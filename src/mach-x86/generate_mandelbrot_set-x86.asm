/*
* generate_mandelbrot_set-x86.s
* Author: Rushy Panchal
* Description: Generates the Mandelbrot Set and returns an Image_T object
*	containing a visual representation of the set.
*	This is src/generate_mandelbrot_set.c implemented in Mach-O x86.
*/

	.data
img_memerr: .string "Memory error when creating image.\n"

	.text
	.globl _generate_mandelbrot_set

	/*
	--- Local Variables/Parameters ---
	* Regular Registers
	*	%edi - width
	*	%esi - height
	*	%rdx - iterations
	*	%rcx - exp
	*	%bl - drawA
	*	%bh - drawB
	*	%bpl - odd_iter
	*	%r12d - w
	*	%r13d - h
	*	%r14 - iter
	*	%r15 - image
	*
	* Floating Point (MMX) Registers
	* 	%xmm0 - xmin
	*	%xmm2 - ymin
	*	%xmm7 - xmax
	*	%xmm8 - ymax
	*	%xmm9 - limit (radius squared)
	*	%xmm10 - x
	*	%xmm11 - y
	* 	%xmm12 - x_scale
	*	%xmm13 - y_scale
	*	%xmm14 - zreal
	*	%xmm15 - zimag
	*/

	.equ STACK_ALIGNMENT, 8
	.equ XMM_SAVE_IMG_NEW, 16

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
_generate_mandelbrot_set:
	/* Save the callee-saving registers. */
	pushq %rbx
	pushq %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	/* Stack alignment. */
	subq $STACK_ALIGNMENT, %rsp

	/* Move all arguments into the appropriate registers. */
	movddup %xmm1, %xmm7 /* xmax */
	movddup %xmm3, %xmm8 /* ymax */
	movddup %xmm4, %xmm9 /* limit */

	/* Save the caller-saved registers. */
	subq $XMM_SAVE_IMG_NEW, %rsp
	movq %xmm0, (%rsp)
	movq %xmm2, 8(%rsp)
	pushq %rdi
	pushq %rsi
	pushq %rcx
	pushq %rdx

	/* width and height are already in %rdi and %rsi, respectively. */
	## image = Image_new(width, height);
	call _Image_new
	movq %rax, %r15

	/* Restore the caller-saved registers. */
	popq %rdx
	popq %rcx
	popq %rsi
	popq %rdi
	movq 8(%rsp), %xmm2
	movq (%rsp), %xmm0
	addq $XMM_SAVE_IMG_NEW, %rsp

	## if (image == NULL) goto memory_error;
	cmpq $0, %r15
	je memory_error

	/* Duplicate the register data in xmm0 and xmm2.
	Note: this must be done after the call of Image_new otherwise both the high
	and low double quadwords of the registers must be saved to the stack. */
	movddup %xmm0, %xmm0
	movddup %xmm2, %xmm2

	## const double x_scale = (xmax - xmin) / width;
	/* convert %rdi to a double into %xmm5 */
	cvtsi2sdq %rdi, %xmm5
	movddup %xmm5, %xmm5
	movapd %xmm7, %xmm12
	subpd %xmm0, %xmm12
	divpd %xmm5, %xmm12

	## const double y_scale = (ymax - ymin) / height;
	/* convert %rsi to a double into %xmm5 */
	cvtsi2sdq %rsi, %xmm5
	movddup %xmm5, %xmm5
	movapd %xmm8, %xmm13
	subpd %xmm2, %xmm13
	divpd %xmm5, %xmm13

	## const double limit = radius * radius;
	mulpd %xmm9, %xmm9

	## const bool odd_iter = (iterations % 2 == 1)
	movb %dl, %bpl
	andb $1, %bpl

	## const unsigned long half_iter = iterations / 2;
	/* iterations is never used again, so we just divide that by 2. */
	shrq $1, %rdx

	## double x = xmax - x_scale;
	movapd %xmm7, %xmm10
	subpd %xmm12, %xmm10
	/* Start point A lower so that it is distinct from point B. */
	subsd %xmm12, %xmm10

	/* We want to move two positions over each time to avoid repeating points. */
	## x_scale += x_scale;
	addpd %xmm12, %xmm12

	## ymax -= y_scale;
	subpd %xmm13, %xmm8

	## size_t w = width - 1;
	movl %edi, %r12d
	decl %r12d

	## height -= 1;
	decl %esi

/* Iterating from w = width to w = 0 */
loop_width:
	## double y = ymax;
	movapd %xmm8, %xmm11

	## size_t h = height;
	movl %esi, %r13d

/* Iterating from h = height to h = 0 */
loop_height:
	## double zreal = x;
	movapd %xmm10, %xmm14

	## double zimag = y;
	movapd %xmm11, %xmm15

	## unsigned long iter = half_iter;
	movq %rdx, %r14

	## bool drawA = true;
	movb $1, %bl

	## bool drawB = true;
	movb $1, %bh

	## if (! odd_iter) goto iter_loop;
	cmpb $0, %bpl
	je iter_loop

	/* Odd number of iterations. */
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow

/* Primary iteration loop for a given point.*/
iter_loop:
	## crpow(&zreal, &zimag, exponent, x, y);
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow
	call _crpow

	## double temp{A, B} = (zreal * zreal + zimag * zimag);
	movapd %xmm14, %xmm3
	mulpd %xmm14, %xmm3
	/* xmm3 = xmm15 * xmm15 + xmm3 */
	vfmadd231pd %xmm15, %xmm15, %xmm3
	
	## drawA = drawA && (tempA <= limit);
	cmplepd %xmm9, %xmm3
	movq %xmm3, %rax
	andb %al, %bl

	## drawB = drawB && (tempB <= limit);
	pextrq $1,%xmm3, %rax 
	andb %al, %bh

	## if (! (drawA | drawB)) goto end_loop_height;
	movb %bl, %al
	orb %bh, %al
	testb %al, %al
	jz end_loop_height

	/* Point is in the limit */
	## if (--iter != 0) goto iter_loop;
	decq %r14
	jnz iter_loop

	/* Save the caller-saved registers. */
	pushq %rdi
	pushq %rsi
	pushq %rcx
	pushq %rdx

	## if (! drawA) goto draw_pointB;
	testb %bl, %bl
	jz draw_pointB

	## Image_setPixel(image, w-1, h, 0, 0, 255);
	decl %r12d
	call _image_draw_pixel
	incl %r12d

/* Try to draw pointB */
draw_pointB:
	## if (! drawB) goto end_draw;
	testb %bh, %bh
	jz end_draw

	## Image_setPixel(image, w, h, 0, 0, 255);
	call _image_draw_pixel

/* End of pixel drawing for both points. */
end_draw:
	/* Restore the caller-saved registers. */
	popq %rdx
	popq %rcx
	popq %rsi
	popq %rdi

/* End of height iteration. */
end_loop_height:
	## y -= y_scale;
	subpd %xmm13, %xmm11

	## h--;
	decl %r13d
	jnz loop_height

/* End of width iteration. */
end_loop_width:
	## x -= x_scale;
	subpd %xmm12, %xmm10

	## if (--w == 0) goto _generate_mandelbrot_set_return;
	decl %r12d
	jz _generate_mandelbrot_set_return

	## if (--w != 0) goto loop_width;
	decl %r12d
	jnz loop_width

/* Return the image and cleanup the stack frame. */
_generate_mandelbrot_set_return:
	addq $STACK_ALIGNMENT, %rsp

	## return image;
	movq %r15, %rax
	/* Restore the callee-saved registers. */
	popq %r15
	popq %r14
	popq %r13
	popq %r12
	popq %rbp
	popq %rbx

	ret

/* Memory error occured. */
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

/* --- Internal Functions ---*/

/*
* Draw a pixel onto the image.
* Note: does not modify any of the input registers.
* Parameters
*	(%r15) image - image to draw onto
*	(%r12d) row - row to draw onto
*	(%r13d) col - column to draw onto
*/
_image_draw_pixel:
	movq %r15, %rdi
	movl %r12d, %esi
	movl %r13d, %edx
	movb $0, %cl
	movb $0, %r8b
	movb $255, %r9b
	call _Image_setPixel

	ret

/*
* Raise a complex number to a real integer exponent.
* Note: z^exponent is stored back into z.
* Parameters
*	(%xmm14) zreal - real part of complex number to exponentiate
*	(%xmm15) zimag - imaginary part of complex number to exponentiate
*	(%rcx) exponent - real integer exponent to raise z to
*	(%xmm10) creal - real part of extra complex number to add to result
*	(%xmm11) cimag - imaginary part of extra complex number to add to result
* Returns
*	(%xmm14) real part of z^exponent + c
*	(%xmm15) imaginary part of z^exponent + c
*
* Temporary Registers Used
*	(%xmm3) wreal - iterated real part of z^exponent
*	(%xmm4) wimag - iterated imaginary part of z^exponent
*	(%rax) exp - iterated exponent
*	(%xmm5) wreal_temp - wreal during iteration
*	(%xmm6) a - computation step for calculating wreal_temp
*	(%xmm6) b - computation step for calculating wimag
*/
_crpow:
	## double wreal = zreal;
	movapd %xmm14, %xmm3

	## double wimag = zimag;
	movapd %xmm15, %xmm4

	## double exp = exponent;
	movq %rcx, %rax

	## if (--exp != 0) goto _crpow_exp_loop
	decq %rax
	jnz _crpow_exp_loop

	ret

/* Primary exponentiation loop for computing z^exponent. */
_crpow_exp_loop:
	## wreal_temp = (zreal * wreal - zimag * wimag);
	movapd %xmm15, %xmm5
	mulpd %xmm4, %xmm5
	/* xmm5 = xmm14 * xmm3 - xmm5
	=> xmm5 = xmm14 * xmm3 - xmm15 * xmm4 */
	vfmsub231pd %xmm14, %xmm3,%xmm5

	## wimag = (zreal * wimag + zimag * wreal);
	mulpd %xmm14, %xmm4
	/* xmm4 = xmm15 * xmm3 + xmm4
	=> xmm4 = xmm14 * xmm4 + xmm15 * xmm3*/
	vfmadd231pd %xmm15, %xmm3, %xmm4

	## wreal = wreal_temp;
	movapd %xmm5, %xmm3

	## if (--exp != 0) goto _crpow_exp_loop
	decq %rax
	jnz _crpow_exp_loop

	## zreal = wreal + x;
	movapd %xmm3, %xmm14
	addpd %xmm10, %xmm14

	## zimag = wreal + y;
	movapd %xmm4, %xmm15
	addpd %xmm11, %xmm15

	ret
