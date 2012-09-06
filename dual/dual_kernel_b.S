	.data
	.global kernelb_start
	.global kernelb_size
	.global cpiob_start
	.global cpiob_size
/* first kernel, bootloader kernel */

kernelb_magic:
	.ascii "KRN0"
kernelb_start:
	.word	kernelb_begin
kernelb_size:
	.word 	kernelb_end - kernelb_begin
cpiob_start:
	.word	cpiob_begin
cpiob_size:
	.word 	cpiob_end - cpiob_begin
	.balign 4,0
kernelb_begin:
	.incbin "bl_zimage"
kernelb_end:
	.balign 4,0
cpiob_begin:
	/* .include "cpio_b.S"*/
	.incbin "bl_cpio.gz"
cpiob_end:
