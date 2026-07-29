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
	test	rsi, rsi
	je	.L1
	lea	rcx, [rdi+rsi*4]
	.p2align 4,,10
	.p2align 3
.L3:
	mov	eax, DWORD PTR [rdi]
	imul	eax, DWORD PTR [rdx]
	add	rdi, 4
	add	eax, DWORD PTR 4[rdx]
	mov	DWORD PTR -4[rdi], eax
	cmp	rcx, rdi
	jne	.L3
.L1:
	ret
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
	test	rsi, rsi
	je	.L9
	mov	r8d, edx
	lea	rcx, [rdi+rsi*4]
	shr	rdx, 32
	.p2align 4,,10
	.p2align 3
.L11:
	mov	eax, DWORD PTR [rdi]
	add	rdi, 4
	imul	eax, r8d
	add	eax, edx
	mov	DWORD PTR -4[rdi], eax
	cmp	rdi, rcx
	jne	.L11
.L9:
	ret
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
	test	rsi, rsi
	je	.L16
	mov	r8d, DWORD PTR [rdx]
	mov	ecx, DWORD PTR 4[rdx]
	lea	rdx, [rdi+rsi*4]
	.p2align 4,,10
	.p2align 3
.L18:
	mov	eax, DWORD PTR [rdi]
	add	rdi, 4
	imul	eax, r8d
	add	eax, ecx
	mov	DWORD PTR -4[rdi], eax
	cmp	rdi, rdx
	jne	.L18
.L16:
	ret
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
	test	rsi, rsi
	je	.L23
	cvttss2si	r8d, DWORD PTR [rdx]
	cvttss2si	ecx, DWORD PTR 4[rdx]
	lea	rdx, [rdi+rsi*4]
	.p2align 4,,10
	.p2align 3
.L25:
	mov	eax, DWORD PTR [rdi]
	add	rdi, 4
	imul	eax, r8d
	add	eax, ecx
	mov	DWORD PTR -4[rdi], eax
	cmp	rdi, rdx
	jne	.L25
.L23:
	ret
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
