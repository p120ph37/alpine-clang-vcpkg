#ifndef ATOMICLIB_H
#define ATOMICLIB_H

/* Thread-safe atomic counter.
 *
 * On aarch64, atomic operations may generate calls to compiler-rt outline
 * atomics (__aarch64_cas4_acq, etc.) which in turn call getauxval() from
 * libc to detect LSE support.  When this library is statically linked,
 * the linker must resolve: app → atomiclib → compiler-rt → libc.a.
 */

int atomic_counter_add(int value);
int atomic_counter_get(void);
void atomic_counter_reset(void);

#endif
