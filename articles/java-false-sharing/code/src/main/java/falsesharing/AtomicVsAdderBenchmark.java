package falsesharing;

import org.openjdk.jmh.annotations.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.LongAdder;

/**
 * The same effect, one layer up — why LongAdder beats AtomicLong under contention.
 *
 * Many threads incrementing a single AtomicLong all fight over one cache line:
 * every successful CAS invalidates that line on every other core, so the line
 * ping-pongs exactly like the false-sharing case — except here the sharing is
 * real, not accidental.
 *
 * LongAdder spreads the count across multiple Cells, and each Cell is padded
 * (@Contended) onto its own cache line. Threads mostly touch different cells, so
 * they mostly touch different lines — the contention, and the coherence traffic,
 * largely disappears. It is false-sharing avoidance built into the JDK.
 *
 * Run with several threads (e.g. -t 8) to see the gap.
 */
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
@Warmup(iterations = 3, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(1)
@State(Scope.Benchmark)
public class AtomicVsAdderBenchmark {

    AtomicLong atomic = new AtomicLong();
    LongAdder adder = new LongAdder();

    @Benchmark
    public long atomicLong() {
        return atomic.incrementAndGet();
    }

    @Benchmark
    public void longAdder() {
        adder.increment();
    }
}
