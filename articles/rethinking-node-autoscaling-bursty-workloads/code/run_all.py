#!/usr/bin/env python3
"""Run the full experiment matrix and save one JSON per run into results/.

Matrix:
  * Boot-delay sweep (reactive arm): boot in {5,15,30,45,60,90}s, N=100.
  * Head-to-head at boot=45s: reactive vs headroom, N=100.

The reactive boot=45s run is shared between the sweep and the head-to-head.
"""
import sys
from pathlib import Path

import run

HERE = Path(__file__).resolve().parent
OUT = HERE / "results"
OUT.mkdir(exist_ok=True)

REPLICAS = 100
SWEEP = [5, 15, 30, 45, 60, 90]
MAIN_DELAY = 45


def save(result, name):
    import json
    (OUT / name).write_text(json.dumps(result, indent=2))
    ready = sorted(p["ready_s"] for p in result["pods"] if p["ready_s"] is not None)
    p95 = ready[min(len(ready) - 1, int(0.95 * len(ready)))] if ready else float("nan")
    print(f"[saved] {name:32s} n={len(ready)}/{result['replicas']} p95={p95:.1f}s",
          flush=True)


def main():
    for d in SWEEP:
        res = run.run_reactive(REPLICAS, d, timeout=400)
        save(res, f"reactive_boot{d:02d}.json")

    res = run.run_headroom(REPLICAS, MAIN_DELAY, timeout=400)
    save(res, f"headroom_boot{MAIN_DELAY:02d}.json")

    print("DONE", flush=True)


if __name__ == "__main__":
    main()
