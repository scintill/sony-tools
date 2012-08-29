/*
	struct atag_header {
	        u32 size	;  length of tag in words including this header 
	        u32 tag		;  tag value 
	}			;
	ATAG_CORE    0x54410001
	ATAG_NONE    0x00000000
	ATAG_INITRD2 0x54420005
	struct atag_initrd2 {
	        u32 start          physical start address
	        u32 size	;  size of compressed ramdisk image in bytes 
	}			;
*/
	.text
	.global start_loader
	.arch armv7-a
	.align
	.arm
@	must preserve kernel loading regs, r0=0, r1=mach_tye r2=atag addr
	
start_loader:
	ldr	r4, =0x7ffef000
	ldr	r5, [r4]
	@ TAMA tag 
	ldr 	r4, =0x54414d41
	cmp	r5, r4
	beq	clear_and_select
	b	clear_tag_bootkb

clear_and_select:
	ldr	r4, =0x7ffef000
	mov	r5, #0
	str	r5, [r4]
	ldr	r5, [r4, #4]
	cmp	r5, #1
	beq 	boot_k1
	b	boot_k2

clear_tag_bootkb:
	ldr	r4, =0x7ffef000
	mov	r5, #0
	str	r5, [r4]
	b 	boot_kb


boot_kb:
	ldr	r8, =kernelb_start
	ldr	r4, [r8]
	ldr	r8, =kernelb_size
	ldr	r5, [r8]
	ldr	r8, =cpiob_start
	ldr	r6, [r8]
	ldr	r8, =cpiob_size
	ldr	r7, [r8]
	b	boot_kernel

	
boot_k1:
	ldr	r8, =kernel1_start
	ldr	r4, [r8]
	ldr	r8, =kernel1_size
	ldr	r5, [r8]
	ldr	r8, =cpio1_start
	ldr	r6, [r8]
	ldr	r8, =cpio1_size
	ldr	r7, [r8]
	b	boot_kernel
	
boot_k2:
	ldr	r8, =kernel2_start
	ldr	r4, [r8]
	ldr	r8, =kernel2_size
	ldr	r5, [r8]
	ldr	r8, =cpio2_start
	ldr	r6, [r8]
	ldr	r8, =cpio2_size
	ldr	r7, [r8]
	b	boot_kernel



boot_kernel:
	@ save r7 to patch atags
	mov	r0, r7	
	
	@ copy cpio first as it will be overwritten by kernel
	@ r7 <- end of cpio area
	add	r7, r6, r7
	ldr	r8, =0x41300000
copy_cpio_loop:
	ldmia	r6!, {r9}
	stmia	r8!, {r9}
	cmp	r6, r7
	ble	copy_cpio_loop

	@restore r7
	mov	r7, r0

@ patch CPIO2 atag
	mov	r3, r2
	@ search for tag
tag_loop:
	@ tag is +4
	ldr	r8, [r3, #4]
	ldr	r9, =0x54420005
	cmp	r9, r8
	beq 	modify_tag
	@ tag size
	ldr	r8, [r3]
	add	r3, r3, r8, lsl #2
	b	tag_loop
modify_tag:
/*	str	r6, [r3, #8] */
	str	r7, [r3, #12]
/*	@ r0 must be 0 */
	mov	r0, #0 
	mov	pc, r4
	
	
/*	
boot_kernel:

	@ save r7 to patch atags
	mov	r0, r7	
	
	@ copy cpio first as it will be overwritten by kernel
	@ r7 <- end of cpio area
	add	r7, r6, r7
	ldr	r8, =0x41300000
copy_cpio_loop:
	ldmia	r6!, {r9}
	stmia	r8!, {r9}
	cmp	r6, r7
	ble	copy_cpio_loop

	@ now copy kernel
	@ r5 <- end of kernel area
	add	r5, r4, r5
	ldr	r8, =start
	
copy_kernel_loop:
	ldmia	r4!, {r9}
	stmia	r8!, {r9}
	cmp	r4, r5
	ble	copy_kernel_loop
	
@ patch CPIO2 atag
	mov	r6, r2
	@ search for tag
tag_loop:
	@ tag is +4
	ldr	r8, [r6, #4]
	ldr	r7, =0x54420005
	cmp	r7, r8
	beq 	modify_tag
	@ tag size
	ldr	r8, [r6]
	add	r6, r6, r8, lsl #2
	b	tag_loop
modify_tag:
	str	r0, [r6, #12]
	@ r0 must be 0
	mov	r0, #0
	*/

/*	
	@ clear_cache:
        mrc     p15, 0, r6, c1, c0, 0    
	bic     r5, r6, #(1 << 2)        
	bic     r5, r5, #(1 << 12)       
	mcr     p15, 0, r5, c1, c0, 0    
	dsb
	mcr	p15, 0, r6, c1, c0, 0
	isb
*/	
	@ start kernel
	b 	start

/*

@ alternate mode, direct from key
select_kernel_keyboard:
	@  gpio 73, vol down virt 0xfe005494 -> phy 0x00801494 
	ldr	r4, =0x00801494
	ldr	r5, [r4]
	cmp	r5, #0
	beq	kernel_1

	@ bootloader kernel
kernel_bl:
	ldr	r4, =_kernelbl_start
	ldr	r6, =_kernelbl_end
	ldr	r5, =start
copy_kernel_bl_loop:
	ldmia	r4!, {r7-r8}
	stmia	r5!, {r7-r8}
	cmp	r4, r6
	ble	copy_kernel_bl_loop

	@ bootloader cpio
	ldr	r4, =_cpiobl_start
	ldr	r6, =_cpiobl_end
	ldr	r5, =0x41300000
copy_cpio_bl_loop:
	ldmia	r4!, {r7-r8}
	stmia	r5!, {r7-r8}
	cmp	r4, r6
	ble	copy_cpio_bl_loop

	@ start kernel
	b start

@ first kernel
kernel_1:
	@ clear tag
	ldr	r4, =0x7ffef000
	mov	r5, #0
	str	r5, [r4]

	@ copy kernel
	ldr	r4, =_kernel1_start
	ldr	r6, =_kernel1_end
	ldr	r5, =start
copy_kernel_1_loop:
	ldmia	r4!, {r7-r8}
	stmia	r5!, {r7-r8}
	cmp	r4, r6
	ble	copy_kernel_1_loop

	@ copy cpio
	ldr	r4, =_cpio1_start
	ldr	r6, =_cpio1_end
	ldr	r5, =0x41300000
copy_cpio_1_loop:
	ldmia	r4!, {r7-r8}
	stmia	r5!, {r7-r8}
	cmp	r4, r6
	ble	copy_cpio_1_loop
	@ start kernel
	b start
*/