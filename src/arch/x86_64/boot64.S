.global long_mode_start

.code64
.section .text
long_mode_start:
		# load 0 into all data segment registers
		movw	$0, %ax
		movw	%ax, %ss
		movw	%ax, %ds
		movw	%ax, %es
  		movw	%ax, %fs
		movw	%ax, %gs

		# print `OKAY` to screen
		movq	$0x2f592f412f4b2f4f, %rax
		movq	%rax, 0xb8000
		hlt
