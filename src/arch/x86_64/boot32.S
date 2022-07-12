.global start

.section .text
.code32
start:
	movl stack_top, %esp

	call check_multiboot
	call check_cpuid
	call check_long_mode

	# Print Hello world to the screen
	movw $0x0248, 0xb8000	# H
	movw $0x0265, 0xb8002	# e
	movw $0x026c, 0xb8004	# l
	movw $0x026c, 0xb8006	# l
	movw $0x026f, 0xb8008	# o
	movw $0x022c, 0xb800a	# ,
	movw $0x0220, 0xb800c	#
	movw $0x0277, 0xb800e	# w
	movw $0x026f, 0xb8010	# o
	movw $0x0272, 0xb8012	# r
	movw $0x026c, 0xb8014	# l
	movw $0x0264, 0xb8016	# d
	movw $0x0221, 0xb8018	# !

	hlt

check_multiboot:
	cmp $0x36d76289, %eax	# multiboot leaves this magic number in eax
	jne .no_multiboot
	ret
.no_multiboot:
	mov $'M, %al
	jmp error

check_cpuid:
	# check if CPUID is avaliable by trying to flip the ID bit (bit 21)
	# on the FLAGS  register. If we can flip it, CPUIDis avaliable
	# -----------------------------------------------------------------

	# copy FLAGS to EAX
	pushfl
	pop %eax

	# copy to ECX for comparing later
	mov %eax, %ecx
	
	# flip the ID bit
	xor $1 << 21, %eax

	# copy EAX to FLAGS
	push %eax
	popfl

	# copy FLAGS to EAX (with fliped bit if CPUID supported)
	pushfl
	pop %eax

	# restore old FLAGS (fliping the bit back if it wasn't flipped)
	push %ecx
	popfl

	# Compare EAX and ECX, if they are equal Id bit wasnt flipped and cpuid isnt supported
	cmp %eax, %ecx
	je .no_cpuid
	ret
.no_cpuid:
	mov $'C, %al
	jmp error

check_long_mode:
	# test if extended processor info in available
	mov $0x80000000, %eax	# implicit argument for cpuid
	cpuid			# get highest supported argument
	cmp $0x80000001, %eax	# it needs to be at least 0x80000001
	jb .no_long_mode	# if it's less, the CPU is too old for long mode

	# use extended info to test if long mode is available
	mov $0x80000001, %eax	# argument for extended processor info
	cpuid			# returns various feature bits in ecx and edx
	test $1 << 29, %edx	# test if the LM-bit is set in the D-register
	jz .no_long_mode	# If it's not set, there is no long mode
	ret
.no_long_mode:
	mov $'L, %al
	jmp error

# Prints `ERR: ` and the given error code to screen and hangs.
# parameter: error code (in ascii) in al
error:
	movw $0x4f45, 0xb8000
	movw $0x4f52, 0xb8002
	movw $0x4f52, 0xb8004
	movw $0x4f3a, 0xb8006
	movw $0x4f20, 0xb8008
	movw $0x4f20, 0xb800a
	movb %al, 0xb800a
	hlt

.section .bss
stack_bottom:
	.skip 64
stack_top:

