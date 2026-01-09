#include <stdio.h>

// Simplest kitty protocol implementation example

int main(void) {
    printf("\e[>1u"); // enable kitty mode
    printf("\e[=\b10;1u"); // activate event visu

    while (1) {
        int ch = getchar();
        if (ch == EOF) {
            break;
        }
        if (ch == 'q') {
            break;
        }
        putchar(ch);
    }
    return 0;
}