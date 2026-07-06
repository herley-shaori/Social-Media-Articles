# Thread: The "200 Partitions" Myth in Spark

## Post 1/7 (477 characters)

Everyone copy-pastes spark.sql.shuffle.partitions=200 into their Spark config. Almost nobody asks why. That number is a relic from the pre-AQE era, when the number of post-shuffle partitions was fixed at planning time regardless of the actual data size involved. I ran two controlled experiments on a small 5,000-row dataset to show exactly what this default costs you today, and why Adaptive Query Execution has quietly rewritten the rules of shuffle tuning. Thread below.

## Post 2/7 (476 characters)

Setup: Apache Spark 3.5.1 run inside Docker (apache/spark:3.5.1-python3), executed directly from spark-submit on the CLI, no notebook involved. Dataset: spark.range(0, 5000), grouped into only 10 distinct keys, aggregated with a sum and a count. Small enough to run comfortably on a laptop, yet large enough to force a genuine shuffle exchange. First run: AQE explicitly disabled, spark.sql.shuffle.partitions left untouched at its historical default value of exactly 200.

## Post 3/7 (488 characters)

The physical plan tells the story immediately: Exchange hashpartitioning(key#2L, 200). Spark commits to exactly 200 output partitions before knowing anything about the actual shape of the data. With only 10 distinct groups produced from 5,000 rows, nearly every one of those partitions ends up empty or holding a single key's worth of rows. Each still needs a task scheduled, launched, tracked, and torn down by the driver. Measured elapsed time for this specific run: 1.1451 seconds.

## Post 4/7 (487 characters)

Second run: the identical job, but with spark.sql.adaptive.enabled=true and spark.sql.adaptive.coalescePartitions.enabled=true set explicitly. The initial physical plan looks nearly identical, wrapped in AdaptiveSparkPlan isFinalPlan=false. That flag is the whole point of this experiment: it is Spark's starting plan, not its final one. Once the shuffle map stage completes, AQE inspects the real post-shuffle data size and rewrites the execution plan accordingly before continuing.

## Post 5/7 (482 characters)

Result: the 200 planned partitions collapsed down to a single final partition once execution actually finished. Elapsed time dropped from 1.1451s to 0.8126s on the exact same query and dataset. Same output rows, same correctness guarantees, meaningfully less scheduling overhead spent on empty or near-empty partitions. This is not a hypothetical optimization described only in documentation, it is measured behavior captured from a real explain plan and real wall-clock timing.

## Post 6/7 (484 characters)

Why this matters in practice: under AQE, spark.sql.shuffle.partitions=200 is no longer simply the partition count your job will use at runtime. It becomes closer to a ceiling AQE considers before deciding what is actually needed, governed by spark.sql.adaptive.advisoryPartitionSizeInBytes (default 64MB) and coalescePartitions.minPartitionSize. Tuning this value upward just to feel extra safe mostly stops doing what most engineers still genuinely assume it does under the hood.

## Post 7/7 (486 characters)

Important caveat: coalescing solves small-partition scheduling overhead, it does not solve data skew. If one key dominates your shuffle, the relevant knob is spark.sql.adaptive.skewJoin.enabled and its associated thresholds, not coalescing. Always check the isFinalPlan flag in explain output before trusting a pre-execution plan at face value. Full write-up with complete plans, measured metrics, and further reading is linked in the article below for anyone who wants the details.
