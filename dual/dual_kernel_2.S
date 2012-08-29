	.data
	.global kernel2_start
	.global kernel2_size
	.global cpio2_start
	.global cpio2_size
/* first kernel, bootloader kernel */

kernel2_start:
	.word	kernel2_begin
kernel2_size:
	.word 	kernel2_end - kernel2_begin
cpio2_start:
	.word	cpio2_begin
cpio2_size:
	.word 	cpio2_end - cpio2_begin

	.align 4, 0
kernel2_begin:
	.incbin "stock_zimage"
kernel2_end:
	.align 4, 0
cpio2_begin:
	.incbin "stock_cpio.gz"
cpio2_end:
	.align 4, 0
