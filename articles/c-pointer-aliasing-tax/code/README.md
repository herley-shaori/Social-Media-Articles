# The Aliasing Tax — Experiment Code

> **Published:** draft; not yet published.
> This directory holds the runnable code behind the article.

Measures what a pointer parameter actually costs in C: not the copy, but the
optimizations the compiler is no longer allowed to perform — and shows that a
naive benchmark of it reports a confidently wrong answer.

## Layout

| Path | Purpose |
|------|---------|
| `kernels.h` / `kernels.c` | One line of arithmetic, four ways of passing its parameters: by pointer, by value, `restrict`, and distinct member types |
| `accum.c` | Accumulator kernels (`int64` and `double`) where the pointer is the destination rather than a source |
| `bench.c` | Timing harness; emits `key=value` lines. Suite A = loop-invariant reload, suite B = pointer accumulator |
| `align_probe.py` | Disassembles a binary and reports whether each hot loop straddles a 32-byte instruction-fetch boundary |
| `run.sh` | Three builds, alignment probe, both suites, assembly dumps → `results/` |
| `plots.py` | Renders `../images/*.png` from `results/` |
| `results/` | Raw measurements, alignment table, and the `-O2`/`-O3` assembly listings |

## Running

```sh
./run.sh          # requires gcc, python3, binutils
python3 plots.py  # requires matplotlib
```

`run.sh` produces three builds of the same kernel source:

| Tag | Flags | Why |
|---|---|---|
| `o2-noalign` | `-O2` | GCC's default loop placement — the accidental experiment |
| `o2-align` | `-O2 -falign-loops=32` | The controlled experiment |
| `o3-align` | `-O3 -falign-loops=32` | What `-O3` does about aliasing |

## Headline results

- At `-O2` with **uncontrolled** loop alignment the benchmark reports that passing
  by value is **28% slower** than passing by pointer. It is reproducible, and it
  is an artifact: the by-value loop happened to straddle a 32-byte fetch boundary.
  Rebuild into a different binary and the penalty moves to a different variant.
- With `-falign-loops=32` the real tax appears: **~6%**, with `apply_ptr` slowest,
  matching the assembly (3 loads per element versus 1).
- At `-O3` the tax all but **disappears** (the four variants land within 3% of each other) — GCC emits a runtime overlap check plus two
  copies of the loop. It is paid in code size instead: 333 bytes for the pointer
  version against 241 for the `restrict` version.
- Where it is genuinely expensive: an `int64` accumulator reached through a
  pointer is **2.29x** slower than one accumulated in a local, because aliasing
  forces a store on every iteration. The same change on a `double` accumulator
  buys **nothing** — FP add latency already dominates.

## Notes

- **The kernels are in a separate translation unit on purpose.** Inlined, the
  compiler sees the real objects, proves non-overlap, and every effect here
  vanishes. Do not "simplify" the harness by merging the files.
- The reported figure is the **minimum** of five trials — the least noisy
  estimator on a shared machine, since noise only ever adds time.
- Every variant is checksummed; `run.sh` fails loudly if the variants stop
  computing the same thing.
- `align_probe.py`'s `crosses32` flag is meaningful for **short** loops. A
  vectorized loop is longer than 32 bytes and necessarily spans two windows, so
  the flag carries no signal there.
