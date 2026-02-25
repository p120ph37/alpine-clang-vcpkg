#include <stdio.h>
#include <stdatomic.h>
#include <zlib.h>
#include "mylib.h"

int main(void) {
    /* Verify vcpkg-installed zlib is properly linked. */
    unsigned long len = compressBound(1);
    unsigned char buf[64];
    unsigned char src = 0;
    if (compress(buf, &len, &src, 1) != Z_OK) {
        fprintf(stderr, "zlib compress failed\n");
        return 1;
    }

    /* On aarch64, atomics use outline helpers that call getauxval() from
       libc — exercising the compiler-rt ↔ libc circular dependency. */
    atomic_int x = 0;
    atomic_fetch_add(&x, 1);
    if (atomic_load(&x) != 1) {
        fprintf(stderr, "atomic operation failed\n");
        return 1;
    }

    printf("result = %d\n", used_func());
    return 0;
}
