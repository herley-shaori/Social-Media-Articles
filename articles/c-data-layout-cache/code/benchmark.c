#define _POSIX_C_SOURCE 200809L

#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/*
 * The two layouts intentionally represent exactly the same 256-byte particle.
 * The update needs only x and vx.  Everything else is cold data that
 * a natural, object-shaped layout puts beside the fields on the hot path.
 */
typedef struct {
    float x, vx;
    float cold[62];
} Particle;

_Static_assert(sizeof(Particle) == 256, "Particle must occupy four cache lines");

typedef struct {
    float *x, *vx;
    float *cold; /* n * 62 floats */
} ParticlesSoA;

static volatile uint64_t sink;

static void *allocate(size_t bytes) {
    void *pointer = NULL;
    if (posix_memalign(&pointer, 64, bytes) != 0 || pointer == NULL) {
        fprintf(stderr, "allocation failed for %zu bytes\n", bytes);
        exit(1);
    }
    return pointer;
}

static uint32_t next_random(uint32_t *state) {
    *state = *state * 1664525u + 1013904223u;
    return *state;
}

static float random_unit(uint32_t *state) {
    return (float)(next_random(state) >> 8) * (1.0f / 16777216.0f);
}

static void init_aos(Particle *particles, size_t count) {
    uint32_t state = 0xC0FFEEu;
    for (size_t i = 0; i < count; ++i) {
        Particle *p = &particles[i];
        p->x = random_unit(&state);
        p->vx = random_unit(&state) - 0.5f;
        for (size_t j = 0; j < 62; ++j) p->cold[j] = random_unit(&state);
    }
}

static ParticlesSoA allocate_soa(size_t count) {
    ParticlesSoA p;
    p.x = allocate(count * sizeof(*p.x));
    p.vx = allocate(count * sizeof(*p.vx));
    p.cold = allocate(count * 62 * sizeof(*p.cold));
    return p;
}

static void free_soa(ParticlesSoA *p) {
    free(p->x); free(p->vx); free(p->cold);
}

static void init_soa(ParticlesSoA *p, size_t count) {
    uint32_t state = 0xC0FFEEu;
    for (size_t i = 0; i < count; ++i) {
        p->x[i] = random_unit(&state);
        p->vx[i] = random_unit(&state) - 0.5f;
        for (size_t j = 0; j < 62; ++j) p->cold[i * 62 + j] = random_unit(&state);
    }
}

__attribute__((noinline))
static void update_aos(Particle *particles, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        particles[i].x += particles[i].vx * 0.016f;
    }
}

__attribute__((noinline))
static void update_soa(float *restrict x, const float *restrict vx, size_t count) {
    /* Each field is separately allocated. This function signature records
       that guarantee; layout is the independent variable, not pointer alias. */
    for (size_t i = 0; i < count; ++i) {
        x[i] += vx[i] * 0.016f;
    }
}

static void (*volatile aos_sweep)(Particle *, size_t) = update_aos;
static void (*volatile soa_sweep)(float *restrict, const float *restrict, size_t) = update_soa;

static uint64_t checksum_aos(const Particle *particles, size_t count) {
    uint64_t hash = 1469598103934665603ULL;
    for (size_t i = 0; i < count; ++i) {
        uint32_t bits;
        memcpy(&bits, &particles[i].x, sizeof(bits));
        hash = (hash ^ bits) * 1099511628211ULL;
    }
    return hash;
}

static uint64_t checksum_soa(const ParticlesSoA *particles, size_t count) {
    uint64_t hash = 1469598103934665603ULL;
    for (size_t i = 0; i < count; ++i) {
        uint32_t bits;
        memcpy(&bits, &particles->x[i], sizeof(uint32_t));
        hash = (hash ^ bits) * 1099511628211ULL;
    }
    return hash;
}

static double seconds_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1000000000.0;
}

static int compare_hot_fields(const Particle *aos, const ParticlesSoA *soa, size_t count) {
    for (size_t i = 0; i < count; ++i) {
        if (memcmp(&aos[i].x, &soa->x[i], sizeof(float)) != 0) return 0;
    }
    return 1;
}

static double benchmark_aos(Particle *particles, size_t count, unsigned steps) {
    const double start = seconds_now();
    for (unsigned step = 0; step < steps; ++step) aos_sweep(particles, count);
    const double elapsed = seconds_now() - start;
    sink ^= checksum_aos(particles, count);
    return elapsed;
}

static double benchmark_soa(ParticlesSoA *particles, size_t count, unsigned steps) {
    const double start = seconds_now();
    for (unsigned step = 0; step < steps; ++step) {
        soa_sweep(particles->x, particles->vx, count);
    }
    const double elapsed = seconds_now() - start;
    sink ^= checksum_soa(particles, count);
    return elapsed;
}

static int compare_double(const void *left, const void *right) {
    const double a = *(const double *)left;
    const double b = *(const double *)right;
    return (a > b) - (a < b);
}

static double median(double *values, size_t count) {
    qsort(values, count, sizeof(*values), compare_double);
    return values[count / 2];
}

static void run_case(size_t count) {
    enum { trials = 7, steps = 120 };
    Particle *aos = allocate(count * sizeof(*aos));
    ParticlesSoA soa = allocate_soa(count);
    double aos_times[trials], soa_times[trials];

    init_aos(aos, count);
    init_soa(&soa, count);
    for (unsigned step = 0; step < 3; ++step) {
        aos_sweep(aos, count);
        soa_sweep(soa.x, soa.vx, count);
    }
    if (!compare_hot_fields(aos, &soa, count)) {
        fprintf(stderr, "correctness check failed for count=%zu\n", count);
        exit(1);
    }

    for (size_t trial = 0; trial < trials; ++trial) {
        init_aos(aos, count);
        aos_times[trial] = benchmark_aos(aos, count, steps);
        init_soa(&soa, count);
        soa_times[trial] = benchmark_soa(&soa, count, steps);
    }

    const double aos_median = median(aos_times, trials);
    const double soa_median = median(soa_times, trials);
    const double updates = (double)count * steps;
    printf("result,count=%zu,working_set_mib=%.2f,aos_ms=%.3f,soa_ms=%.3f,aos_mupdates_s=%.2f,soa_mupdates_s=%.2f,speedup=%.2f,correct=1\n",
           count, (double)(count * sizeof(*aos)) / (1024.0 * 1024.0),
           aos_median * 1000.0, soa_median * 1000.0,
           updates / aos_median / 1000000.0, updates / soa_median / 1000000.0,
           aos_median / soa_median);

    free(aos);
    free_soa(&soa);
}

int main(void) {
    const size_t cases[] = {1000, 10000, 100000, 524288};
    printf("metadata,compiler=%s\n", __VERSION__);
    printf("metadata,particle_bytes=%zu,trials=7,steps_per_trial=120\n", sizeof(Particle));
    printf("result,count,working_set_mib,aos_ms,soa_ms,aos_mupdates_s,soa_mupdates_s,speedup,correct\n");
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) run_case(cases[i]);
    fprintf(stderr, "sink=%" PRIu64 "\n", sink);
    return 0;
}
