/*
* generate_mandelbrot_set.c
* Author: Rushy Panchal
* Description: Generates the Mandelbrot Set and returns an Image_T object
*	containing a visual representation of the set.
*/

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <assert.h>
#include "image.h"
#include "mandelbrot.h"

/* --- Internal Method Prototypes --- */
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

/* Generate the Mandelbrot Set and return an image. */
Image_T generate_mandelbrot_set(const size_t width, const size_t height,
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