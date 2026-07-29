#ifndef KERNELS_H
#define KERNELS_H

#include <stddef.h>

/* Integer config: members are `int`, the same type the kernel writes through.
 * Type-based alias analysis therefore CANNOT rule out aliasing. */
struct Config {
    int scale;
    int offset;
};

/* Float config: members are `float`, a different type from the `int` the
 * kernel writes. Under strict aliasing the compiler may assume no overlap. */
struct ConfigF {
    float scale;
    float offset;
};

/* The same arithmetic, four ways of handing the two parameters over. */
void apply_ptr(int *out, size_t n, const struct Config *cfg);
void apply_val(int *out, size_t n, struct Config cfg);
void apply_restrict(int *out, size_t n, const struct Config *restrict cfg);
void apply_ptr_float(int *out, size_t n, const struct ConfigF *cfg);

#endif
