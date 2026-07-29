	.file	"accum.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	isum_ptr
	.type	isum_ptr, @function
isum_ptr:
.LFB0:
	.cfi_startproc
	endbr64
	test	rdx, rdx
	je	.L1
	mov	rax, QWORD PTR [rdi]
	lea	rdx, [rsi+rdx*8]
	.p2align 4,,10
	.p2align 3
.L3:
	add	rax, QWORD PTR [rsi]
	add	rsi, 8
	mov	QWORD PTR [rdi], rax
	cmp	rdx, rsi
	jne	.L3
.L1:
	ret
	.cfi_endproc
.LFE0:
	.size	isum_ptr, .-isum_ptr
	.p2align 4
	.globl	isum_restrict
	.type	isum_restrict, @function
isum_restrict:
.LFB1:
	.cfi_startproc
	endbr64
	test	rdx, rdx
	je	.L7
	movq	xmm0, QWORD PTR [rdi]
	cmp	rdx, 1
	je	.L12
	mov	rcx, rdx
	mov	rax, rsi
	pxor	xmm1, xmm1
	shr	rcx
	sal	rcx, 4
	add	rcx, rsi
	.p2align 4,,10
	.p2align 3
.L10:
	movdqu	xmm3, XMMWORD PTR [rax]
	add	rax, 16
	paddq	xmm1, xmm3
	cmp	rcx, rax
	jne	.L10
	movdqa	xmm2, xmm1
	psrldq	xmm2, 8
	paddq	xmm1, xmm2
	paddq	xmm0, xmm1
	test	dl, 1
	je	.L11
	and	rdx, -2
.L9:
	movq	xmm1, QWORD PTR [rsi+rdx*8]
	paddq	xmm0, xmm1
.L11:
	movq	QWORD PTR [rdi], xmm0
.L7:
	ret
.L12:
	xor	edx, edx
	jmp	.L9
	.cfi_endproc
.LFE1:
	.size	isum_restrict, .-isum_restrict
	.p2align 4
	.globl	isum_local
	.type	isum_local, @function
isum_local:
.LFB2:
	.cfi_startproc
	endbr64
	movq	xmm0, QWORD PTR [rdi]
	test	rdx, rdx
	je	.L21
	cmp	rdx, 1
	je	.L26
	mov	rcx, rdx
	mov	rax, rsi
	pxor	xmm1, xmm1
	shr	rcx
	sal	rcx, 4
	add	rcx, rsi
	.p2align 4,,10
	.p2align 3
.L23:
	movdqu	xmm3, XMMWORD PTR [rax]
	add	rax, 16
	paddq	xmm1, xmm3
	cmp	rcx, rax
	jne	.L23
	movdqa	xmm2, xmm1
	psrldq	xmm2, 8
	paddq	xmm1, xmm2
	paddq	xmm0, xmm1
	test	dl, 1
	je	.L21
	and	rdx, -2
.L22:
	movq	xmm1, QWORD PTR [rsi+rdx*8]
	paddq	xmm0, xmm1
.L21:
	movq	QWORD PTR [rdi], xmm0
	ret
.L26:
	xor	edx, edx
	jmp	.L22
	.cfi_endproc
.LFE2:
	.size	isum_local, .-isum_local
	.p2align 4
	.globl	dsum_ptr
	.type	dsum_ptr, @function
dsum_ptr:
.LFB3:
	.cfi_startproc
	endbr64
	test	rdx, rdx
	je	.L34
	movsd	xmm0, QWORD PTR [rdi]
	lea	rax, [rsi+rdx*8]
	.p2align 4,,10
	.p2align 3
.L36:
	addsd	xmm0, QWORD PTR [rsi]
	add	rsi, 8
	movsd	QWORD PTR [rdi], xmm0
	cmp	rax, rsi
	jne	.L36
.L34:
	ret
	.cfi_endproc
.LFE3:
	.size	dsum_ptr, .-dsum_ptr
	.p2align 4
	.globl	dsum_restrict
	.type	dsum_restrict, @function
dsum_restrict:
.LFB4:
	.cfi_startproc
	endbr64
	test	rdx, rdx
	je	.L39
	movsd	xmm0, QWORD PTR [rdi]
	cmp	rdx, 1
	je	.L44
	mov	rcx, rdx
	mov	rax, rsi
	shr	rcx
	sal	rcx, 4
	add	rcx, rsi
	.p2align 4,,10
	.p2align 3
.L42:
	addsd	xmm0, QWORD PTR [rax]
	add	rax, 16
	addsd	xmm0, QWORD PTR -8[rax]
	cmp	rcx, rax
	jne	.L42
	test	dl, 1
	je	.L43
	and	rdx, -2
.L41:
	addsd	xmm0, QWORD PTR [rsi+rdx*8]
.L43:
	movsd	QWORD PTR [rdi], xmm0
.L39:
	ret
.L44:
	xor	edx, edx
	jmp	.L41
	.cfi_endproc
.LFE4:
	.size	dsum_restrict, .-dsum_restrict
	.p2align 4
	.globl	dsum_local
	.type	dsum_local, @function
dsum_local:
.LFB5:
	.cfi_startproc
	endbr64
	movsd	xmm0, QWORD PTR [rdi]
	test	rdx, rdx
	je	.L53
	cmp	rdx, 1
	je	.L58
	mov	rcx, rdx
	mov	rax, rsi
	shr	rcx
	sal	rcx, 4
	add	rcx, rsi
	.p2align 4,,10
	.p2align 3
.L55:
	addsd	xmm0, QWORD PTR [rax]
	add	rax, 16
	addsd	xmm0, QWORD PTR -8[rax]
	cmp	rcx, rax
	jne	.L55
	test	dl, 1
	je	.L53
	and	rdx, -2
.L54:
	addsd	xmm0, QWORD PTR [rsi+rdx*8]
.L53:
	movsd	QWORD PTR [rdi], xmm0
	ret
.L58:
	xor	edx, edx
	jmp	.L54
	.cfi_endproc
.LFE5:
	.size	dsum_local, .-dsum_local
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
	.section	.note.gnu.property,"a"
	.align 8
	.long	1f - 0f
	.long	4f - 1f
	.long	5
0:
	.string	"GNU"
1:
	.align 8
	.long	0xc0000002
	.long	3f - 2f
2:
	.long	0x3
3:
	.align 8
4:
