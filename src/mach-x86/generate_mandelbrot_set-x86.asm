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
	*	%rbx - iterations
	*	%rcx - exp
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
	*	%xmm14 -  zreal
	*	%xmm15 - zimag
	*/

	.equ STACK_ALIGNMENT, 8
	.equ XMM_SAVE_IMG_NEW, 24

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
	movq %rdx, %rbx
	movapd %xmm1, %xmm7 /* xmax */
	movapd %xmm3, %xmm8 /* ymax */
	movapd %xmm4, %xmm9 /* limit */

	/* Save the caller-saved registers. */
	subq $XMM_SAVE_IMG_NEW, %rsp
	movq %xmm0, (%rsp)
	movq %xmm2, 8(%rsp)
	pushq %rdi
	pushq %rsi
	pushq %rcx

	/* width and height are already in %rdi and %rsi, respectively. */
	## image = Image_new(width, height);
	call _Image_new
	movq %rax, %r15

	/* Restore the caller-saved registers. */
	popq %rcx
	popq %rsi
	popq %rdi
	movq 8(%rsp), %xmm2
	movq (%rsp), %xmm0
	addq $XMM_SAVE_IMG_NEW, %rsp

	## if (image == NULL) goto memory_error;
	cmpq $0, %r15
	je memory_error

	## const double x_scale = (xmax - xmin) / width;
	/* convert %rdi to a double into %xmm5 */
	cvtsi2sdq %rdi, %xmm5
	movapd %xmm7, %xmm12
	subsd %xmm0, %xmm12
	divsd %xmm5, %xmm12

	## const double y_scale = (ymax - ymin) / height;
	/* convert %rsi to a double into %xmm5 */
	cvtsi2sdq %rsi, %xmm5
	movapd %xmm8, %xmm13
	subsd %xmm2, %xmm13
	divsd %xmm5, %xmm13

	## const double limit = radius * radius;
	mulsd %xmm9, %xmm9

	## const bool odd_iter = (iterations % 2 == 1)
	movb %dl, %bpl
	andb $1, %bpl

	## const unsigned long half_iter = iterations / 2;
	/* iterations is never used again, so we just divide that by 2. */
	shrq $1, %rbx

	## double x = xmax - x_scale;
	movapd %xmm7, %xmm10
	subsd %xmm12, %xmm10

	## ymax -= y_scale;
	subsd %xmm13, %xmm8

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
	movq %rbx, %r14

	## if (! odd_iter) goto iter_loop;
	cmpb $0, %bpl
	je iter_loop

	/* Odd number of iterations. */
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow

/* Even number of iterations.*/
iter_loop:
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow
	call _crpow

	## double temp = (zreal * zreal + zimag * zimag);
	movapd %xmm14, %xmm3
	mulsd %xmm14, %xmm3
	movapd %xmm15, %xmm4
	mulsd %xmm15, %xmm4
	addsd %xmm3, %xmm4

	## if (temp <= limit) goto in_limit;
	cmplesd %xmm9, %xmm4
	movq %xmm4, %rax
	testq %rax, %rax
	jz end_draw_point

in_limit:
	## if (--iter != 0) goto iter_loop;
	decq %r14
	jnz iter_loop

draw_point:
	/* Save the caller-saved registers. */
	pushq %rdi
	pushq %rsi
	pushq %rcx

	## Image_setPixel(image, w, h, 0, 0, 255);
	movq %r15, %rdi
	movl %r12d, %esi
	movl %r13d, %edx
	movb $0, %cl
	movb $0, %r8b
	movb $255, %r9b
	call _Image_setPixel

	/* Restore the caller-saved registers. */
	popq %rcx
	popq %rsi
	popq %rdi

end_draw_point:
	## y -= y_scale;
	subsd %xmm13, %xmm11

	## h--;
	decl %r13d
	jnz loop_height

end_loop_height:
	## x -= x_scale;
	subsd %xmm12, %xmm10

	## w--;
	decl %r12d
	jnz loop_width;

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

_crpow:
	## double wreal = zreal;
	movapd %xmm14, %xmm3

	## double wimag = zimag;
	movapd %xmm15, %xmm4

	movq %rcx, %rax

	## if (exp-- != 0) goto _crpow_exp_loop
	decq %rax
	jnz _crpow_exp_loop

	ret

_crpow_exp_loop:
	## wreal_temp = (zreal * wreal - zimag * wimag);
	/* wreal_temp = zreal * wreal */
	movapd %xmm14, %xmm5
	mulsd %xmm3, %xmm5
	/* a = zimag * wimag */
	movapd %xmm15, %xmm6
	mulsd %xmm4, %xmm6
	/* wreal_temp = wreal_temp - a */
	subsd %xmm6, %xmm5

	## wimag = (zreal * wimag + zimag * wreal);
	/* wimag = zreal * wimag */
	movapd %xmm14, %xmm6
	mulsd %xmm4, %xmm6
	/* b = zimag * wreal */
	movapd %xmm15, %xmm4
	mulsd %xmm3, %xmm4
	/* wimag = wimag + b */
	addsd %xmm6, %xmm4

	## wreal = wreal_temp;
	movapd %xmm5, %xmm3

	## while (exp--)
	decq %rax
	jnz _crpow_exp_loop

_crpow_return:
	## zreal = wreal + x;
	movapd %xmm3, %xmm14
	addsd %xmm10, %xmm14

	## zimag = wreal + y;
	movapd %xmm4, %xmm15
	addsd %xmm11, %xmm15

	ret
