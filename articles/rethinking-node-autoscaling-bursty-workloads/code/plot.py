#!/usr/bin/env python3
"""Render the three annotated result figures from results/*.json.

Every figure marks its critical point in the image itself, so a reader
understands the takeaway without the prose:

  latency-cdf.png          the boot-latency floor: reactive p95 vs headroom p95
  node-timeline.png        when nodes arrive vs when pods actually get served
  latency-vs-bootdelay.png the structural floor: p95 tracks boot time linearly
"""
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
RES = HERE / "results"
IMG = HERE.parent / "images"
IMG.mkdir(exist_ok=True)

FG = "#1f2933"
REACTIVE_C = "#d1495b"
HEADROOM_C = "#2a9d8f"
FLOOR_C = "#e08a1e"
plt.rcParams.update({"font.size": 11, "axes.edgecolor": "#8592a0",
                     "axes.titlesize": 13, "figure.dpi": 130})


def load(name):
    p = RES / name
    return json.loads(p.read_text()) if p.exists() else None


def ready_latencies(res):
    return sorted(p["ready_s"] for p in res["pods"] if p["ready_s"] is not None)


def pct(sorted_vals, q):
    if not sorted_vals:
        return float("nan")
    return sorted_vals[min(len(sorted_vals) - 1, int(q * len(sorted_vals)))]


def cdf_xy(vals):
    v = np.array(vals)
    y = np.arange(1, len(v) + 1) / len(v)
    return v, y


def fig_cdf():
    react = load("reactive_boot45.json")
    head = load("headroom_boot45.json")
    if not (react and head):
        print("skip cdf: missing boot45 runs")
        return
    fig, ax = plt.subplots(figsize=(8, 5))
    for res, color, label in [(react, REACTIVE_C, "Reactive (autoscaler provisions on demand)"),
                              (head, HEADROOM_C, "Headroom (warm capacity pre-staged)")]:
        vals = ready_latencies(res)
        x, y = cdf_xy(vals)
        ax.step(x, y * 100, where="post", color=color, lw=2.4, label=label)
        p95 = pct(vals, 0.95)
        ax.axvline(p95, color=color, ls=":", lw=1.4, alpha=0.8)
        ax.annotate(f"p95 = {p95:.0f}s", xy=(p95, 50),
                    xytext=(p95 + 3, 42 if color == REACTIVE_C else 30),
                    color=color, fontsize=10, fontweight="bold")

    boot = react["boot_delay_s"]
    ax.axvline(boot, color=FLOOR_C, ls="--", lw=1.6)
    ax.annotate(f"node-boot floor = {boot:.0f}s\nno reactive pod beats this",
                xy=(boot, 22), xytext=(boot - 17, 20), color=FLOOR_C, fontsize=9.5,
                ha="left",
                arrowprops=dict(arrowstyle="->", color=FLOOR_C, lw=1.1))

    ax.set_xlabel("Pod latency: burst fired → Ready  (seconds)")
    ax.set_ylabel("% of burst pods Ready")
    ax.set_title("Burst of 100 pods: where reactive autoscaling loses to headroom")
    ax.set_ylim(0, 101)
    ax.set_xlim(-1, boot + 14)
    ax.grid(True, alpha=0.25)
    ax.legend(loc="lower right", framealpha=0.95)
    fig.tight_layout()
    fig.savefig(IMG / "latency-cdf.png")
    print("wrote latency-cdf.png")


def fig_timeline():
    react = load("reactive_boot45.json")
    head = load("headroom_boot45.json")
    if not (react and head):
        print("skip timeline: missing boot45 runs")
        return
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 5), sharey=False)
    for ax, res, color, title in [(a1, react, REACTIVE_C, "Reactive"),
                                  (a2, head, HEADROOM_C, "Headroom")]:
        s = res["series"]
        t = [p["t"] for p in s]
        nodes = [p["total_nodes"] for p in s]
        pods = [p["ready_pods"] for p in s]
        ax.plot(t, nodes, color="#38618c", lw=2.2, marker="o", ms=3,
                label="nodes provisioned")
        ax.plot(t, pods, color=color, lw=2.4, marker="s", ms=3,
                label="burst pods Ready")
        # Critical point: when all pods became Ready.
        done = next((p for p in s if p["ready_pods"] >= res["replicas"]), s[-1])
        ax.axvline(done["t"], color=color, ls=":", lw=1.5)
        ax.annotate(f"all {res['replicas']} pods Ready\n@ {done['t']:.0f}s",
                    xy=(done["t"], res["replicas"] * 0.55),
                    xytext=(done["t"] * 0.15 + 1, res["replicas"] * 0.6),
                    color=color, fontsize=9.5, fontweight="bold")
        ax.set_title(f"{title}  (boot delay {res['boot_delay_s']:.0f}s)")
        ax.set_xlabel("seconds after burst fired")
        ax.grid(True, alpha=0.25)
        ax.legend(loc="center right", fontsize=9)
    a1.set_ylabel("count")
    fig.suptitle("Same burst, same boot delay — headroom serves before reactive even has nodes",
                 fontsize=12)
    fig.tight_layout()
    fig.savefig(IMG / "node-timeline.png")
    print("wrote node-timeline.png")


def fig_sweep():
    delays, p50s, p95s = [], [], []
    for d in [5, 15, 30, 45, 60, 90]:
        res = load(f"reactive_boot{d:02d}.json")
        if not res:
            continue
        vals = ready_latencies(res)
        delays.append(d)
        p50s.append(pct(vals, 0.50))
        p95s.append(pct(vals, 0.95))
    if len(delays) < 2:
        print("skip sweep: need >=2 points")
        return
    fig, ax = plt.subplots(figsize=(8, 5))
    d = np.array(delays)
    ax.plot(d, d, color=FLOOR_C, ls="--", lw=1.8, label="node-boot floor (y = boot delay)")
    ax.fill_between(d, 0, d, color=FLOOR_C, alpha=0.08)
    ax.plot(d, p95s, color=REACTIVE_C, lw=2.4, marker="o", ms=6, label="reactive p95")
    ax.plot(d, p50s, color="#38618c", lw=2.0, marker="s", ms=5, label="reactive p50")
    for x, y in zip(d, p95s):
        ax.annotate(f"{y:.0f}s", xy=(x, y), xytext=(x - 1, y + 3),
                    color=REACTIVE_C, fontsize=9)
    # Critical annotation: the gap above the floor is fixed scheduling overhead.
    ax.annotate("p95 stays a roughly constant\noffset above the boot floor —\nthe floor is structural, not tunable",
                xy=(d[-1], p95s[-1]), xytext=(d[0] + 6, max(p95s) * 0.72),
                color=FG, fontsize=10,
                arrowprops=dict(arrowstyle="->", color=FG, lw=1.2))
    ax.set_xlabel("Simulated node-boot delay (seconds)")
    ax.set_ylabel("Pod ready-latency (seconds)")
    ax.set_title("Reactive burst latency is bounded below by node-boot time")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="upper left")
    fig.tight_layout()
    fig.savefig(IMG / "latency-vs-bootdelay.png")
    print("wrote latency-vs-bootdelay.png")


def summary():
    lines = []
    for d in [5, 15, 30, 45, 60, 90]:
        res = load(f"reactive_boot{d:02d}.json")
        if res:
            v = ready_latencies(res)
            lines.append(f"reactive boot={d:>2}s  n={len(v)}/{res['replicas']}  "
                         f"p50={pct(v,0.5):.0f}s p95={pct(v,0.95):.0f}s max={v[-1]:.0f}s "
                         f"nodes={len(res['nodes'])}")
    head = load("headroom_boot45.json")
    if head:
        v = ready_latencies(head)
        lines.append(f"headroom boot=45s  n={len(v)}/{head['replicas']}  "
                     f"p50={pct(v,0.5):.0f}s p95={pct(v,0.95):.0f}s max={v[-1]:.0f}s "
                     f"nodes={len(head['nodes'])}")
    (RES / "summary.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    fig_cdf()
    fig_timeline()
    fig_sweep()
    summary()
