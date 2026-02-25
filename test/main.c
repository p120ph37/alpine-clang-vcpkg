#include <stdio.h>
#include <zlib.h>
#include "mylib.h"
#include <atomiclib.h>

int main(void) {
    printf("result = %d\n", used_func());
    printf("zlib version = %s\n", zlibVersion());
    atomic_counter_add(42);
    printf("atomic result = %d\n", atomic_counter_get());
    return 0;
}
