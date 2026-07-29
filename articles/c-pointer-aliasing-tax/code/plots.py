#!/usr/bin/env python3
"""Render the article figures from results/.

Run run.sh first. Writes ../images/*.png.
"""

import pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).resolve().parent
RESULTS = HERE / "results"
IMAGES = HERE.parent / "images"

# Categorical slots 1 and 2 of a CVD-validated palette (worst-pair ΔE 24.7
# under protanopia, 33.6 normal vision), so the two builds stay separable in
# print and for colour-blind readers.
BLUE, ORANGE = "#2a78d6", "#eb6834"
INK, MUTED, GRID = "#0b0b0b", "#52514e", "#dedcd6"


def load(name):
    values = {}
    for line in (RESULTS / name).read_text().splitlines():
        if "=" in line and not line.startswith("=="):
            k, v = line.split("=", 1)
            values[k.strip()] = v.strip()
    return values


def style(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(axis="both", length=0, colors=MUTED, labelsize=10)


def bars(ax, labels, a_vals, b_vals, a_name, b_name):
    x = range(len(labels))
    w = 0.36
    # 2px-equivalent gap between adjacent fills
    left = ax.bar([i - w / 2 - 0.012 for i in x], a_vals, w, label=a_name,
                  color=BLUE, edgecolor="white", linewidth=1.5)
    right = ax.bar([i + w / 2 + 0.012 for i in x], b_vals, w, label=b_name,
                   color=ORANGE, edgecolor="white", linewidth=1.5)
    for group in (left, right):
        for rect in group:
            ax.annotate(f"{rect.get_height():.2f}",
                        (rect.get_x() + rect.get_width() / 2, rect.get_height()),
                        textcoords="offset points", xytext=(0, 3),
                        ha="center", fontsize=9, color=MUTED)
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels)
    return left, right


def figure_one():
    a = load("suite_a.txt")
    variants = [("ptr", "by pointer"), ("val", "by value"),
                ("restrict", "restrict"), ("float", "float members")]
    labels = [lbl for _, lbl in variants]
    noalign = [float(a[f"o2-noalign.A.{k}.ns_per_elem"]) for k, _ in variants]
    aligned = [float(a[f"o2-align.A.{k}.ns_per_elem"]) for k, _ in variants]

    fig, ax = plt.subplots(figsize=(9, 5.2))
    bars(ax, labels, noalign, aligned,
         "-O2, GCC default loop alignment", "-O2 -falign-loops=32")
    style(ax)
    ax.set_ylabel("nanoseconds per element  (lower is better)",
                  color=MUTED, fontsize=10)
    ax.set_ylim(0, max(noalign + aligned) * 1.30)
    ax.set_title("The same source, the same -O2, the same machine",
                 fontsize=15, color=INK, pad=26, loc="left")
    ax.text(0, 1.035,
            "Whichever loop happens to straddle a 32-byte fetch boundary pays for it.",
            transform=ax.transAxes, fontsize=10.5, color=MUTED)

    worst = noalign[1]
    ax.annotate("loop straddles a 32-byte\ninstruction-fetch boundary",
                xy=(1 - 0.20, worst * 1.005), xytext=(1.35, worst * 1.20),
                fontsize=9.5, color=INK, ha="left",
                arrowprops=dict(arrowstyle="->", color=MUTED, linewidth=1.2))

    ax.legend(frameon=False, fontsize=10, labelcolor=MUTED,
              loc="upper center", bbox_to_anchor=(0.5, -0.09), ncols=2)
    fig.tight_layout()
    out = IMAGES / "alignment-artifact.png"
    fig.savefig(out, dpi=170, facecolor="white")
    print(f"wrote {out}")


def figure_two():
    b = load("suite_b.txt")
    variants = [("ptr", "sum via pointer"), ("restrict", "+ restrict"),
                ("local", "local accumulator")]
    labels = [lbl for _, lbl in variants]
    ints = [float(b[f"B.int.{k}.ns_per_elem"]) for k, _ in variants]
    dbls = [float(b[f"B.dbl.{k}.ns_per_elem"]) for k, _ in variants]

    # Two measures on one scale, shown as small multiples rather than one
    # grouped chart: the comparison that matters is the SHAPE within each
    # panel, and a shared y-axis keeps the absolute costs comparable too.
    fig, axes = plt.subplots(1, 2, figsize=(10, 5.4), sharey=True)
    top = max(ints + dbls) * 1.30

    for ax, vals, colour, panel in (
        (axes[0], ints, BLUE, "int64 accumulator"),
        (axes[1], dbls, ORANGE, "double accumulator"),
    ):
        rects = ax.bar(range(len(labels)), vals, 0.58, color=colour,
                       edgecolor="white", linewidth=1.5)
        for rect, v in zip(rects, vals):
            ax.annotate(f"{v:.2f}",
                        (rect.get_x() + rect.get_width() / 2, v),
                        textcoords="offset points", xytext=(0, 4),
                        ha="center", fontsize=10, color=INK)
            ax.annotate(f"{vals[0] / v:.2f}x",
                        (rect.get_x() + rect.get_width() / 2, v),
                        textcoords="offset points", xytext=(0, 19),
                        ha="center", fontsize=9.5, color=MUTED)
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels, fontsize=10)
        ax.set_ylim(0, top)
        style(ax)
        ax.set_title(panel, fontsize=11.5, color=INK, pad=8, loc="left")

    axes[0].set_ylabel("nanoseconds per element  (lower is better)",
                       color=MUTED, fontsize=10)
    fig.suptitle("The aliasing tax is only visible on the critical path",
                 fontsize=15, color=INK, x=0.055, ha="left", y=0.985)
    fig.text(0.055, 0.925,
             "Identical loop bodies. Integers gain 2.3x from dropping the store; "
             "doubles gain nothing —\nfloating-point add latency already dominates, "
             "so there is no room left to win.",
             fontsize=10.5, color=MUTED, ha="left", va="top")
    fig.tight_layout(rect=[0, 0, 1, 0.90])
    out = IMAGES / "critical-path.png"
    fig.savefig(out, dpi=170, facecolor="white")
    print(f"wrote {out}")


if __name__ == "__main__":
    IMAGES.mkdir(exist_ok=True)
    figure_one()
    figure_two()
