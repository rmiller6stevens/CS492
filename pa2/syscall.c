#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/syscall.h>

int main(void)
{
char word[] = "testtesttesttesttesttesttesttestt";
printf("before: %s\n", word);
long x = syscall(441, word);
printf("syscall: %ld\n", x);
printf("after: %s\n", word);
return 0;
}
