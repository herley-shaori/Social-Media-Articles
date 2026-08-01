#!/usr/bin/env bash
# Rebuild the benchmark and record a reproducible environment report.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p build results

gcc -O3 -march=x86-64-v3 -std=c11 -Wall -Wextra -Wpedantic \
    benchmark.c -o build/benchmark

{
    echo "compiler=$(gcc --version | head -1)"
    echo "kernel=$(uname -srmo)"
    echo "cpu=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"
    echo "container_cpus=$(nproc)"
} > results/environment.txt

for run in 1 2 3; do
    ./build/benchmark | tee "results/run-${run}.csv"
done

echo "wrote results/environment.txt and results/run-{1,2,3}.csv"
