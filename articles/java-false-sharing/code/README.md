# False Sharing in Java — Benchmarks

> **Published:** the full article has been published on LinkedIn / Medium.
> This repository holds only the runnable code the article references.

JMH benchmarks showing false sharing: two threads writing *different* variables
that share a cache line stall each other, and how padding (and `LongAdder`)
removes the cost.

## Benchmarks

| File | What it measures |
|------|-------------------|
| `FalseSharingBenchmark.java` | Eight threads, eight private counters. `packed` = counters adjacent (shared cache line) vs `spread` = 128 bytes apart (own line). |
| `AtomicVsAdderBenchmark.java` | Eight threads on one counter: `AtomicLong` (one contended line) vs `LongAdder` (padded, striped cells). |

## Running

```sh
./run.sh          # builds the JMH jar, runs both, writes results-*.json / .txt
python3 plots.py  # renders ../images/*.png from the JSON (needs matplotlib)
```

Requires a JDK (tested on OpenJDK 25) and Maven.

## Measured result (Apple Silicon, 14 cores, OpenJDK 25, JMH 1.37)

- False sharing: `packed` ≈ 128k ops/ms vs `spread` ≈ 2.44M ops/ms — about **19x**.
- Contention: `AtomicLong` ≈ 23k ops/ms vs `LongAdder` ≈ 1.73M ops/ms — about **76x**.

## Notes

- Counters are written with `VarHandle` **volatile** stores on purpose: a plain
  increment would be coalesced by the JIT and the memory traffic — the thing we
  measure — would disappear.
- Padding is **128 bytes** because Apple Silicon uses 128-byte cache lines; 64
  would be enough on typical x86.
- The false-sharing benchmark uses multiple JMH forks because the macOS
  scheduler can occasionally co-locate threads and hide the effect in a single
  run.
