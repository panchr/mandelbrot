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
	*	%r10b - odd_iter
	*	%r11d - w
	*	%r12d - h
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
	* 	%xmm7 - x_scale
	*	%xmm8 - y_scale
	*	%xmm9 -  zreal
	*	%xmm10 - zimag
	*	%xmm11 ... %xmm15 - scratch
	*/

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
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	/* Stack alignment. */
	subq $8, %rsp

	/* Save the caller-saved registers. */
	subq $48, %rsp
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
	call _Image_new
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
	addq $48, %rsp

	## if (image == NULL) goto memory_error;
	cmpq $0, %r15
	je memory_error

	## const double x_scale = (xmax - xmin) / width;
	/* convert %rdi to a double into %xmm13 */
	cvtsi2sdq %rdi, %xmm13
	movapd %xmm1, %xmm7
	subsd %xmm0, %xmm7
	divsd %xmm13, %xmm7

	## const double y_scale = (ymax - ymin) / height;
	/* convert %rsi to a double into %xmm13 */
	cvtsi2sdq %rsi, %xmm14
	movapd %xmm3, %xmm8
	subsd %xmm2, %xmm8
	divsd %xmm14, %xmm8

	## const double limit = radius * radius;
	mulsd %xmm4, %xmm4

	## const bool odd_iter = (iterations % 2 == 1)
	movb %dl, %r10b
	andb $1, %r10b

	## const unsigned long half_iter = iterations / 2;
	/* iterations is never used again, so we just divide that by 2. */
	shrq $1, %rdx

	## double x = xmax - x_scale;
	movapd %xmm1, %xmm5
	subsd %xmm7, %xmm5

	## size_t w = width - 1;
	movl %edi, %r11d
	decl %r11d

/* Iterating from w = width to w = 0 */
loop_width:
	## double y = ymax - y_scale;
	movapd %xmm3, %xmm6
	subsd %xmm8, %xmm6

	## size_t h = height - 1;
	movl %esi, %r12d
	decl %r12d

/* Iterating from h = height to h = 0 */
loop_height:
	## double zreal = x;
	movapd %xmm5, %xmm9

	## double zimag = y;
	movapd %xmm6, %xmm10

	## bool draw = true;
	movb $1, %r13b

	## unsigned long iter = half_iter;
	movq %rdx, %r14

	## if (! odd_iter) goto even_iter;
	cmpb $0, %r10b
	je even_iter

	/* Odd number of iterations. */
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow

/* Even number of iterations.*/
even_iter:
	## crpow(&zreal, &zimag, exponent, x, y);
	call _crpow
	call _crpow

	## double temp = (zreal * zreal + zimag * zimag);
	movapd %xmm9, %xmm11
	mulsd %xmm9, %xmm11
	movapd %xmm10, %xmm12
	mulsd %xmm10, %xmm12
	addsd %xmm11, %xmm12

	## if (temp <= limit) goto in_limit;
	cmplesd %xmm4, %xmm12
	movq %xmm12, %rax
	testq %rax, %rax
	jnz in_limit

	## draw = false;
	movb $0, %r13b
	jmp check_draw

in_limit:
	## if (--iter != 0) goto even_iter;
	decq %r14
	jnz even_iter

check_draw:
	cmpb $0, %r13b
	jz end_check_draw

	/* Save the caller-saved registers. */
	subq $80, %rsp
	movq %xmm0, (%rsp)
	movq %xmm1, 8(%rsp)
	movq %xmm2, 16(%rsp)
	movq %xmm3, 24(%rsp)
	movq %xmm4, 32(%rsp)
	movq %xmm5, 40(%rsp)
	movq %xmm6, 48(%rsp)
	movq %xmm7, 56(%rsp)
	movq %xmm8, 64(%rsp)
	movq %xmm9, 72(%rsp)
	movq %xmm10, 80(%rsp)
	pushq %rdi
	pushq %rsi
	pushq %rdx
	pushq %rcx
	pushq %r10
	pushq %r11

	## Image_setPixel(image, w, h, 0, 0, 255);
	movq %r15, %rdi
	movl %r11d, %esi
	movl %r12d, %edx
	movb $0, %cl
	movb $0, %r8b
	movb $255, %r9b
	call _Image_setPixel

	/* Restore the caller-saved registers. */
	popq %r11
	popq %r10
	popq %rcx
	popq %rdx
	popq %rsi
	popq %rdi
	movq 80(%rsp), %xmm10
	movq 72(%rsp), %xmm9
	movq 64(%rsp), %xmm8
	movq 56(%rsp), %xmm7
	movq 48(%rsp), %xmm6
	movq 40(%rsp), %xmm5
	movq 32(%rsp), %xmm4
	movq 24(%rsp), %xmm3
	movq 16(%rsp), %xmm2
	movq 8(%rsp), %xmm1
	movq (%rsp), %xmm0
	addq $80, %rsp

end_check_draw:
	## y -= y_scale;
	subsd %xmm8, %xmm6

	## h--;
	decl %r12d
	jnz loop_height

end_loop_height:
	## x -= x_scale;
	subsd %xmm7, %xmm5

	## w--;
	decl %r11d
	jnz loop_width;

_generate_mandelbrot_set_return:
	addq $8, %rsp

	## return image;
	movq %r15, %rax
	/* Restore the callee-saved registers. */
	popq %r15
	popq %r14
	popq %r13
	popq %r12

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
	movapd %xmm9, %xmm11

	## double wimag = zimag;
	movapd %xmm10, %xmm12

	movq %rcx, %rax

	## if (exp-- != 0) goto _crpow_exp_loop
	decq %rax
	jnz _crpow_exp_loop

	## zreal = 1;
	movq $1, %rax
	cvtsi2sdq %rax, %xmm9

	## zimag = 0;
	pxor %xmm10, %xmm10
	ret

_crpow_exp_loop:
	## wreal_temp = (zreal * wreal - zimag * wimag);
	/* wreal_temp = zreal * wreal */
	movapd %xmm9, %xmm13
	mulsd %xmm11, %xmm13
	/* a = zimag * wimag */
	movapd %xmm10, %xmm14
	mulsd %xmm12, %xmm14
	/* wreal_temp = wreal_temp - a */
	subsd %xmm14, %xmm13

	## wimag = (zreal * wimag + zimag * wreal);
	/* wimag = zreal * wimag */
	movapd %xmm9, %xmm14
	mulsd %xmm12, %xmm14
	/* b = zimag * wreal */
	movapd %xmm10, %xmm12
	mulsd %xmm11, %xmm12
	/* wimag = wimag + b */
	addsd %xmm14, %xmm12

	## wreal = wreal_temp;
	movapd %xmm13, %xmm11

	## while (exp--)
	decq %rax
	jnz _crpow_exp_loop

_crpow_return:
	## zreal = wreal + x;
	movapd %xmm11, %xmm9
	addsd %xmm5, %xmm9

	## zimag = wreal + y;
	movapd %xmm12, %xmm10
	addsd %xmm6, %xmm10

	ret
