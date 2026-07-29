/* Kernels live in their own translation unit on purpose.
 *
 * If these bodies were visible to the benchmark loop, the compiler would
 * inline them, see the actual objects behind both parameters, prove they do
 * not overlap, and every difference measured in this experiment would vanish.
 * That is not a flaw in the experiment; it is the single most important
 * caveat about it, so the setup makes the call boundary real and explicit.
 */

#include "kernels.h"

/* (1) By pointer. `out` writes `int`; `cfg->scale` reads `int`.
 * Same type, so the write MAY land on the config. The compiler is obliged to
 * re-read scale and offset on every single iteration. */
void apply_ptr(int *out, size_t n, const struct Config *cfg)
{
    for (size_t i = 0; i < n; i++)
        out[i] = out[i] * cfg->scale + cfg->offset;
}

/* (2) By value. `cfg` is a private copy whose address is never taken, so no
 * store through `out` can possibly reach it. Both fields are hoisted into
 * registers before the loop starts. */
void apply_val(int *out, size_t n, struct Config cfg)
{
    for (size_t i = 0; i < n; i++)
        out[i] = out[i] * cfg.scale + cfg.offset;
}

/* (3) By pointer, with a promise. `restrict` tells the compiler that the
 * object reached through `cfg` is not reached through any other pointer here.
 * The promise is unverified: break it and the behaviour is undefined. */
void apply_restrict(int *out, size_t n, const struct Config *restrict cfg)
{
    for (size_t i = 0; i < n; i++)
        out[i] = out[i] * cfg->scale + cfg->offset;
}

/* (4) By pointer, different member type. Nothing here promises anything, but
 * an `int` store cannot legally alias a `float` object, so type-based alias
 * analysis alone is enough to hoist the loads. */
void apply_ptr_float(int *out, size_t n, const struct ConfigF *cfg)
{
    for (size_t i = 0; i < n; i++)
        out[i] = out[i] * (int)cfg->scale + (int)cfg->offset;
}
