/*
* mandelbrot.c
* Author: Rushy Panchal
* Description: Renders the Mandelbrot Set to an image using an iterated function
*	of z^exp + c, where z starts at c (and c is every point in the complex plane).
*	exp is user-inputted, but the standard Set is created using exp=2.
*/

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>
#include "image.h"

#define XMIN -2.0f
#define XMAX 2.0f
#define YMIN -2.0f
#define YMAX 2.0f
#define LIMIT 2.0f
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
*	const double xmin - minimum x value of the graph
*	const double xmax - maximum x value of the graph
*	const double ymin - minimum y value of the graph
*	const double ymax - maximum y value of the graph
*	const double radius - escape radius of the set
* Returns
*	(Image_T) image of the set
*/
static Image_T generate_mandelbrot_set(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent,
	const double xmin, const double xmax, const double ymin,
	const double ymax, const double radius);

/*
* Generate the Mandelbrot Set and return an image.
* Parameters
*	const size_t width - width of the image
*	const size_t height - height of the image
*	const unsigned long iterations - iterations per pixel
*	const unsigned long exponent - exponent for the set
*	const double xmin - minimum x value of the graph
*	const double xmax - maximum x value of the graph
*	const double ymin - minimum y value of the graph
*	const double ymax - maximum y value of the graph
*	const double radius - escape radius of the set
* Returns
*	(Image_T) image of the set
*/
extern double generate_mandelbrot_set_asm(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent,
	const double xmin, const double xmax, const double ymin,
	const double ymax, const double radius);

/*
* Raise a complex number to a real power. Stores the return value in
* *zreal and *zimag.
* Parameters
*	double *zreal - real part of the complex number
*	double *zimag - imaginary part of the complex number
*	unsigned long exp - real exponent
*	const double real_extra - extra value to add to *zreal (after exponentiation)
*	const double imag_extra - extra value to add to *zimag (after exponentiation)
*/
static inline void crpow(double *zreal,  double *zimag, unsigned long exp,
	const double real_extra, const double imag_extra);

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

	generate_mandelbrot_set_asm(width, height, iterations, exponent,
		XMIN, XMAX, YMIN, YMAX, LIMIT);
	exit(0);

	/* Generate the Mandelbrot Set and try to save it to a file. */
	image = generate_mandelbrot_set(width, height, iterations, exponent,
		XMIN, XMAX, YMIN, YMAX, LIMIT);
	if (! Image_save(image, path)) {
		fprintf(stderr, "Error saving to file %s\n", path);
		}
	Image_free(image);

	return 0;
	}

/* Generate the Mandelbrot Set and return an image. */
static Image_T generate_mandelbrot_set(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent,
	const double xmin, const double xmax, const double ymin,
	const double ymax, const double radius) {
	Image_T image = NULL; /* resulting image */

	/* The scales are used to map each pixel to the appropriate Cartestian
	coordinate. */
	const double x_scale = (xmax - xmin) / width; /* scale of the x plane */
	const double y_scale = (ymax - ymin) / height; /* scale of the y plane */
	const double limit = radius * radius; /* radius squared avoids taking the
	square root in abs(z). */

	double x; /* x coordinate */
	double y; /* y coordinate */
	size_t w; /* iterating width */
	size_t h; /* iterating height */
	double zreal; /* real part of the complex number */
	double zimag; /* imaginary part of the complex number */
	unsigned long iter; /* current iteration */
	bool draw; /* whether or not to draw the pixel */

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
	for (x = xmin, w = 0; w < width; x += x_scale, w++) {
		for (y = ymin, h = 0; h < height; y += y_scale, h++) {
			/* Convert the (x, y) coordinate to a complex number. */
			zreal = x;
			zimag = y;

			draw = true;
			/* Iterate the function z^exponent + c as long as it stays within
			the given limit.
			Note: for performance, this loop is unrolled. This means that
			only half the iterations are perfomed but the main calculation
			in each iteration is done twice per unrolled iteration. */
			if (iterations % 2 == 1) crpow(&zreal, &zimag, exponent, x, y);

			for (iter = 0; iter < iterations / 2; iter++) {
				crpow(&zreal, &zimag, exponent, x, y);
				crpow(&zreal, &zimag, exponent, x, y);

				/* If it passes the limit, do not draw the point. Also, no need
				to iterate further as any further iterations will also pass the limit. */
				if ((zreal * zreal + zimag * zimag) > limit) {
					draw = false;
					break;
					}
				}

			if (draw) Image_setPixel(image, w, h, 0, 0, 255);
			}
		}

	return image;
	}

/* Raise a complex number to a real power and add extra real/imaginary parts
to the result. */
static inline void crpow(double *zreal, double *zimag, unsigned long exp,
	const double real_extra, const double imag_extra) {
	double wreal = *zreal; /* real part of result */
	double wimag = *zimag; /* imaginary part of result */
	double wreal_temp; /* temporary storage of real part */

	if (exp == 0) {
		*zreal = 1;
		*zimag = 0;
		return;
		}

	/* We decrement from the beginning because w starts at z, and so
	we only need to iterate exp - 1 times. */
	while (--exp) {
		wreal_temp = (*zreal * wreal - *zimag * wimag);
		wimag = (*zreal * wimag + *zimag * wreal);
		wreal = wreal_temp;
		}
	
	*zreal = wreal + real_extra;
	*zimag = wimag + imag_extra;
	}
