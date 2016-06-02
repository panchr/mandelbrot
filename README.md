# mandelbrot
*A Mandelbrot image generator written in C and optimized in x86*

**Note: currently, the `x86-64` language used is in the AT&T format while being
assembled for [`Mach-O`](https://en.wikipedia.org/wiki/Mach-O) (for OS X).
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

### Building
To build, you must have `make` installed (along with the other pre-requisites listed
above).Then, simply run `make` in the root project directory and it should be built.
Again, assembly is not very portable so it will not build on most systems.

`make debug` builds a debugging version (specifically, with the `-g` flag to `gcc`).
Similarly, `make profile` builds a profiling version (with the `-pg` flags).
Finally, `make test` with optional parameters (see [below](#final-timing-tests))
will run time the `x86-64` optimized version and compare it to the regular C
version.

## Optimization Attempts
### C Optimization
My first goal was to optimize the C code.

To begin, I thought I could stop using `cpow`, as this was designed to raise a complex
number to a complex power. However, my Mandelbrot Set would only be rendered
with real, integer exponents. So, I rolled out my own complex exponentiation
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
value to simplify the overall computations. In this case, `c` is the point being
currently examined (the Mandelbrot Set for an exponent `e` at a point `c`
is the iterated value of `z^e + c` where `z` starts at `c`).

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

In addition, I designed my subroutines (at this point, only `crpow`) to not act as
direct functions. In that sense, they break the `x86-64` conventions because
arguments are not passed to them using the proper registers. Instead, the
subroutines directly read the proper registers and store the data in the appropriate
places. This was tricky because I had to make sure any temporary registers used
there were not needed elsewhere - to do so, I kept track of what registers were
being used for.

At this point, I unrolled the innermost loop for the iteration of `z^e + c`.
The original loop of

```C
for (iter = 0; iter < iterations; iter++) {
	crpow(&zreal, &zimag, exp, x, y);

	/* test of abs(z)^2 is still within the limit */
	}
```

became

```C
/* Odd number of iterations */
if (iterations % 2 == 1) crpow(&zreal, &zimag, exp, x, y);

/* Iterate half the amount but do twice the work in each iteration. */
for (iter = 0; iter < iterations / 2; iter++) {
	crpow(&zreal, &zimag, exp, x, y);
	crpow(&zreal, &zimag, exp, x, y);

	/* test of abs(z)^2 is still within the limit */
	}
```

The primary goal of loop unrolling is to minimize the number of jumps.
Interestingly, this created an issue in the C version - if `zreal` or `zimag` overflowed
after the first call to `crpow`, then they would be treated as lower than the limit
(because they are now negative after overflowing). I could not fix this, so I removed
the loop unrolling in C. In the `x86-64` version, however, overflow did not cause
any problems - I'm not sure why.

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

### Packed Double Optimization Attempt 2
In the second attempt, I tried a different approach - parallelizing computations using
[SIMD (Single Instruction Multiple Data)](https://en.wikipedia.org/wiki/SIMD).

Instead of storing both parts of a complex number in a single `XMM` register,
I stored two complex numbers across two registers. Interestingly, an instruction
that operates only on the low quadword (i.e 64 bits) and an instruction that
operates on both quadwords (i.e 128 bits) takes the same amount of time. So,
in theory, this would double the speed of the program if implemented correctly.

I decided to parallelize the computation in the width (real) direction, but this is
arbitrary. In addition, I made the choice to enforce an even width/height, just
because it simplified dealing with the case of an odd width (which would cause
the program to go past the array bounds).

The most difficult part about this was properly handling which point(s) should be
drawn. Previously, I removed the entire `draw` boolean which kept track of
whether or not to draw a given point, because this was not necessary with a single
point. Now, however, I had to store these in separate byte-sized registers so that
I could check which points to draw. In addition, I decided to only stop iterating
prematurely if both of the points did not need to be drawn.This prevented a full
doubling of speed, but it simplified the logic - there would be a lot more information
to keep track of if both points were decoupled. In fact, at that point it would be
easier to just deal with them completely independently. Instead, I continue iterating
until either a) both points should not be drawn or b) the iterations complete.
Then, the points that can be drawn are drawn.

A few other minute optimizations included removing extraneous jumps to
simplify logic. For example, the C code

```C
if (absval_squared >= limit) {
	draw = false;
	break;
	}
else { /* placeholder for continuing iteration */ }
```

translates to

```asm
/* absval_squared, limit, and draw are just placeholders for the actual registers */
	cmplepd absval_squared, limit
	movq limit, %rax
	testq %rax, %rax
	jnz in_limit

	movb $0, draw

in_limit:
	/* continue iteration */
```

However, this can be simplified to

```asm
/* absval_squared, limit, and draw are just placeholders for the actual registers */
	cmplepd absval_squared, limit
	movq limit, %rax
	andb %rax, draw
	
	/* continue iteration */
```

Which has fewer branches (for jumps) and instructions while also being simpler.

This is the current level of optimization. Using SIMD instructions led to a nearly 40%
(or higher with large enough iterations/image size) faster program. However,
there are some very minor errors which seem to emerge from floating point error
in large input. For example, with dimensions of `2500x2500`, there is a 7-pixel
difference in the resulting output when compared to the original C program.

To run some of the timing tests, run `make test SIZE={size} ITER={iter} EXP={exp}`,
where `size` is the width and height of the image in pixels, `iter` is the number
of iterations, and `exp` is the exponent to use.

Some time trials are provided below.

## Final Timing Tests

```sh
$ make test
time bin/mandelbrot mandelbrot.png 1000 1000 250 2
Configuration
	File: mandelbrot.png
	Size (Width x Height): 1000 x 1000 px
	Iterations: 250
	Exponent: 2
        0.19 real         0.16 user         0.00 sys
time bin/mandelbrot-x86 mandelbrot-x86.png 1000 1000 250 2
Configuration
	File: mandelbrot-x86.png
	Size (Width x Height): 1000 x 1000 px
	Iterations: 250
	Exponent: 2
        0.12 real         0.11 user         0.00 sys
bin/imgdiff mandelbrot.png mandelbrot-x86.png
Difference
	Count: 0
	Primary Ratio: 0.000000
	Secondary Ratio: 0.000000

$ make SIZE=2500
time bin/mandelbrot mandelbrot.png 2500 2500 250 2
Configuration
	File: mandelbrot.png
	Size (Width x Height): 2500 x 2500 px
	Iterations: 250
	Exponent: 2
        1.03 real         0.98 user         0.02 sys
time bin/mandelbrot-x86 mandelbrot-x86.png 2500 2500 250 2
Configuration
	File: mandelbrot-x86.png
	Size (Width x Height): 2500 x 2500 px
	Iterations: 250
	Exponent: 2
        0.77 real         0.67 user         0.02 sys
bin/imgdiff mandelbrot.png mandelbrot-x86.png
Difference
	Count: 7
	Primary Ratio: 0.000001
	Secondary Ratio: 0.000001
make: *** [test] Error 1

$ make ITER=5000
time bin/mandelbrot mandelbrot.png 1000 1000 5000 2
Configuration
	File: mandelbrot.png
	Size (Width x Height): 1000 x 1000 px
	Iterations: 5000
	Exponent: 2
        1.95 real         1.93 user         0.01 sys
time bin/mandelbrot-x86 mandelbrot-x86.png 1000 1000 5000 2
Configuration
	File: mandelbrot-x86.png
	Size (Width x Height): 1000 x 1000 px
	Iterations: 5000
	Exponent: 2
        1.10 real         1.09 user         0.00 sys
bin/imgdiff mandelbrot.png mandelbrot-x86.png
Difference
	Count: 3
	Primary Ratio: 0.000003
	Secondary Ratio: 0.000003
make: *** [test] Error 1

$ make SIZE=10000 ITER=1000 EXP=5
time bin/mandelbrot mandelbrot.png 10000 10000 1000 5
Configuration
	File: mandelbrot.png
	Size (Width x Height): 10000 x 10000 px
	Iterations: 1000
	Exponent: 5
      158.99 real       158.35 user         0.44 sys
time bin/mandelbrot-x86 mandelbrot-x86.png 10000 10000 1000 5
Configuration
	File: mandelbrot-x86.png
	Size (Width x Height): 10000 x 10000 px
	Iterations: 1000
	Exponent: 5
       92.58 real        91.64 user         0.50 sys
bin/imgdiff mandelbrot.png mandelbrot-x86.png
Difference
	Count: 1348
	Primary Ratio: 0.000013
	Secondary Ratio: 0.000013
make: *** [test] Error 1
```

As shown, the improved `x86-64` version is significantly faster. Although it does
have some error, it not noticeable at all (usually less than 0.002%).
