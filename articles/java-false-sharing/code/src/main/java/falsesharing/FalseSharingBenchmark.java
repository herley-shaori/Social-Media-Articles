package falsesharing;

import org.openjdk.jmh.annotations.*;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * The core false-sharing demonstration.
 *
 * Eight worker threads each increment their OWN counter — no thread ever
 * touches another thread's counter, so there is no shared mutable state and no
 * lock. The only difference between the two benchmarks is where those eight
 * counters sit in memory:
 *
 *   packed:  the eight counters are one long[8] — all of them inside a single
 *            cache line (or two). Every write by any thread invalidates that
 *            line on all the other cores, so the line ping-pongs across the
 *            whole machine (MESI coherence traffic). This is false sharing.
 *
 *   spread:  the eight counters sit 128 bytes apart (STRIDE = 16 longs), so
 *            each one owns its own cache line and no two threads ever touch the
 *            same line. No coherence ping-pong.
 *
 * Same work, same eight threads, each on its own counter. The entire throughput
 * gap is false sharing and nothing else.
 *
 * Why VarHandle volatile writes: a plain increment would be hoisted out of the
 * loop and coalesced by the JIT, erasing the per-write memory traffic we are
 * measuring. Volatile stores force each increment to reach memory — exactly the
 * pattern that triggers false sharing in real counter-heavy, lock-free code.
 *
 * Why eight threads (not two): with only two threads the OS may co-schedule
 * them on one core and hide the effect. Filling the machine guarantees the
 * writes are genuinely cross-core, which makes the result stable.
 */
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.MILLISECONDS)
@Warmup(iterations = 3, time = 1)
@Measurement(iterations = 5, time = 1)
@Fork(3)
public class FalseSharingBenchmark {

    static final int THREADS = 8;
    static final int STRIDE = 16; // 16 longs = 128 bytes = one Apple-Silicon cache line

    static final VarHandle LONGS = MethodHandles.arrayElementVarHandle(long[].class);

    @State(Scope.Benchmark)
    public static class Counters {
        final AtomicInteger next = new AtomicInteger();
        long[] packed;              // 8 counters, adjacent -> same line(s)
        long[] spread;              // 8 counters, 128 bytes apart -> own lines

        @Setup(Level.Trial)
        public void init() {
            packed = new long[THREADS];
            spread = new long[THREADS * STRIDE];
            next.set(0);
        }
    }

    /** Per-thread slot assignment, so each worker owns exactly one counter. */
    @State(Scope.Thread)
    public static class Slot {
        int id;
        @Setup(Level.Trial)
        public void assign(Counters c) {
            id = c.next.getAndIncrement() % THREADS;
        }
    }

    @Benchmark
    @Threads(THREADS)
    public void packed(Counters c, Slot s) {
        long v = (long) LONGS.getVolatile(c.packed, s.id);
        LONGS.setVolatile(c.packed, s.id, v + 1);
    }

    @Benchmark
    @Threads(THREADS)
    public void spread(Counters c, Slot s) {
        int i = s.id * STRIDE;
        long v = (long) LONGS.getVolatile(c.spread, i);
        LONGS.setVolatile(c.spread, i, v + 1);
    }
}
