	.file	"kernels.c"
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	apply_ptr
	.type	apply_ptr, @function
apply_ptr:
.LFB0:
	.cfi_startproc
	endbr64
	mov	rax, rdi
	mov	rcx, rsi
	mov	rdi, rdx
	test	rsi, rsi
	je	.L1
	lea	rdx, -1[rsi]
	cmp	rdx, 2
	jbe	.L24
	lea	rdx, 0[0+rsi*4]
	lea	rsi, [rax+rdx]
	cmp	rdi, rsi
	jnb	.L9
	lea	rsi, 8[rdi]
	cmp	rax, rsi
	jnb	.L9
.L3:
	lea	rcx, [rax+rdx]
	.p2align 4,,10
	.p2align 3
.L7:
	mov	edx, DWORD PTR [rax]
	imul	edx, DWORD PTR [rdi]
	add	rax, 4
	add	edx, DWORD PTR 4[rdi]
	mov	DWORD PTR -4[rax], edx
	cmp	rax, rcx
	jne	.L7
.L1:
	ret
	.p2align 4,,10
	.p2align 3
.L9:
	movd	xmm5, DWORD PTR [rdi]
	mov	rsi, rcx
	movd	xmm6, DWORD PTR 4[rdi]
	mov	rdx, rax
	shr	rsi, 2
	pshufd	xmm2, xmm5, 0
	sal	rsi, 4
	pshufd	xmm4, xmm6, 0
	movdqa	xmm3, xmm2
	add	rsi, rax
	psrlq	xmm3, 32
	.p2align 4,,10
	.p2align 3
.L5:
	movdqu	xmm0, XMMWORD PTR [rdx]
	movdqu	xmm1, XMMWORD PTR [rdx]
	add	rdx, 16
	psrlq	xmm0, 32
	pmuludq	xmm1, xmm2
	pmuludq	xmm0, xmm3
	pshufd	xmm1, xmm1, 8
	pshufd	xmm0, xmm0, 8
	punpckldq	xmm1, xmm0
	movdqa	xmm0, xmm1
	paddd	xmm0, xmm4
	movups	XMMWORD PTR -16[rdx], xmm0
	cmp	rdx, rsi
	jne	.L5
	mov	rdx, rcx
	and	rdx, -4
	test	cl, 3
	je	.L1
	lea	r8, 0[0+rdx*4]
	lea	r9, [rax+r8]
	mov	esi, DWORD PTR [r9]
	imul	esi, DWORD PTR [rdi]
	add	esi, DWORD PTR 4[rdi]
	mov	DWORD PTR [r9], esi
	lea	rsi, 1[rdx]
	cmp	rsi, rcx
	jnb	.L1
	lea	r9, 4[rax+r8]
	add	rdx, 2
	mov	esi, DWORD PTR [r9]
	imul	esi, DWORD PTR [rdi]
	add	esi, DWORD PTR 4[rdi]
	mov	DWORD PTR [r9], esi
	cmp	rdx, rcx
	jnb	.L1
	lea	rdx, 8[rax+r8]
	mov	eax, DWORD PTR [rdx]
	imul	eax, DWORD PTR [rdi]
	add	eax, DWORD PTR 4[rdi]
	mov	DWORD PTR [rdx], eax
	ret
	.p2align 4,,10
	.p2align 3
.L24:
	lea	rdx, 0[0+rsi*4]
	jmp	.L3
	.cfi_endproc
.LFE0:
	.size	apply_ptr, .-apply_ptr
	.p2align 4
	.globl	apply_val
	.type	apply_val, @function
apply_val:
.LFB1:
	.cfi_startproc
	endbr64
	mov	rcx, rdx
	test	rsi, rsi
	je	.L25
	mov	r8, rdx
	lea	rax, -1[rsi]
	sar	r8, 32
	cmp	rax, 2
	jbe	.L30
	movd	xmm5, edx
	mov	rdx, rsi
	movd	xmm6, r8d
	mov	rax, rdi
	pshufd	xmm2, xmm5, 0
	shr	rdx, 2
	pshufd	xmm4, xmm6, 0
	sal	rdx, 4
	movdqa	xmm3, xmm2
	add	rdx, rdi
	psrlq	xmm3, 32
	.p2align 4,,10
	.p2align 3
.L28:
	movdqu	xmm0, XMMWORD PTR [rax]
	movdqu	xmm1, XMMWORD PTR [rax]
	add	rax, 16
	psrlq	xmm0, 32
	pmuludq	xmm1, xmm2
	pmuludq	xmm0, xmm3
	pshufd	xmm1, xmm1, 8
	pshufd	xmm0, xmm0, 8
	punpckldq	xmm1, xmm0
	movdqa	xmm0, xmm1
	paddd	xmm0, xmm4
	movups	XMMWORD PTR -16[rax], xmm0
	cmp	rax, rdx
	jne	.L28
	test	sil, 3
	je	.L25
	mov	rax, rsi
	and	rax, -4
.L27:
	lea	r9, 0[0+rax*4]
	lea	r10, [rdi+r9]
	mov	edx, DWORD PTR [r10]
	imul	edx, ecx
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	lea	rdx, 1[rax]
	cmp	rdx, rsi
	jnb	.L25
	lea	r10, 4[rdi+r9]
	add	rax, 2
	mov	edx, DWORD PTR [r10]
	imul	edx, ecx
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	cmp	rax, rsi
	jnb	.L25
	lea	rax, 8[rdi+r9]
	imul	ecx, DWORD PTR [rax]
	add	ecx, r8d
	mov	DWORD PTR [rax], ecx
.L25:
	ret
.L30:
	xor	eax, eax
	jmp	.L27
	.cfi_endproc
.LFE1:
	.size	apply_val, .-apply_val
	.p2align 4
	.globl	apply_restrict
	.type	apply_restrict, @function
apply_restrict:
.LFB2:
	.cfi_startproc
	endbr64
	mov	rcx, rsi
	test	rsi, rsi
	je	.L38
	lea	rax, -1[rcx]
	mov	esi, DWORD PTR [rdx]
	mov	r8d, DWORD PTR 4[rdx]
	cmp	rax, 2
	jbe	.L43
	movd	xmm5, esi
	mov	rdx, rcx
	movd	xmm6, r8d
	mov	rax, rdi
	pshufd	xmm2, xmm5, 0
	shr	rdx, 2
	pshufd	xmm4, xmm6, 0
	sal	rdx, 4
	movdqa	xmm3, xmm2
	add	rdx, rdi
	psrlq	xmm3, 32
	.p2align 4,,10
	.p2align 3
.L41:
	movdqu	xmm0, XMMWORD PTR [rax]
	movdqu	xmm1, XMMWORD PTR [rax]
	add	rax, 16
	psrlq	xmm0, 32
	pmuludq	xmm1, xmm2
	pmuludq	xmm0, xmm3
	pshufd	xmm1, xmm1, 8
	pshufd	xmm0, xmm0, 8
	punpckldq	xmm1, xmm0
	movdqa	xmm0, xmm1
	paddd	xmm0, xmm4
	movups	XMMWORD PTR -16[rax], xmm0
	cmp	rax, rdx
	jne	.L41
	test	cl, 3
	je	.L38
	mov	rax, rcx
	and	rax, -4
.L40:
	lea	r9, 0[0+rax*4]
	lea	r10, [rdi+r9]
	mov	edx, DWORD PTR [r10]
	imul	edx, esi
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	lea	rdx, 1[rax]
	cmp	rdx, rcx
	jnb	.L38
	lea	r10, 4[rdi+r9]
	add	rax, 2
	mov	edx, DWORD PTR [r10]
	imul	edx, esi
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	cmp	rax, rcx
	jnb	.L38
	lea	rax, 8[rdi+r9]
	imul	esi, DWORD PTR [rax]
	add	esi, r8d
	mov	DWORD PTR [rax], esi
.L38:
	ret
.L43:
	xor	eax, eax
	jmp	.L40
	.cfi_endproc
.LFE2:
	.size	apply_restrict, .-apply_restrict
	.p2align 4
	.globl	apply_ptr_float
	.type	apply_ptr_float, @function
apply_ptr_float:
.LFB3:
	.cfi_startproc
	endbr64
	mov	rcx, rsi
	test	rsi, rsi
	je	.L51
	cvttss2si	esi, DWORD PTR [rdx]
	lea	rax, -1[rcx]
	cvttss2si	r8d, DWORD PTR 4[rdx]
	cmp	rax, 2
	jbe	.L56
	movd	xmm5, esi
	mov	rdx, rcx
	movd	xmm6, r8d
	mov	rax, rdi
	pshufd	xmm2, xmm5, 0
	shr	rdx, 2
	pshufd	xmm4, xmm6, 0
	sal	rdx, 4
	movdqa	xmm3, xmm2
	add	rdx, rdi
	psrlq	xmm3, 32
	.p2align 4,,10
	.p2align 3
.L54:
	movdqu	xmm0, XMMWORD PTR [rax]
	movdqu	xmm1, XMMWORD PTR [rax]
	add	rax, 16
	psrlq	xmm0, 32
	pmuludq	xmm1, xmm2
	pmuludq	xmm0, xmm3
	pshufd	xmm1, xmm1, 8
	pshufd	xmm0, xmm0, 8
	punpckldq	xmm1, xmm0
	movdqa	xmm0, xmm1
	paddd	xmm0, xmm4
	movups	XMMWORD PTR -16[rax], xmm0
	cmp	rax, rdx
	jne	.L54
	test	cl, 3
	je	.L51
	mov	rax, rcx
	and	rax, -4
.L53:
	lea	r9, 0[0+rax*4]
	lea	r10, [rdi+r9]
	mov	edx, DWORD PTR [r10]
	imul	edx, esi
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	lea	rdx, 1[rax]
	cmp	rdx, rcx
	jnb	.L51
	lea	r10, 4[rdi+r9]
	add	rax, 2
	mov	edx, DWORD PTR [r10]
	imul	edx, esi
	add	edx, r8d
	mov	DWORD PTR [r10], edx
	cmp	rax, rcx
	jnb	.L51
	lea	rax, 8[rdi+r9]
	imul	esi, DWORD PTR [rax]
	add	esi, r8d
	mov	DWORD PTR [rax], esi
.L51:
	ret
.L56:
	xor	eax, eax
	jmp	.L53
	.cfi_endproc
.LFE3:
	.size	apply_ptr_float, .-apply_ptr_float
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
