#include "mylib.h"
#include <stdatomic.h>

/* Use atomics inside the library so that on arm64, the static archive
   contains references to compiler-rt's outline atomic helpers.  This
   exercises the circular dependency: libmylib.a → compiler-rt → libc. */
static atomic_int counter = 0;

int used_func(void) {
    atomic_fetch_add(&counter, 1);
    return 41 + atomic_load(&counter);
}

int unused_func(void) {
    return 99;
}
