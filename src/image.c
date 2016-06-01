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

/* Create an image from a file.*/
Image_T Image_fromFile(const char *path) {
	Image_T image = NULL; /* image to return to client */
	FILE *fp = NULL; /* pointer to open file object */
	png_structp png = NULL; /* PNG image struct */
	png_infop png_info = NULL; /* PNG image info struct */
	size_t width; /* width of the image */
	size_t height;  /* height of the image */
	png_byte color_type; /* type of the color */
	png_byte **row_pointers = NULL; /* png byte data */
	png_byte *row = NULL; /* single row in PNG file */
	size_t h; /* current iterating height */
	size_t w; /* current iterating width */
	struct Pixel *pixel; /* current iterating pixel */

	assert(path != NULL);

	/* Open the file for reading in binary mode. */
	fp = fopen(path, "rb");
	if (fp == NULL) return NULL;

	/* Create the PNG read struct. */
	png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if (png == NULL) {
		fclose(fp);
		return NULL;
		}

	/* Create the PNG info struct. */
	png_info = png_create_info_struct(png);
	if (png_info == NULL) {
		fclose(fp);
		png_destroy_read_struct(&png, &png_info, NULL);
		return NULL;
		}

	/* Error handling. */
	if (setjmp(png_jmpbuf(png))) {
		fclose(fp);
		png_destroy_read_struct(&png, &png_info, NULL);
		return NULL;
		}

	/* Start the I/O for the PNG file. */
	png_init_io(png, fp);
	png_read_info(png, png_info);

	/* Read the meta-data of the file. */
	width = (size_t) png_get_image_width(png, png_info);
	height = (size_t) png_get_image_height(png, png_info);
	color_type = png_get_color_type(png, png_info);
	png_read_update_info(png, png_info);

	/* Create the image. */
	image = Image_new(width, height);
	if (image == NULL) {
		fclose(fp);
		png_destroy_read_struct(&png, &png_info, NULL);
		return NULL;
		}

	/* Allocate memory for the data rows. */
	row_pointers = (png_byte**) png_malloc(png, height * sizeof(png_byte*));
	if (row_pointers == NULL) {
		fclose(fp);
		png_destroy_read_struct(&png, &png_info, NULL);
		Image_free(image);
		return NULL;
		}

	for (h = 0; h < height; h++) {
		row = png_malloc(png, sizeof(uint8_t) * width * PIXEL_SIZE);
		if (row == NULL) {
			fclose(fp);
			Image_freePngRows(png, row_pointers, h);
			png_destroy_read_struct(&png, &png_info, NULL);
			Image_free(image);
			return  NULL;
			}
		row_pointers[h] = row;
		}

	/* Read the image into memory. */
	png_read_image(png, row_pointers);
	fclose(fp);

	/* Store the appropriate pixel data in the image. */
	for (h = 0; h < height; h++) {
		row = row_pointers[h];
		for (w = 0; w < width; w++) {
			pixel = Image_pixel(image, w, h);
			pixel->red = *row++;
			pixel->green = *row++;
			pixel->blue = *row++;
			}
		}

	Image_freePngRows(png, row_pointers, height);
	return image;
	}

/* Free the image. */
void Image_free(Image_T image) {
	if (image != NULL) free(image->pixels);
	free(image);
	}

/* Get the width of an image. */
size_t Image_getWidth(const Image_T image) {
	assert(image != NULL);

	return image->width;
	}

/* Get the height of an image. */
size_t Image_getHeight(const Image_T image) {
	assert(image != NULL);

	return image->height;
	}

/* Get the size of an image. */
size_t Image_getSize(const Image_T image) {
	assert(image != NULL);

	return image->width * image->height;
	}

/* Set the RGB color of the pixel in the image. */
void Image_setPixel(const Image_T image, const size_t row, const size_t col,
	const uint8_t red, const uint8_t green, const uint8_t blue) {
	struct Pixel *pixel = NULL; /* pixel at (row, col) */

	assert(image != NULL);
	assert(row >= 0 && row < image->height);
	assert(col >= 0 && col < image->width);

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

/* Count the number of differences in the images. */
size_t Image_diff(const Image_T image, const Image_T other) {
	size_t count; /* difference count */
	size_t width; /* width to iterate */
	size_t height; /* height to iterate */
	size_t w; /* current iterating width */
	size_t h; /* current iterating height */
	struct Pixel *pixel; /* current pixel of the image */
	struct Pixel *other_pixel; /* current pixel of the other image */

	assert(image != NULL);
	assert(other != NULL);

	/* Take the smaller of the two widths and heights. */
	width = (image->width > other->width) ? other->width: image->width;
	height = (image->height > other->height) ? other->height: image->height;

	/* Start the count off as the difference in sizes. */
	count = image->width * image->height - other->width * other->height;

	for (h = 0; h < height; h++) {
		for (w = 0; w < width; w++) {
			pixel = Image_pixel(image, w, h);
			other_pixel = Image_pixel(other, w, h);

			if (pixel->red != other_pixel->red ||
				pixel->green != other_pixel->green ||
				pixel->blue != other_pixel->blue) count++;
			}
		}

	return count;
	}

/* --- Internal Methods --- */
/* Get the pixel at a given coordinate. */
static struct Pixel *Image_pixel(const Image_T image, const size_t row,
	const size_t col) {
	assert(image != NULL);
	assert(row >= 0 && row < image->height);
	assert(col >= 0 && col < image->width);

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
