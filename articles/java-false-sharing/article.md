# The Bug That Isn't in Your Code: False Sharing in Java

This article has been published at: _<add LinkedIn / Medium URL here>_

This repository holds only the runnable code and benchmarks the article references:

- [`code/`](code) — a Maven + JMH project.
- [`code/src/main/java/falsesharing/FalseSharingBenchmark.java`](code/src/main/java/falsesharing/FalseSharingBenchmark.java) — eight threads, eight private counters, packed vs padded layout.
- [`code/src/main/java/falsesharing/AtomicVsAdderBenchmark.java`](code/src/main/java/falsesharing/AtomicVsAdderBenchmark.java) — AtomicLong vs LongAdder under contention.
- [`code/run.sh`](code/run.sh) — builds and runs both benchmarks, saving JSON results.
- [`code/plots.py`](code/plots.py) — renders the charts from the JSON.
- [`images/`](images) — the cache-line diagram and the two result charts.
