/* Benchmark harness for the aliasing-tax experiment.
 *
 * Method notes:
 *  - The working set is sized to sit in L1/L2 so the loops are limited by the
 *    arithmetic, the loads and the stores, not by DRAM bandwidth. A
 *    memory-bound loop would hide the effect being measured.
 *  - Each variant is run REPS times; the reported figure is the MINIMUM
 *    elapsed time over TRIALS, which is the least noisy estimator on a shared
 *    machine (noise only ever adds time).
 *  - Every variant is checksummed. Identical checksums prove the variants
 *    compute the same thing, so the timings compare like with like.
 *  - Kernels live in separate translation units. If they were visible here
 *    they would be inlined, the compiler would see the real objects behind
 *    every parameter, prove they do not overlap, and every difference in this
 *    experiment would vanish. That caveat is the whole reason for the split.
 *
 * Output is machine-readable (one `key=value` line per measurement) so run.sh
 * can collect it and plots.py can render it without parsing prose.
 */

#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include "kernels.h"

#define N      16384   /* 64 KiB of int */
#define REPS   2000
#define TRIALS 5

void isum_ptr(int64_t *, const int64_t *, size_t);
void isum_restrict(int64_t *restrict, const int64_t *restrict, size_t);
void isum_local(int64_t *, const int64_t *, size_t);
void dsum_ptr(double *, const double *, size_t);
void dsum_restrict(double *restrict, const double *restrict, size_t);
void dsum_local(double *, const double *, size_t);

static double now_sec(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static uint64_t checksum(const int *a, size_t n)
{
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) {
        h ^= (uint64_t)(uint32_t)a[i];
        h *= 1099511628211ULL;
    }
    return h;
}

static void reset(int *a, size_t n)
{
    for (size_t i = 0; i < n; i++)
        a[i] = (int)(i & 0x3F);
}

/* ---------------- Suite A: loop-invariant reload ---------------- */

static void suite_a(void)
{
    int *buf = aligned_alloc(64, N * sizeof *buf);
    if (!buf) exit(1);

    struct Config  cfg  = { .scale = 1, .offset = 1 };
    struct ConfigF cfgf = { .scale = 1.0f, .offset = 1.0f };

    static const char *names[4] = { "ptr", "val", "restrict", "float" };
    double best[4];
    uint64_t sums[4] = { 0, 0, 0, 0 };

    for (int v = 0; v < 4; v++) best[v] = 1e30;

    for (int t = 0; t < TRIALS; t++) {
        for (int v = 0; v < 4; v++) {
            reset(buf, N);
            double t0 = now_sec();
            for (int r = 0; r < REPS; r++) {
                switch (v) {
                case 0: apply_ptr(buf, N, &cfg);        break;
                case 1: apply_val(buf, N, cfg);         break;
                case 2: apply_restrict(buf, N, &cfg);   break;
                case 3: apply_ptr_float(buf, N, &cfgf); break;
                }
            }
            double dt = now_sec() - t0;
            if (dt < best[v]) best[v] = dt;
            sums[v] = checksum(buf, N);
        }
    }

    double elems = (double)N * REPS;
    for (int v = 0; v < 4; v++)
        printf("A.%s.ns_per_elem=%.4f\n", names[v], best[v] / elems * 1e9);
    for (int v = 0; v < 4; v++)
        printf("A.%s.speedup=%.4f\n", names[v], best[0] / best[v]);

    int ok = (sums[0] == sums[1]) && (sums[1] == sums[2]) && (sums[2] == sums[3]);
    printf("A.checksums_identical=%d\n", ok);
    printf("A.checksum=%016llx\n", (unsigned long long)sums[0]);

    free(buf);
}

/* ---------------- Suite B: pointer accumulator ---------------- */

static void suite_b(void)
{
    size_t n = N;
    int64_t *xi = aligned_alloc(64, n * sizeof *xi);
    double  *xd = aligned_alloc(64, n * sizeof *xd);
    if (!xi || !xd) exit(1);
    for (size_t i = 0; i < n; i++) {
        xi[i] = (int64_t)(i & 7);
        xd[i] = 1.0 / (double)(i + 1);
    }

    static const char *names[3] = { "ptr", "restrict", "local" };
    double bi[3] = { 1e30, 1e30, 1e30 }, bd[3] = { 1e30, 1e30, 1e30 };
    int64_t ri[3] = { 0, 0, 0 };
    double  rd[3] = { 0, 0, 0 };

    for (int t = 0; t < TRIALS; t++) {
        for (int v = 0; v < 3; v++) {
            int64_t s = 0;
            double t0 = now_sec();
            for (int r = 0; r < REPS; r++) {
                s = 0;
                if      (v == 0) isum_ptr(&s, xi, n);
                else if (v == 1) isum_restrict(&s, xi, n);
                else             isum_local(&s, xi, n);
            }
            double dt = now_sec() - t0;
            if (dt < bi[v]) bi[v] = dt;
            ri[v] = s;
        }
        for (int v = 0; v < 3; v++) {
            double s = 0;
            double t0 = now_sec();
            for (int r = 0; r < REPS; r++) {
                s = 0;
                if      (v == 0) dsum_ptr(&s, xd, n);
                else if (v == 1) dsum_restrict(&s, xd, n);
                else             dsum_local(&s, xd, n);
            }
            double dt = now_sec() - t0;
            if (dt < bd[v]) bd[v] = dt;
            rd[v] = s;
        }
    }

    double elems = (double)n * REPS;
    for (int v = 0; v < 3; v++) {
        printf("B.int.%s.ns_per_elem=%.4f\n", names[v], bi[v] / elems * 1e9);
        printf("B.int.%s.speedup=%.4f\n", names[v], bi[0] / bi[v]);
    }
    for (int v = 0; v < 3; v++) {
        printf("B.dbl.%s.ns_per_elem=%.4f\n", names[v], bd[v] / elems * 1e9);
        printf("B.dbl.%s.speedup=%.4f\n", names[v], bd[0] / bd[v]);
    }
    printf("B.int.results_identical=%d\n", ri[0] == ri[1] && ri[1] == ri[2]);
    printf("B.dbl.results_identical=%d\n", rd[0] == rd[1] && rd[1] == rd[2]);

    free(xi);
    free(xd);
}

int main(int argc, char **argv)
{
    printf("config.N=%d\nconfig.reps=%d\nconfig.trials=%d\n", N, REPS, TRIALS);
    if (argc > 1 && argv[1][0] == 'b') suite_b();
    else                               suite_a();
    return 0;
}
