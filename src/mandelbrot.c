/*
* mandelbrot.c
* Author: Rushy Panchal
* Description: Renders the Mandelbrot Set to an image using an iterated function
*	of z^exp + c, where z starts at c (and c is every point in the complex plane).
*	exp is user-inputted, but the standard Set is created using exp=2.
*/

#include <stdio.h>
#include <stdlib.h>
#include <complex.h>
#include <math.h>
#include <assert.h>
#include "image.h"

#define XMIN -2.0
#define XMAX 2.0
#define YMIN -2.0
#define YMAX 2.0
#define LIMIT 2.0
#define DEFAULT_FILE "mandelbrot.png"
#define DEFAULT_WIDTH 1000
#define DEFAULT_HEIGHT 1000
#define DEFAULT_ITERATIONS 100
#define DEFAULT_EXPONENT 2

/* --- Internal Method Prototypes --- */
/*
* Generate the Mandelbrot Set and return an image.
* Parameters
*	const size_t width - width of the image
*	const size_t height - height of the image
*	const unsigned long iterations - iterations per pixel
*	const unsigned long exponent - exponent for the set
* Returns
*	(Image_T) image of the set
*/
static Image_T generate_mandelbrot_set(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent);

/*
* Raise a complex number to a real power.
* Parameters
*	const double complex z - complex base
*	unsigned long exp - real exponent
* Returns
*	(double complex) z^exp
*/
static inline double complex crpow(const double complex z, unsigned long exp);

/*
* Generate the Mandelbrot Set with the given settings, saving it to a file.
* Command-Line Arguments
*	char *path - path of the file to save the image to (default: mandelbrot.png)
*	size_t width - width of the image in pixels (default: 1000)
*	size_t height - height of the image in pixels (default: 1000)
*	unsigned long iterations - number of iterations to use per point (default: 100)
*	unsigned long exponent - exponent of the Mandelbrot Set (default: 2)
*/
int main(int argc, char *argv[]) {
	/* Command-line arguments. */
	char *path = DEFAULT_FILE; /* path of the file to save the image to */
	size_t width = DEFAULT_WIDTH; /* width of the image */
	size_t height = DEFAULT_HEIGHT; /* height of the image */
	unsigned long iterations = DEFAULT_ITERATIONS; /* number of iterations
	to use per point */
	unsigned long exponent = DEFAULT_EXPONENT; /* exponent to use for
	the Mandelbrot Set */

	Image_T image = NULL; /* resulting image of Mandelbrot set. */

	/* There are no breaks (until the last case) because if argc = n,
	we also want to run the (n - w) case for w in {0, n - 1} as all of those
	arguments also need to be processed - they are present in the command-line
	arguments. */
	switch (argc) {
		case 6: /* argv[5] is the exponent */
			exponent = strtoul(argv[5], NULL, 0);
		case 5: /* argv[4] is the number of iterations */
			iterations = strtoul(argv[4], NULL, 0);
		case 4: /* argv[3] is the height */
			height = (size_t) strtoul(argv[3], NULL, 0);
		case 3: /* argv[2] is the width */
			width = (size_t) strtoul(argv[2], NULL, 0);
		case 2: /* argv[1] is the path */
			path = argv[1];
			break;
		}

	printf("Configuration\n\tFile: %s\n\tSize (Width x Height): %lu x %lu px\n\
\tIterations: %lu\n\tExponent: %lu\n",
		path, width, height, iterations, exponent);

	/* Generate the Mandelbrot Set and try to save it to a file. */
	image = generate_mandelbrot_set(width, height, iterations, exponent);
	if (! Image_save(image, path)) {
		fprintf(stderr, "Error saving to file %s\n", path);
		}
	Image_free(image);

	return 0;
	}

/* Generate the Mandelbrot Set and return an image. */
static Image_T generate_mandelbrot_set(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent) {
	Image_T image = NULL; /* resulting image */

	/* The scales are used to map each pixel to the appropriate Cartestian
	coordinate. */
	const double x_scale = (XMAX - XMIN) / width; /* scale of the x plane */
	const double y_scale = (YMAX - YMIN) / height; /* scale of the y plane */

	double x; /* x coordinate */
	double y; /* y coordinate */
	size_t w; /* iterating width */
	size_t h; /* iterating height */
	double complex cpoint; /* current iterating point in the plane */
	double complex z; /* current iterating value in the plane */
	unsigned long iter; /* current iteration */
	bool draw; /* whether or not to draw the pixel. */

	assert(width >= 0);
	assert(height >= 0);
	assert(iterations >= 0);
	assert(exponent >= 0);

	image = Image_new(width, height);
	if (image == NULL) {
		fprintf(stderr, "Memory error when creating image.\n");
		exit(EXIT_FAILURE);
		}

	/* Iterate through the pixels in the image, mapping each to a single
	point in the xy-plane. */
	for (x = XMIN, w = 0; w < width; x += x_scale, w++) {
		for (y = YMIN, h = 0; h < height; y += y_scale, h++) {
			/* Convert the (x, y) coordinate to a complex number. */
			cpoint = x + y * I;
			z = cpoint;

			draw = true;
			/* Iterate the function z^exponent + c as long as it stays within
			the given limit.
			Note: for performance, this loop is unrolled. This means that
			only half the iterations are perfomed but the main calculation
			in each iteration is done twice per unrolled iteration. */
			if (iterations % 2 == 1) z = crpow(z, exponent) + cpoint;
			for (iter = 0; iter < iterations / 2; iter++) {
				z = crpow(z, exponent) + cpoint;
				z = crpow(z, exponent) + cpoint;

				/* Passed the limit, so do not draw the point. Also, no need
				to iterate further. */
				if (cabs(z) > LIMIT) {
					draw = false;
					break;
					}
				}

			if (draw) Image_setPixel(image, w, h, 0, 0, 255);
			}
		}

	return image;
	}

/* Raise a complex number to a real power. */
static inline double complex crpow(const double complex z, unsigned long exp) {
	double complex w = z; /* iterated exponent*/

	if (exp == 0) return 1;

	/* We decrement from the beginning because w starts at z, and so
	we only need to iterate exp - 1 times. */
	while (--exp) w *= z;
	return w;
	}
