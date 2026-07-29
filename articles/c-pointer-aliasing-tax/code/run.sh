#!/usr/bin/env bash
# Reproduce every number in the article.
#
# Three builds of the same kernel source:
#   o2-noalign : -O2, GCC's default loop alignment  -> the accidental experiment
#   o2-align   : -O2 -falign-loops=32               -> the controlled experiment
#   o3-align   : -O3 -falign-loops=32               -> what -O3 does about it
#
# Everything is written to results/ as `key=value` lines.

set -euo pipefail
cd "$(dirname "$0")"
mkdir -p results build

CC=${CC:-gcc}
STD="-std=c11"

echo "== environment =="
{
    echo "env.cc=$($CC --version | head -1)"
    echo "env.uname=$(uname -srm)"
    if [ -r /proc/cpuinfo ]; then
        echo "env.cpu=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)"
    fi
} | tee results/env.txt

build() {
    local tag=$1; shift
    $CC -O0 "$@" $STD -c bench.c -o build/bench-$tag.o   # harness: never optimised into the kernels
    $CC "$@" $STD -c kernels.c   -o build/kernels-$tag.o
    $CC "$@" $STD -c accum.c     -o build/accum-$tag.o
    $CC build/bench-$tag.o build/kernels-$tag.o build/accum-$tag.o -o build/bench-$tag
}

echo
echo "== building =="
build o2-noalign -O2
build o2-align   -O2 -falign-loops=32
build o3-align   -O3 -falign-loops=32
echo "ok"

echo
echo "== loop alignment =="
python3 align_probe.py build/bench-o2-noalign build/bench-o2-align build/bench-o3-align \
    | tee results/alignment.txt

echo
echo "== suite A: loop-invariant reload =="
for tag in o2-noalign o2-align o3-align; do
    ./build/bench-$tag a | sed "s/^/$tag./"
done | tee results/suite_a.txt

echo
echo "== suite B: pointer accumulator (-O3) =="
./build/bench-o3-align b | tee results/suite_b.txt

echo
echo "== verifying all variants compute the same thing =="
if grep -q 'checksums_identical=0' results/suite_a.txt \
   || grep -q 'results_identical=0' results/suite_b.txt; then
    echo "FAIL: variants disagree — the timings are not comparable." >&2
    exit 1
fi
echo "ok: suite A checksums and suite B results all match"

echo
echo "== kernel code size (-O3) =="
for f in apply_ptr apply_val apply_restrict apply_ptr_float; do
    sz=$(nm -S build/bench-o3-align | awk -v f="$f" '$4==f {print $2}')
    printf 'size.%s=%d\n' "$f" "$((16#${sz:-0}))"
done | tee results/code_size.txt

echo
echo "== assembly excerpts =="
$CC -O2 $STD -S -masm=intel -o results/kernels-O2.s kernels.c
$CC -O3 $STD -S -masm=intel -o results/kernels-O3.s kernels.c
$CC -O3 $STD -S -masm=intel -o results/accum-O3.s   accum.c
echo "wrote results/kernels-O2.s results/kernels-O3.s results/accum-O3.s"

echo
echo "done. Now: python3 plots.py"
