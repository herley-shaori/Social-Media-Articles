#!/usr/bin/env bash
# Build the JMH benchmarks and run both experiments, saving JSON results.
# Requires a JDK (tested on OpenJDK 25) and Maven.
set -euo pipefail
cd "$(dirname "$0")"

echo "### building ..."
mvn -q -DskipTests package

echo "### 1) false sharing: two threads, adjacent vs padded counters"
java -jar target/benchmarks.jar "FalseSharingBenchmark" \
    -rf json -rff results-falsesharing.json | tee results-falsesharing.txt

echo "### 2) AtomicLong vs LongAdder under contention (8 threads)"
java -jar target/benchmarks.jar "AtomicVsAdderBenchmark" -t 8 \
    -rf json -rff results-atomicadder.json | tee results-atomicadder.txt

echo "### done."
