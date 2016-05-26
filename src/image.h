/*
* image.h
* Author: Rushy Panchal
* Description: A simple module to manipulate PNG images.
* 	Provides the Image_T ADT for writing and saving PNG images.
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
* Free the image.
* Parameters
*	Image_T image - image to free
*/
void Image_free(Image_T image);

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
* Save the image to a file.
* Parameters
*	const Image_t image - image to save
*	const char *path - path of the file to save the image to
* Returns
*	(bool) true on success, false on failure
*/
bool Image_save(const Image_T image, const char *path);

#endif
