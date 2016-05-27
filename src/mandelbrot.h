/*
* mandelbrot.h
* Author: Rushy Panchal
* Description: Interface to generate_mandelbrot.c. 
*/

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
Image_T generate_mandelbrot_set(const size_t width, const size_t height,
	const unsigned long iterations, const unsigned long exponent,
	const double xmin, const double xmax, const double ymin,
	const double ymax, const double radius);
