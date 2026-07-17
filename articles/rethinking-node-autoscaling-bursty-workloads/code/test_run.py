#!/usr/bin/env python3
"""Sanity checks for the pure timestamp/statistics logic in run.py and plot.py.

Run: python3 test_run.py   (no framework, just asserts)
"""
from datetime import timezone

import run
import plot


def test_parse_ts_and_cond_time():
    obj = {
        "status": {
            "conditions": [
                {"type": "Ready", "status": "True",
                 "lastTransitionTime": "2026-07-17T10:00:30Z"},
                {"type": "PodScheduled", "status": "True",
                 "lastTransitionTime": "2026-07-17T10:00:10Z"},
            ]
        }
    }
    ready = run.cond_time(obj, "Ready")
    sched = run.cond_time(obj, "PodScheduled")
    assert ready.tzinfo == timezone.utc
    # Ready is 20s after scheduled.
    assert (ready - sched).total_seconds() == 20.0
    # A condition that is not True must not be returned.
    assert run.cond_time({"status": {"conditions": [
        {"type": "Ready", "status": "False",
         "lastTransitionTime": "2026-07-17T10:00:00Z"}]}}, "Ready") is None


def test_percentile():
    vals = list(range(1, 101))  # 1..100 sorted
    assert plot.pct(vals, 0.50) == 51
    assert plot.pct(vals, 0.95) == 96
    assert plot.pct([], 0.95) != plot.pct([], 0.95)  # NaN != NaN


def test_ready_latencies_filters_none():
    res = {"pods": [
        {"ready_s": 5.0}, {"ready_s": None}, {"ready_s": 1.0},
    ]}
    assert plot.ready_latencies(res) == [1.0, 5.0]


if __name__ == "__main__":
    test_parse_ts_and_cond_time()
    test_percentile()
    test_ready_latencies_filters_none()
    print("all sanity checks passed")
