.global long_mode_start

.section .text
long_mode_start:
	# print `OKAY` to screen
	movq 0x2f592f412f4b2f4f, %rax
	movq %rax, 0xb8000
	hlt
