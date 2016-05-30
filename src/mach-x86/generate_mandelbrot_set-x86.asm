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
	*	%r13b - draw (not used)
	*	%r14 - iter
	*	%r15 - image
	*
	* Floating Point (MMX) Registers (high, low)
	*	%xmm6 - xmin, ymin
	*	%xmm7 - xmax, ymax
	*	%xmm8 - x_scale, y_scale
	*	%xmm9 - -, limit
	*	%xmm10 - x, y
	*	%xmm11 - zreal, zimag
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

	/* Move xmin and ymin into the high and low segments of xmm7,
	respectively. */
	movapd %xmm2, %xmm6
	unpcklpd %xmm0, %xmm6

	/* Move xmax and ymax into the high and low segments of xmm7,
	respectively. */
	movapd %xmm3, %xmm7
	unpcklpd %xmm1, %xmm7

	## const double x_scale = (xmax - xmin) / width;
	/* convert %rdi to a double into %xmm12 */
	cvtsi2sdq %rdi, %xmm15
	subsd %xmm0, %xmm1
	divsd %xmm15, %xmm1

	## const double y_scale = (ymax - ymin) / height;
	/* convert %rsi to a double into %xmm12 */
	cvtsi2sdq %rsi, %xmm15
	subsd %xmm2, %xmm3
	divsd %xmm15, %xmm3

	/* Move x_scale and y_scale into the high and low segments of xmm8, respectively. */
	movapd %xmm3, %xmm8
	unpcklpd %xmm1, %xmm8

	## const double limit = radius * radius;
	movapd %xmm4, %xmm9
	mulsd %xmm9, %xmm9

	## const bool odd_iter = (iterations % 2 == 1)
	movb %dl, %r10b
	andb $1, %r10b

	## const unsigned long half_iter = iterations / 2;
	/* iterations is never used again, so we just divide that by 2. */
	shrq $1, %rdx

	## if (exp == 0) half_iter = 0;
	cmpq $0, %rcx
	jnz exp_non_zero
	movq $0, %rdx

exp_non_zero:
	## double x = xmax - x_scale;
	movapd %xmm7, %xmm10
	subpd %xmm8, %xmm10

	## ymax -= y_scale;
	subsd %xmm8, %xmm7

	## size_t w = width - 1;
	movl %edi, %r11d
	decl %r11d

/* Iterating from w = width to w = 0 */
loop_width:
	## double y = ymax;
	movsd %xmm7, %xmm10

	## size_t h = height - 1;
	movl %esi, %r12d
	decl %r12d

/* Iterating from h = height to h = 0 */
loop_height:
	## double zreal = x;
	## double zimag = y;
	movapd %xmm10, %xmm11

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
	movapd %xmm11, %xmm0
	mulpd %xmm0, %xmm0
	haddpd %xmm0, %xmm0

	## if (temp <= limit) goto in_limit;
	cmpsd $2, %xmm9, %xmm0
	movq %xmm0, %rax
	testq %rax, %rax
	jnz in_limit

	## draw = false;
	jmp end_check_draw

in_limit:
	## if (--iter != 0) goto even_iter;
	decq %r14
	jnz even_iter

draw_point:
	/* Save the caller-saved registers. */
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

end_check_draw:
	## y -= y_scale;
	subsd %xmm8, %xmm10

	## h--;
	decl %r12d
	jnz loop_height

end_loop_height:
	## x -= x_scale;
	/* Note: this also performs y -= y_scale, but that is irrelevant because
	y is set to ymax - y_scale in the next iteration.*/
	subpd %xmm8, %xmm10

	## w--;
	decl %r11d
	jnz loop_width

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
	## double wimag = zimag;
	movapd %xmm11, %xmm0

	movq %rcx, %r8

	## if (exp-- != 0) goto _crpow_exp_loop
	decq %r8
	jnz _crpow_exp_loop

	ret

_crpow_exp_loop:
	## wreal_temp = (zreal * wreal - zimag * wimag);
	movapd %xmm0, %xmm1
	mulpd %xmm11, %xmm1
	/* Because hsubpd computes low - high, we have to first
	shuffle the elements. */
	shufpd $1, %xmm1, %xmm1
	hsubpd %xmm1, %xmm1

	## wimag_temp = (zreal * wimag + zimag * wreal);
	movapd %xmm0, %xmm2
	shufpd $1, %xmm2, %xmm2
	mulpd %xmm11, %xmm2
	haddpd %xmm2, %xmm2

	## wreal = wreal_temp;
	movapd %xmm1, %xmm0
	## wimag = wimag_temp;
	movsd %xmm2, %xmm0

	## while (exp--)
	decq %r8
	jg _crpow_exp_loop

_crpow_return:
	## zreal = wreal + x;
	## zimag = wreal + y;
	movapd %xmm0, %xmm11
	addpd %xmm10, %xmm11

	ret
	