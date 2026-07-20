#!/usr/bin/env python3
"""Render the two result charts from the JMH JSON output into ../images/."""
import json
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
IMG = HERE.parent / "images"
IMG.mkdir(exist_ok=True)
plt.rcParams.update({"font.size": 12, "axes.edgecolor": "#8592a0", "figure.dpi": 140})

SLOW = "#d1495b"
FAST = "#2a9d8f"


def score(path, name):
    for b in json.load(open(HERE / path)):
        if b["benchmark"].endswith(name):
            return b["primaryMetric"]["score"], b["primaryMetric"]["scoreError"]
    raise KeyError(name)


def bar_chart(fname, title, subtitle, labels, values, errors, colors, note):
    fig, ax = plt.subplots(figsize=(7.5, 5))
    x = range(len(labels))
    bars = ax.bar(x, values, yerr=errors, color=colors, width=0.55,
                  capsize=6, error_kw={"ecolor": "#555", "lw": 1})
    ax.set_xticks(list(x))
    ax.set_xticklabels(labels, fontsize=12.5)
    ax.set_ylabel("Throughput (ops/ms, higher is better)")
    ax.set_title(title, fontsize=13.5, fontweight="bold", pad=18)
    ax.text(0.5, 1.015, subtitle, transform=ax.transAxes, ha="center",
            va="bottom", fontsize=10.5, color="#5a6675")
    for b, v in zip(bars, values):
        ax.text(b.get_x() + b.get_width() / 2, v, f"{v:,.0f}",
                ha="center", va="bottom", fontsize=11, fontweight="bold")
    ax.margins(y=0.18)
    ax.annotate(note, xy=(0.5, values[0]), xytext=(0.30, 0.60),
                textcoords="axes fraction", ha="center",
                fontsize=13, fontweight="bold", color=FAST,
                arrowprops=dict(arrowstyle="->", color=FAST, lw=1.6))
    ax.grid(axis="y", alpha=0.25)
    fig.tight_layout()
    fig.savefig(IMG / fname)
    print("wrote", fname)


# 1) False sharing: packed vs spread
p, pe = score("results-falsesharing.json", "packed")
s, se = score("results-falsesharing.json", "spread")
bar_chart(
    "false-sharing-throughput.png",
    "Eight threads, eight private counters — only the layout differs",
    "packed = all counters share cache lines · spread = each on its own 128-byte line",
    ["packed\n(false sharing)", "spread\n(padded)"],
    [p, s], [pe, se], [SLOW, FAST],
    f"{s / p:.0f}x faster\njust by spacing\nthe counters out",
)

# 2) AtomicLong vs LongAdder under contention
a, ae = score("results-atomicadder.json", "atomicLong")
l, le = score("results-atomicadder.json", "longAdder")
bar_chart(
    "atomic-vs-adder.png",
    "AtomicLong vs LongAdder — 8 threads incrementing one counter",
    "LongAdder stripes the count across padded cells, sidestepping the contended line",
    ["AtomicLong\n(one hot line)", "LongAdder\n(padded cells)"],
    [a, l], [ae, le], [SLOW, FAST],
    f"{l / a:.0f}x faster\nunder contention",
)
