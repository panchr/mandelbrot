/*
* generate_mandelbrot_set.s
* Author: Rushy Panchal
* Description: Generates the Mandelbrot Set and returns an Image_T object.
*/

	.data
img_memerr: .string "Memory error when creating image.\n"

	.text

/*
* Generate the Mandelbrot Set and return an image.
* Parameters
*	(%rdi) const size_t width - width of the image
*	(%rsi) const size_t height - height of the image
*	(%rdx) const unsigned long iterations - iterations per pixel
*	(%rcx) const unsigned long exponent - exponent for the set
*	(%xmm0) const double xmin - minimum x value of the graph
*	(%xmm1) const double xmax - maximum x value of the graph
*	(%xmm2) const double ymin - minimum y value of the graph
*	(%xmm3) const double ymax - maximum y value of the graph
*	(%xmm4) const double radius - escape radius of the set
* Returns
*	(Image_T) image of the set
*/
	.globl _generate_mandelbrot_set_asm

	/*
	--- Local Variables/Parameters ---
	* Regular Registers
	*	%rdi - width
	*	%rsi - height
	*	%rdx - iterations
	*	%rcx - exp
	*	%r13b - draw
	*	%r14 - iter
	*	%r15 - image
	*
	* Floating Point (MMX) Registers
	* 	%xmm0 - xmin
	*	%xmm1 - xmax
	*	%xmm2 - ymin
	*	%xmm3 - ymax
	*	%xmm4 - limit (radius squared)
	*	%xmm5 - x
	*	%xmm6 - y
	* 	%xmm7 - w
	*	%xmm8 - h
	*	%xmm9 -  x_scale
	*	%xmm10 - y_scale
	*	%xmm11 - zreal
	*	%xmm12 - zimag
	*	%xmm13 - scratch
	*	%xmm14 - scratch
	*	%xmm15 - scratch
	*/

	/* 5 arguments of 8 bytes each + 4 bytes for alignment = 48 bytes */
	.equ XMM_ARGSIZE, 48

_generate_mandelbrot_set_asm:
	/* Stack alignment. */
	subq $8, %rsp

	/* Save the caller-saved registers. */
	subq $XMM_ARGSIZE, %rsp
	movq %xmm0, (%rsp)
	movq %xmm1, 8(%rsp)
	movq %xmm2, 16(%rsp)
	movq %xmm3, 24(%rsp)
	movq %xmm4, 32(%rsp)
	pushq %rdi
	pushq %rsi
	pushq %rdx
	pushq %rcx

	/* width and height are already in %rdi and %rsi, respectively. */
	## image = Image_new(width, height);
	callq _Image_new
	movq %rax, %r15

	/* Restore the caller-saved registers. */
	popq %rcx
	popq %rdx
	popq %rsi
	popq %rdi
	movq 32(%rsp), %xmm4
	movq 24(%rsp), %xmm3
	movq 16(%rsp), %xmm2
	movq 8(%rsp), %xmm1
	movq (%rsp), %xmm0
	addq $XMM_ARGSIZE, %rsp

	## if (image == NULL) goto memory_error;
	cmpq $0, %r15
	je memory_error

	## const double x_scale = (xmax - xmin) / width;
	/* convert %rdi to a double into %xmm13 */
	cvtsi2sdq %rdi, %xmm13
	movapd %xmm1, %xmm9
	subsd %xmm0, %xmm9
	divsd %xmm13, %xmm9

	## const double y_scale = (ymax - ymin) / height;
	/* convert %rsi to a double into %xmm13 */
	cvtsi2sdq %rsi, %xmm14
	movapd %xmm3, %xmm10
	subsd %xmm2, %xmm10
	divsd %xmm14, %xmm10

	## const double limit = radius * radius;
	mulsd %xmm4, %xmm4

	## printf("%p %f %f %f\n", image, x_scale, y_scale, limit);
	leaq str_format(%rip), %rdi
	movq %r15, %rsi
	movapd %xmm10, %xmm0
	movapd %xmm9, %xmm1
	movapd %xmm4, %xmm2
	movb $3, %al
	call _printf

end:
	addq $8, %rsp
	movq %r15, %rax
	ret

memory_error:
	## fprintf(stderr, "Memory error when creating image.\n");
	movq ___stderrp@GOTPCREL(%rip), %rdi
	movq (%rdi), %rdi
	leaq img_memerr(%rip), %rsi
	movl $0, %eax
	call _fprintf

	## exit(EXIT_FAILURE);
	movl $1, %edi
	call _exit


	.data
str_format: .string "%p %f %f %f\n"
