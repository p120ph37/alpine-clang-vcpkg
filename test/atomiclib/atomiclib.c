#include "atomiclib.h"
#include <stdatomic.h>

static atomic_int counter = 0;

int atomic_counter_add(int value) {
    return atomic_fetch_add(&counter, value);
}

int atomic_counter_get(void) {
    return atomic_load(&counter);
}

void atomic_counter_reset(void) {
    atomic_store(&counter, 0);
}
