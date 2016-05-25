/*
* mandelbrot.c
* Author: Rushy Panchal
* Description: Renders the Mandelbrot set using a 
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

/* --- Internal Method Prototypes --- */
/*
* Generate the Mandelbrot Set and return an image.
* Parameters
*	size_t width - width of the image
*	size_t height - height of the image
*	unsigned long iterations - iterations per pixel
*	unsigned long exponent - exponent for the set
* Returns
*	(Image_T) image of the set
*/
static Image_T generate_mandelbrot_set(size_t width, size_t height,
	unsigned long iterations, unsigned long exponent);

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
	char *path = "mandelbrot.png"; /* path of the file to save the image to */
	size_t width = 1000; /* width of the image */
	size_t height = 1000; /* height of the image */
	unsigned long iterations = 100; /* number of iterations to use per point */
	unsigned long exponent = 2; /* exponent to use of the Mandelbrot Set */

	Image_T image = NULL; /* resulting image of Mandelbrot set. */

	switch (argc) {
		case 6:
			exponent = strtoul(argv[5], NULL, 0);
		case 5:
			iterations = strtoul(argv[4], NULL, 0);
		case 4:
			height = (size_t) strtoul(argv[3], NULL, 0);
		case 3:
			width = (size_t) strtoul(argv[2], NULL, 0);
		case 2:
			path = argv[1];
		}

	printf("Configuration\n\tFile: %s\n\tSize (Width x Height): %lu x %lu px\n\
\tIterations: %lu\n\tExponent: %lu\n",
		path, width, height, iterations, exponent);

	image = generate_mandelbrot_set(width, height, exponent, iterations);
	if (! Image_save(image, path)) {
		fprintf(stderr, "Error saving to file %s\n", path);
		exit(EXIT_FAILURE);
		}

	return 0;
	}

/* Generate the Mandelbrot Set and return an image. */
static Image_T generate_mandelbrot_set(size_t width, size_t height,
	unsigned long iterations, unsigned long exponent) {
	Image_T image; /* resulting image */
	double x_scale; /* scale of the x plane */
	double y_scale; /* scale of the y plane */

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
	assert(exponent > 0);

	image = Image_new(width, height);
	if (image == NULL) {
		fprintf(stderr, "Memory error.\n");
		exit(EXIT_FAILURE);
		}

	/* The scales are used to map each pixel to the appropriate Cartestian
	coordinate. */
	x_scale = (XMAX - XMIN) / width;
	y_scale = (YMAX - YMIN) / height;

	for (w = 0; w < width; w++) {
		x =  x_scale * w + XMIN;
		for (h = 0; h < height; h++) {
			y = YMAX - y_scale * h;

			cpoint = x + y * I;
			z = cpoint;

			draw = true;
			for (iter = 0; iter < iterations; iter++) {
				z = cpow(z, exponent) + cpoint;
				if (cabs(z) > LIMIT) {
					draw = false;
					break;
					}
				}

			if (draw) Image_setPixel(image, w, h, 0, 255, 0);
			// if (draw) printf("(%f, %f) ", x, y);
			}
		// printf("\n");
		}

	return image;
	}
