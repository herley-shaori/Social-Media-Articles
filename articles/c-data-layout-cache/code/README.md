# Data Layout and Cache Locality — Experiment Code

> **Article:** draft — not yet published on Medium.

This directory contains the reproducible experiment for a C article about a
seemingly harmless data-layout choice: an array of 256-byte `Particle` structs
versus a struct of arrays holding the exact same fields.

The hot loop updates only `x` from `vx`. The remaining 248 bytes of
each particle are deliberately cold. The benchmark measures when the
object-shaped Array of Structs (AoS) layout makes the CPU move data the loop
does not need, and whether Struct of Arrays (SoA) improves throughput.

## Correctness and fairness

- Both representations contain the same fields and use the same deterministic
  initial values.
- The update operation, number of updates, and compiler flags are identical.
- The four SoA fields used by the hot loop are separately allocated, so its
  local pointers are declared `restrict`. This records a property the
  experiment actually guarantees and prevents pointer-alias analysis from
  obscuring the layout effect.
- Before timing, the program runs both layouts and checks that every updated
  `x` value is bit-for-bit identical.
- Seven trials are run per layout and size; the reported value is the median.
- Each simulation step is a full sweep through the collection. The harness
  invokes the sweep through a volatile function pointer so the compiler cannot
  legally collapse 120 sweeps into 120 updates of one particle at a time.
- The three data sizes represent a small working set, a cache-pressure case,
  and a RAM-dominated case. The actual cases are 1,000 (0.24 MiB), 10,000
  (2.44 MiB), 100,000 (24.41 MiB), and 524,288 (128 MiB) particles.
  `working_set_mib` is the 256-byte-per-particle representation size.

## Run with Docker

From this directory in PowerShell:

```powershell
docker build -t c-data-layout-cache:local .
docker run --rm --cpuset-cpus=0 -v "${PWD}:/work" c-data-layout-cache:local /work/run.sh
```

The first command pins the compiler family through `gcc:14-bookworm`; the
second writes the raw result file and environment report into `results/`.

`--cpuset-cpus=0` reduces scheduler noise by keeping the benchmark on one
container CPU. The figures compare layouts reliably within this container, but
they must not be presented as native-Windows performance figures: Docker
Desktop runs Linux containers in its Linux VM.

## Output

- `results/environment.txt` records the compiler, Linux kernel, reported CPU,
  and visible container CPU count.
- `results/run-1.csv` through `results/run-3.csv` contain three independent
  process runs. Each result is itself the median of seven trials. Every result
  line must report `correct=1`; otherwise its timings are invalid.
