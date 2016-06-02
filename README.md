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

## Optimization Attempts
Here, I go through a list of my attempted optimizations and their results.

### In C
My first goal was to optimize the C code.

To begin, I thought I could stop using `cpow`, as this was designed to raise a complex
number to a complex power. However, my Mandelbrot Set would only be rendered
with real, integer exponents. So,I rolled out my own complex exponentiation
function, called `crpow`, which was essentially just an iterated multiplication:

```C
static double complex crpow(double complex z, unsigned long exp) {
	double complex w = z;
	if (exp-- == 0) return 1;
	while (exp--) w *= z;
	return w;
	}
```

This led to a pretty substantial improvement in speed (something around **25%** or
more), but there was still more to be done. Why rely on the `complex.h` library at all?

To avoid relying on it, I simply used two `double`s to store the real and imaginary
parts of the complex number, and passed in pointers to those `double`s. My
reasoning to use pointers was to simplify returning the result; they were stored
directly into the input pointers. The function later evolved into adding in the `c`
value as well, to simplify the overall computations. In this case, `c` is the point being
currently examined.

Once this was done, I could completely remove my reliance on `cabs` as well, because
I could compute the sum of the squared real/imaginary parts, and compare that to
the squared limit - this avoids computing an expensive square root.

### First x86-64 Version
Then, I rewrote all of the C code in x86-64. To help figure out some of the trickier
aspects that were more difficult to lookup (such as converting an integer to a
double), I often wrote short snippets of code and then compiled them using
`gcc -c -S test.c -o test.s`:

```C
double toDouble(int n) {
	return (double) n;
	}

int main(void) {
	int x = 25;
	double f = toDouble(x); 
	return 0;
	}
```
