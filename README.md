# mandelbrot
*A Mandelbrot image generator written in C and optimized in x86*

**Note: currently, the x86-64 language used is the Mach-O format (for OS X). It is
written using the AT&T format of x86-64.
Assembly language is not very portable, and so it might not run/assemble
properly on other machines and configurations.**

## Introduction
This project was created as an experiment to see how much optimization
could be done in x86-64 - in addition, I wanted to see if I could beat the compiler's
`-O3` optimization level.

### Configuration
I am running all of my tests on an Early 2015 Macbook Pro with an Intel i5 running
OS X 10.11.5.

All of the compilation flags can be seen in the Makefile. Note that although I am
using `gcc` in the Makefile, this defaults to `clang`.

To facilitate reading from/writing to PNG images, I am using `libpng 1.6.21`, which
I installed with [Homebrew](http://brew.sh).

For debugging purposes, I used `gdb` (also installed via Homebrew) and then
`Instruments` for profiling code.
