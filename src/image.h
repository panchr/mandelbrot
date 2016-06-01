/*
* image.h
* Author: Rushy Panchal
* Description: A simple module to manipulate PNG images.
* 	Provides the Image_T ADT for writing and saving PNG images.
*	Note: assumes using RGB coloring.
*/

#ifndef IMAGE_INCLUDED
#define IMAGE_INCLUDED

#include <stdbool.h>
#include <stdint.h>

typedef struct Image *Image_T;

/*
* Create a new image of the given width and height.
* Parameters
*	const size_t width - width of the image
*	const size_t height - height of the image
* Returns
*	(Image_T) pointer to the Image object (or NULL on memory exhaustion)
*/
Image_T Image_new(const size_t width, const size_t height);

/*
* Create an image from a file.
* Parameters
*	const char *path - path of the file
* Returns
*	(Image_T) pointer to image object (or NULL on memory exhaustion)
*/
Image_T Image_fromFile(const char *path);

/*
* Free the image.
* Parameters
*	Image_T image - image to free
*/
void Image_free(Image_T image);

/*
* Get the width of an image.
* Parameters
*	const Image_T image - image to get width of
* Returns
*	(size_t) width of the image
*/
size_t Image_getWidth(const Image_T image);

/*
* Get the height of an image.
* Parameters
*	const Image_T image - image to get height of
* Returns
*	(size_t) height of the image
*/
size_t Image_getHeight(const Image_T image);

/*
* Get the size of an image.
* Parameters
*	const Image_T image - image to get size of
* Returns
*	(size_t) size of the image
*/
size_t Image_getSize(const Image_T image);

/*
* Set the RGB color of the pixel in the image.
* Parameters
*	const Image_T image - image to set the pixel of
*	const size_t row - row of the pixel
*	const size_t col - column of the pixel
*	const uint8_t red - red value of the color
*	const uint8_t green - green value of the color
*	const uint8_t blue - blue value of the color
*/
void Image_setPixel(const Image_T image, const size_t row, const size_t col,
	const uint8_t red, const uint8_t green, const uint8_t blue);

/*
* Calculate the difference of the two images. The returned value is
* the number of differences detected.
* Parameters
*	const Image_T image - primary image
*	const Image_T other - secondary image
* Returns
*	(size_t) difference count
*/
size_t Image_diff(const Image_T image, const Image_T other);

/*
* Save the image to a file.
* Parameters
*	const Image_t image - image to save
*	const char *path - path of the file to save the image to
* Returns
*	(bool) true on success, false on failure
*/
bool Image_save(const Image_T image, const char *path);

#endif
