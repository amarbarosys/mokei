#include <stdio.h>
#define M(x) { x }
/* c */
int f(int x) {
    if (x > 1 && x < 9) {
        return 1;
    }
    for (int i = 0; i < 3; i++) {
        x += i;
    }
    return x ? 1 : 0;
}

struct S { int a; };
int main(void) { return f(2); }
