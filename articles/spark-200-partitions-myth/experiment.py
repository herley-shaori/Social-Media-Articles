import time
import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Usage:
#   spark-submit experiment.py false   -> AQE disabled (baseline, static 200 partitions)
#   spark-submit experiment.py true    -> AQE enabled (coalesces partitions at runtime)
aqe_enabled = sys.argv[1] == "true" if len(sys.argv) > 1 else False

builder = SparkSession.builder.appName(f"shuffle-partitions-demo-aqe-{aqe_enabled}")
builder = builder.config("spark.sql.shuffle.partitions", "200")
builder = builder.config("spark.sql.adaptive.enabled", "true" if aqe_enabled else "false")
builder = builder.config("spark.sql.adaptive.coalescePartitions.enabled", "true" if aqe_enabled else "false")

spark = builder.getOrCreate()
spark.sparkContext.setLogLevel("ERROR")

# Small dataset: 5,000 rows, enough to trigger a shuffle but nowhere near needing 200 partitions.
df = spark.range(0, 5000).withColumn("key", (F.col("id") % 10)).withColumn("value", F.col("id") * 2)

agg = df.groupBy("key").agg(F.sum("value").alias("total"), F.count("*").alias("cnt"))

print("=" * 80)
print(f"AQE ENABLED: {aqe_enabled}")
print("=" * 80)

print("\n--- EXPLAIN PLAN ---")
agg.explain(True)

start = time.time()
result = agg.collect()
elapsed = time.time() - start

print("\n--- RESULT ---")
for row in sorted(result, key=lambda r: r["key"]):
    print(row)

print(f"\n--- METRICS ---")
print(f"Elapsed time: {elapsed:.4f}s")
print(f"Number of output partitions after shuffle: {agg.rdd.getNumPartitions()}")

spark.stop()
