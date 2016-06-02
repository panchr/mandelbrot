# mandelbrot
*A Mandelbrot image generator written in C and optimized in x86*

**Note: currently, the `x86-64` language used is the `Mach-O` format (for OS X). It is
written using the AT&T format of `x86-64`.
Assembly language is not very portable, and so it might not run/assemble
properly on other machines and configurations.**

## Introduction
This project was created as an experiment to see how much optimization
could be done in `x86-64` - in addition, I wanted to see if I could beat the compiler's
`-O3` optimization level.

## Configuration
I am running all of my tests on an Early 2015 Macbook Pro with an Intel i5 running
OS X 10.11.5 (El Capitan).

All of the compilation flags can be seen in the Makefile. Note that although I am
using `gcc` in the Makefile, this defaults to `clang`.

To facilitate reading from/writing to PNG images, I am using `libpng 1.6.21`, which
I installed with [Homebrew](http://brew.sh).

For debugging purposes, I used `gdb` (also installed via Homebrew) and then
`Instruments` for profiling code.

## Optimization Attempts
Here, I go through a list of my attempted optimizations and their results.

### C Optimization
My first goal was to optimize the C code.

To begin, I thought I could stop using `cpow`, as this was designed to raise a complex
number to a complex power. However, my Mandelbrot Set would only be rendered
with real, integer exponents. So,I rolled out my own complex exponentiation
function, called `crpow`, which was essentially just an iterated multiplication:

```C
double complex crpow(double complex z, unsigned long exp) {
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

### First `x86-64` Version
Then, I rewrote all of the C code in `x86-64`. To help figure out some of the trickier
aspects that were more difficult to find online (such as converting an integer to a
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

Once rewritten in `x86-64`, I needed to figure out what I could optimize. The first step
was avoiding all use of memory and only using `XMM` registers. This was simple,
but then I realized that there was a lot of movement to/from memory for each call of
`Image_setPixel` because I had to preserve the state of the `XMM` registers.
Worse yet, these calls occured in a nested loop, so it could occur (in theory, of course) a maximum of `width * height` times, which was excessive.

To do so, I moved all of the local variables to callee-saved `XMM` registers which allows
me to avoid most of the data movement.

*Note: this technically occurred separately in both the `dev-x86-packed-parallel` and
`dev-x86-packed` branches.*

### Packed Double Optimization Attempt 1
Because I had never used `XMM` registers prior to this project, I had no idea how
to make use of the fact that the `XMM` registers are 128 bits, except I knew that
there were instructions that operated on "packed" `double`s.

Initially, I tried to store a complex number in a single register, by storing the
real part in the high quadword and imaginary part in the real quadword. This was
not arbitrary, however - the imaginary part changes more often, because the outer
loop was iterating width and the inner loop was iterating height. When the height
changes, the imaginary part also changes, and thus it made sense to place
the imaginary part in the low quadword, as this was easier to operate on.

I propagated these changes throughout, but ultimately found that this was
actually slower than the initial attempt.

From a brief analysis, this seemed to be due to the complexity of some of the
arithmetic. For example, although horizontal arithmetic (across the low/high
quadwords of a register) could be performed easily, numerous instructions
were still required for most operations. Namely, `crpow` required me to use
multiple `shufpd` instructions (which switch the low/high quadwords) to
properly use other instructions. Overall, although fewer registers were used,
this approach did not work.
