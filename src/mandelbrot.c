/*
* mandelbrot.c
* Author: Rushy Panchal
* Description: Renders the Mandelbrot Set to an image using an iterated function
*	of z^exp + c, where z starts at c (and c is every point in the complex plane).
*	exp is user-inputted, but the standard Set is created using exp=2.
*/

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <assert.h>
#include "image.h"
#include "mandelbrot.h"

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

/*
* Generate the Mandelbrot Set with the given settings, saving it to a file.
* Command-Line Arguments
*	char *path - path of the file to save the image to (default: mandelbrot.png)
*	size_t width - width of the image in pixels (default: 1000)
*	size_t height - height of the image in pixels (default: 1000)
*	unsigned long iterations - number of iterations to use per point (default: 100)
*	unsigned long exponent - exponent of the Mandelbrot Set (default: 2)
*
* Note:
*	width and height should be even - they are made even if not provided as such.
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

	/* Width and height must be even for parallel processing. */
	if (width % 2 == 1) {
		printf("Width was decreased by one so that it is even.\n");
		width--;
		}
	if (height % 2 == 1) {
		printf("Height was decreased by one so that it is even.\n");
		height--;
		}

	printf("Configuration\n\tFile: %s\n\tSize (Width x Height): %lu x %lu px\n\
\tIterations: %lu\n\tExponent: %lu\n",
		path, width, height, iterations, exponent);

	/* Generate the Mandelbrot Set and try to save it to a file. */
	image = generate_mandelbrot_set(width, height, iterations, exponent,
		XMIN, XMAX, YMIN, YMAX, LIMIT);
	if (! Image_save(image, path)) {
		fprintf(stderr, "Error saving to file %s\n", path);
		}
	Image_free(image);

	return 0;
	}
