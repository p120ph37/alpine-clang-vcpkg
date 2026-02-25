#include <stdio.h>
#include <zlib.h>
#include "mylib.h"

int main(void) {
    printf("result = %d\n", used_func());
    printf("zlib version = %s\n", zlibVersion());
    return 0;
}
