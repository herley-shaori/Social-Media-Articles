/* Second workload: an accumulator reached through a pointer.
 *
 * Here aliasing does more than force a reload. `*sum += x[i]` must be STORED
 * on every iteration, because x[i] might be *sum itself. The store lands on
 * the loop's critical path, and no amount of loop versioning removes it.
 *
 * Two element types are provided on purpose. The integer version is bound by
 * the store; the double version is bound by floating-point add latency, which
 * is longer. That difference is the point: the aliasing tax is only visible
 * when it sits on the critical path.
 */

#include <stddef.h>
#include <stdint.h>

/* ---- int64: add latency is 1 cycle, so the store dominates ---- */

void isum_ptr(int64_t *sum, const int64_t *x, size_t n)
{
    for (size_t i = 0; i < n; i++)
        *sum += x[i];
}

void isum_restrict(int64_t *restrict sum, const int64_t *restrict x, size_t n)
{
    for (size_t i = 0; i < n; i++)
        *sum += x[i];
}

/* No keyword needed: a local whose address is never taken cannot be aliased. */
void isum_local(int64_t *sum, const int64_t *x, size_t n)
{
    int64_t acc = *sum;
    for (size_t i = 0; i < n; i++)
        acc += x[i];
    *sum = acc;
}

/* ---- double: FP add latency (~4 cycles) already dominates ---- */

void dsum_ptr(double *sum, const double *x, size_t n)
{
    for (size_t i = 0; i < n; i++)
        *sum += x[i];
}

void dsum_restrict(double *restrict sum, const double *restrict x, size_t n)
{
    for (size_t i = 0; i < n; i++)
        *sum += x[i];
}

void dsum_local(double *sum, const double *x, size_t n)
{
    double acc = *sum;
    for (size_t i = 0; i < n; i++)
        acc += x[i];
    *sum = acc;
}
