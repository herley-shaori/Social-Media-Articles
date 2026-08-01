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
- The two SoA fields used by the hot loop are separately allocated, so their
  local pointers are declared `restrict`. This records a property the
  experiment actually guarantees and prevents pointer-alias analysis from
  obscuring the layout effect.
- Before timing, the program runs both layouts and checks that every updated
  `x` value is bit-for-bit identical.
- Seven trials are run per layout and size; the reported value is the median.
- Each simulation step is a full sweep through the collection. The harness
  invokes the sweep through a volatile function pointer so the compiler cannot
  legally collapse 120 sweeps into 120 updates of one particle at a time.
- The four data sizes represent a small working set, a cache-pressure case,
  and a RAM-dominated case. The actual cases are 1,000 (0.24 MiB), 10,000
  (2.44 MiB), 100,000 (24.41 MiB), and 524,288 (128 MiB) particles.
  `working_set_mib` is the 256-byte-per-particle representation size.

## Before and after

| Aspect | Before: Array of Structs (AoS) | After: Struct of Arrays (SoA) | Why it changes the result |
|---|---|---|---|
| Memory layout | `Particle particles[N]`; every particle is 256 bytes | `x[N]`, `vx[N]`, and cold fields in separate arrays | The loop needs only 8 useful bytes per particle; AoS makes them sparse at a 256-byte stride, while SoA packs them contiguously. |
| Hot-loop access | Loads `x` and `vx` at a 256-byte stride | Reads two contiguous float arrays | Contiguous arrays are cache- and prefetch-friendly. |
| Generated machine code | Scalar update per particle | AVX2 vector update over contiguous floats | GCC can process eight SoA elements per vector instruction. |
| 10,000-particle result | 6.255–8.313 ms | 0.124–0.147 ms | SoA was 42.69–57.33x faster across the three process runs. |

The algorithm did not change: both versions run the same `x += vx * 0.016f`
update 120 times and must produce bit-for-bit identical `x` values. The only
independent variable is how the same fields are arranged in memory.

## Benchmark environment

The benchmark is compiled and executed inside a **Linux container**, not by a
Windows C compiler. Docker Desktop runs that Linux container through its WSL2
backend. The recorded environment for these results is:

| Component | Recorded value |
|---|---|
| Container image | `gcc:14-bookworm` |
| Compiler | GCC 14.3.0 |
| Container kernel | Linux 5.15.167.4-microsoft-standard-WSL2, x86_64 |
| CPU reported in the container | 12th Gen Intel Core i9-12950HX |
| Benchmark CPU allocation | One logical CPU (`--cpuset-cpus=0`) |

Docker Desktop can expose all 24 logical CPUs of this machine to a container.
This experiment deliberately uses one because it measures a single-threaded
hot loop. Giving that loop more CPUs would not make it faster; it would only
make its timing less controlled. The results are valid for an AoS-versus-SoA
comparison in this container, not as native-Windows timings.

## Run the C benchmark with Docker

From this directory in PowerShell:

```powershell
# Build the pinned GCC environment (needed only after a Dockerfile change).
docker build -t c-data-layout-cache:local .

# Compile benchmark.c and run the complete C benchmark.
docker run --rm --cpuset-cpus=0 -v "${PWD}:/work" c-data-layout-cache:local /work/run.sh
```

The first command pins the compiler family through `gcc:14-bookworm`; the
second writes the raw result file and environment report into `results/`.

To see the GCC compile command and run the C program directly, use this
equivalent command. It prints results to the terminal but does not save the
three raw run files:

```powershell
docker run --rm --cpuset-cpus=0 -v "${PWD}:/work" c-data-layout-cache:local -lc 'cd /work; mkdir -p build; gcc -O3 -march=x86-64-v3 -std=c11 -Wall -Wextra -Wpedantic benchmark.c -o build/benchmark; ./build/benchmark'
```

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
