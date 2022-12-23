.global start

.section .rodata
gdt64:
		.quad 0	# zero entry
.equ gdt64.code, . - gdt64
		.quad (1<<43) | (1<<44) | (1<<47) | (1<<53) # code segment
gdt64.pointer:
		.word . - gdt64 - 1
		.quad gdt64

.section .text
.code32
start:
		movl	$stack_top, %esp

		call	check_multiboot
		call	check_cpuid
		call	check_long_mode

		call	set_up_page_tables
		call	enable_paging

		lgdt	(gdt64.pointer)								# load the 64-bit gdt
		jmp		$gdt64.code, $long_mode_start				# long jump to long mode

		hlt

check_multiboot:
		cmp		$0x36d76289, %eax	# multiboot leaves this magic number in eax
		jne		.no_multiboot
		ret
.no_multiboot:
		movb	$'M, %al
		jmp		error

check_cpuid:
		# check if CPUID is avaliable by trying to flip the ID bit (bit 21)
		# on the FLAGS  register. If we can flip it, CPUIDis avaliable
		# -----------------------------------------------------------------

		# copy FLAGS to EAX
		pushfl
		pop		%eax

		# copy to ECX for comparing later
		mov		%eax, %ecx
	
		# flip the ID bit
		xor		$1 << 21, %eax

		# copy EAX to FLAGS
		push	%eax
		popfl

		# copy FLAGS to EAX (with fliped bit if CPUID supported)
		pushfl
		pop		%eax

		# restore old FLAGS (fliping the bit back if it wasn't flipped)
		push	%ecx
		popfl

		# Compare EAX and ECX, if they are equal Id bit wasnt flipped and cpuid isnt supported
		cmp		%eax, %ecx
		je		.no_cpuid
		ret
.no_cpuid:
		movb	$'C, %al
		jmp error

check_long_mode:
		# test if extended processor info in available
		mov		$0x80000000, %eax		# implicit argument for cpuid
		cpuid							# get highest supported argument
		cmp		$0x80000001, %eax		# it needs to be at least 0x80000001
		jb		.no_long_mode			# if it's less, the CPU is too old for long mode

		# use extended info to test if long mode is available
		mov		$0x80000001, %eax		# argument for extended processor info
		cpuid							# returns various feature bits in ecx and edx
		test	$1 << 29, %edx			# test if the LM-bit is set in the D-register
		jz		.no_long_mode			# If it's not set, there is no long mode
		ret
.no_long_mode:
		mov		$'L, %al
		jmp		error

set_up_page_tables:
		# map first P4 entry to P3 table
		movl	$p3_table, %eax
		orl		$0b11, %eax			# present + writable bits
		movl	%eax, p4_table

		# map first P3 entry to P2 table
		movl	$p2_table, %eax
		orl		$0b11, %eax  		# present + writable bits
		movl	%eax, p3_table

		# map each P2 entry to a huge 2 MiB page
		movl	$0, %ecx			# counter variable

.map_p2_table:
		# map each ecx-th P2 entry to a huge page that starts at address 2MiB * ECX
		movl	0x200000, %eax				# 2 MiB
		mul		%ecx						# start address of ecx-th page
		orl		$0b10000011, %eax			# present + writable + huge bits
		movl	%eax, p2_table(, %ecx, 8)	# map ecx-th entry

		inc		%ecx						# increment counter
		cmp		$512, %ecx					# if counter == 512, the whole P2is mapped
		jne		.map_p2_table				# else map the next entry

		ret

enable_paging:
		# load P4 table to cr3 register (cpu uses this to access P4 table)
		movl	$p4_table, %eax
		movl	%eax, %cr3

		# enable PAE-flag in cr4 (Phisical Adress Extension)
		movl	%cr4, %eax
		orl		$1 << 5, %eax
		movl	%eax, %cr4

	# set the long mode bit in the EFER MSR (model specific register)
		movl	$0xC0000080, %ecx
		rdmsr
		orl		$1 << 8, %eax
		wrmsr

		# enable paging in the cr0 register
		movl	%cr0, %eax
		orl		$1 << 31, %eax
		movl	%eax, %cr0

		ret

# Prints `ERR: ` and the given error code to screen and hangs.
# parameter: error code (in ascii) in al
error:
		movw	$0x0245, 0xb8000
		movw	$0x0252, 0xb8002
		movw	$0x0252, 0xb8004
		movw	$0x023a, 0xb8006
		movw	$0x0220, 0xb8008
		movw	$0x0220, 0xb800a
		movb	%al, 0xb800a
		hlt

.section .bss
.align 4096
p4_table:
		.skip 4096
p3_table:
		.skip 4096
p2_table:
		.skip 4096

stack_bottom:
		.skip 64
stack_top:
