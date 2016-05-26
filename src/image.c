/*
* image.c
* Author: Rushy Panchal
* Description: A simple ADT to manipulate PNG images. Implements image.h.
*	A lot of the code here is adapted from: http://www.lemoda.net/c/write-png/.
*/

#include <png.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>
#include <assert.h>
#include "image.h"

#define DEPTH 8
#define PIXEL_SIZE 3

/* A Pixel is simply an RGB tuple. */
struct Pixel {
	uint8_t red;
	uint8_t green;	
	uint8_t blue;
	};

struct Image {
	struct Pixel *pixels; /* Pixels in the image, stored in row-major order. */
	size_t width; /* Width of the image. */
	size_t height; /* Height of the image. */
	};

/* --- Internal Method Prototypes --- */
/*
* Get the pixel at a given coordinate.
* Parameters
*	const Image_T image - image to get pixel from
*	const size_t row - row of the pixel
*	const size_t col - column of the pixel
* Returns
*	(struct Pixel*) pixel at (row, col) in the image
*/
static struct Pixel *Image_pixel(const Image_T image, const size_t row,
	const size_t col);

/*
* Free the PNG rows.
* Parameters
*	png_structp png - png struct to free from
*	png_byte **rows - rows to free
*	const size_t count - number of rows
*/
static void Image_freePngRows(png_structp png, png_byte **rows,
	const size_t count);

/* Create a new image of the requested width and height. */
Image_T Image_new(const size_t width, const size_t height) {
	Image_T image; /* image for client */

	assert(width >= 0);
	assert(height >= 0);

	/* Allocate memory for the image object. */
	image = (Image_T) malloc(sizeof(struct Image));
	if (image == NULL) return NULL;

	/* Allocate (zero-cleared) memory for the pixels. */
	image->pixels = (struct Pixel*) calloc(sizeof(struct Pixel), width * height);
	if (image->pixels == NULL) {
		free(image);
		return NULL;
		}

	/* Set the fields of the image. */
	image->width = width;
	image->height = height;

	return image;
	}

/* Free the image. */
void Image_free(Image_T image) {
	if (image != NULL) free(image->pixels);
	free(image);
	}

/* Set the RGB color of the pixel in the image. */
void Image_setPixel(const Image_T image, const size_t row, const size_t col,
	const uint8_t red, const uint8_t green, const uint8_t blue) {
	struct Pixel *pixel = NULL; /* pixel at (row, col) */

	assert(image != NULL);
	assert(row >= 0);
	assert(col >= 0);

	pixel = Image_pixel(image, row, col);

	pixel->red = red;
	pixel->green = green;
	pixel->blue = blue;
	}

/* Save the image at the file path. */
bool Image_save(const Image_T image, const char *path) {
	FILE *fp; /* file pointer to save the image */
	png_structp png = NULL; /* PNG image struct */
	png_infop png_info = NULL; /* PNG image info struct */
	size_t w; /* width iterating index */
	size_t h; /* height iterating index */
	png_byte **row_pointers = NULL; /* png byte data */
	png_byte *row = NULL; /* single row in PNG file */
	struct Pixel *pixel = NULL; /* current pixel */

	assert(image != NULL);
	assert(path != NULL);

	/* Open the file for writing in binary mode. */
	fp = fopen(path, "wb");
	if (fp == NULL) return false;

	/* Create the PNG write struct. */
	png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png == NULL) {
		fclose(fp);
		return false;
		}

	/* Create the PNG info struct. */
	png_info = png_create_info_struct(png);
	if (png_info == NULL) {
		fclose(fp);
		png_destroy_write_struct(&png, &png_info);
		return false;
		}

	/* Error handling. */
	if (setjmp(png_jmpbuf(png))) {
		fclose(fp);
		png_destroy_write_struct(&png, &png_info);
		return false;
		}

	/* Set the information for the image. */
	png_set_IHDR(
		png,
		png_info,
		image->width,
		image->height,
		DEPTH,
		PNG_COLOR_TYPE_RGB,
		PNG_INTERLACE_NONE,
		PNG_COMPRESSION_TYPE_DEFAULT,
		PNG_FILTER_TYPE_DEFAULT);

	/* Allocate memory for the data rows. */
	row_pointers = (png_byte**) png_malloc(png, image->height * sizeof(png_byte*));
	if (row_pointers == NULL) {
		fclose(fp);
		png_destroy_write_struct(&png, &png_info);
		return false;
		}

	/* Set the data in each row. */
	for (h = 0; h < image->height; h++) {
		row = png_malloc(png, sizeof(uint8_t) * image->width * PIXEL_SIZE);
		if (row == NULL) {
			fclose(fp);
			Image_freePngRows(png, row_pointers, h);
			png_destroy_write_struct(&png, &png_info);
			return false;
			}

		row_pointers[h] = row;
		for (w = 0; w < image->width; w++) {
			pixel = Image_pixel(image, w, h);
			*row++ = pixel->red;
			*row++ = pixel->green;
			*row++ = pixel->blue;
			}
		}

	/* Set the rows, initialize I/O, and write the image to the file. */
	png_set_rows(png, png_info, row_pointers);
	png_init_io(png, fp);
	png_write_png(png, png_info, PNG_TRANSFORM_IDENTITY, NULL);

	/* Free all resources used. */
	Image_freePngRows(png, row_pointers, image->height);
	png_destroy_write_struct(&png, &png_info);
	fclose(fp);

	return true;
	}

/* --- Internal Methods --- */
/* Get the pixel at a given coordinate. */
static struct Pixel *Image_pixel(const Image_T image, const size_t row,
	const size_t col) {
	assert(image != NULL);
	assert(row >= 0);
	assert(col >= 0);

	return image->pixels + image->width * col + row;
	}

/* Free the PNG rows. */
static void Image_freePngRows(png_structp png, png_byte **rows,
	const size_t count) {
	size_t iteration; /* iteration count */

	assert(png != NULL);
	assert(rows != NULL);
	assert(count >= 0);

	for (iteration = 0; iteration < count; iteration++)
		png_free(png, rows[iteration]);

	png_free(png, rows);
	}
