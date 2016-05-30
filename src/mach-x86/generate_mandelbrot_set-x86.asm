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
	*	%edi - width*
	*	%esi - height
	*	%rbp - iterations
	*	%rbx - exp
	*	%r10b - odd_iter
	*	%r12d - w
	*	%r13d - h
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
	*
	*	* = not preserved
	*/

	.equ STACK_ALIGNMENT, 8
	.equ CALLER_SAVED_XMM, 48

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
	/* Save the callee-saved registers. */
	pushq %rbx
	pushq %rbp
	pushq %r12
	pushq %r13
	pushq %r14
	pushq %r15
	/* Stack alignment. */
	subq $STACK_ALIGNMENT, %rsp

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
	movq %rdx, %rbp
	shrq $1, %rbp

	## if (--exp != -1) goto exp_non_zero;
	movq %rcx, %rbx
	decq %rbx
	cmpq $-1, %rbx
	jne exp_non_zero

	## else half_iter = 0;
	movq $0, %rbp

exp_non_zero:
	## double x = xmax - x_scale;
	movapd %xmm7, %xmm10
	subpd %xmm8, %xmm10

	## ymax -= y_scale;
	subsd %xmm8, %xmm7

	## size_t w = width - 1;
	movl %edi, %r12d
	decl %r12d

	/* Save the caller-saved registers that need to be preserved. */
	subq $8, %rsp
	pushq %rsi

	/* width and height are already in %rdi and %rsi, respectively. */
	## image = Image_new(width, height);
	call _Image_new
	movq %rax, %r15

	/* Restore the caller-saved registers. */
	popq %rsi
	addq $8, %rsp

	## height -= 1;
	decl %esi

	## if (image == NULL) goto memory_error;
	cmpq $0, %r15
	je memory_error

/* Iterating from w = width to w = 0 */
loop_width:
	## double y = ymax;
	movsd %xmm7, %xmm10

	## size_t h = height;
	movl %esi, %r13d

/* Iterating from h = height to h = 0 */
loop_height:
	## double zreal = x;
	## double zimag = y;
	movapd %xmm10, %xmm11

	## unsigned long iter = half_iter;
	movq %rbp, %r14

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
	cmplesd %xmm9, %xmm0
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
	pushq %rsi
	pushq %r10

	## Image_setPixel(image, w, h, 0, 0, 255);
	movq %r15, %rdi
	movl %r12d, %esi
	movl %r13d, %edx
	movb $0, %cl
	movb $0, %r8b
	movb $255, %r9b
	call _Image_setPixel

	/* Restore the caller-saved registers. */
	popq %r10
	popq %rsi

end_check_draw:
	## y -= y_scale;
	subsd %xmm8, %xmm10

	## h--;
	decl %r13d
	jnz loop_height

end_loop_height:
	## x -= x_scale;
	/* Note: this also performs y -= y_scale, but that is irrelevant because
	y is set to ymax - y_scale in the next iteration.*/
	subpd %xmm8, %xmm10

	## w--;
	decl %r12d
	jnz loop_width

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

/*
* Raise a complex number to a real integer power and add an extra complex
* number to the result.
* Note: Modifies the complex number z in place, but uses additional registers
*	during computation as temporary stores. Treats high quadword as real
*	part and low quadword as imaginary ({real, imag}).
* Parameters
*	(%xmm11) {double, double} z - complex number to raise to power
*	(%xmm10) {double, double} extra - extra complex number to add to result
*	(%rbx) unsigned long exponent - real power
* Returns (%xmm11)
*	({double, double}) z^exponent + extra
* Registers Used
*	(%xmm0) {double, double} w - iterated value of z^exponent
*	(%xmm1) {double, double} z_flipped - flipped version of z ({imag, real})
*	(%xmm2) {double, double} wimag_temp -  temporary storage of
*		w_imag during iteration
*	(%r8) unsigned long exp - current iterated exponent
*/
_crpow:
	## double wreal = zreal;
	## double wimag = zimag;
	movapd %xmm11, %xmm0

	## double zfr = zimag;
	## double zfi = zreal;
	/* Create a flipped version of xmm11 to use when calculating the imaginary
	part. */
	movapd %xmm11, %xmm1
	shufpd $1, %xmm1, %xmm1

	## unsigned long exp = exponent;
	movq %rbx, %r8

	## if (exp == 0) goto _crpow_exp_loop
	cmpq $0, %r8
	jz _crpow_return

_crpow_exp_loop:
	## wimag_temp = wimag;
	movapd %xmm0, %xmm2

	## wreal = (zreal * wreal - zimag * wimag);
	mulpd %xmm11, %xmm0
	/* Because hsubpd computes low - high, we have to first
	shuffle the elements. */
	shufpd $1, %xmm0, %xmm0
	hsubpd %xmm0, %xmm0

	## wimag_temp = (zreal * wimag + zimag * wreal);
	mulpd %xmm1, %xmm2
	haddpd %xmm2, %xmm2

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
	