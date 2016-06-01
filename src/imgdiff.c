/*
* imgdiff.c
* Author: Rushy Panchal
* Description: Calculate the difference between two images. Returns 0 on difference
*	count of 0 and EXIT_FAILURE on non-zero count.
*/

#include <stdlib.h>
#include <stdio.h>
#include "image.h"

/*
* Calculate the difference between two images.
* Command-Line Arguments
*	char *path - path of the primary image
*	char *other_path - path of the secondary image
*/
int main(int argc, char *argv[]) {
	Image_T image; /* primary image */
	Image_T other_image; /* other image */
	size_t diff; /* image difference */
	double ratio_image; /* image diff to size ratio */
	double ratio_other_image; /* other_image diff to size ratio */

	if (argc != 3) {
		fprintf(stderr, "imgdiff expects exactly two command-line arguments.\n");
		exit(EXIT_FAILURE);
		}

	image = Image_fromFile(argv[1]);
	other_image = Image_fromFile(argv[2]);

	diff = Image_diff(image, other_image);
	ratio_image = (double) diff / Image_getSize(image);
	ratio_other_image = (double) diff / Image_getSize(other_image);

	printf("Difference\n\tCount: %lu\n\tPrimary Ratio: %f\n\t\
Secondary Ratio: %f\n", diff, ratio_image, ratio_other_image);

	if (diff == 0) return 0;
	else return EXIT_FAILURE;
	}
