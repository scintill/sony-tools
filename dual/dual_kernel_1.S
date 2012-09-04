	.data
	.global kernel1_start
	.global kernel1_size
	.global cpio1_start
	.global cpio1_size
/* first kernel, bootloader kernel */

kernel1_start:
	.word	kernel1_begin
kernel1_size:
	.word 	kernel1_end - kernel1_begin
cpio1_start:
	.word	cpio1_begin
cpio1_size:
	.word 	cpio1_end - cpio1_begin

	.align 4, 0
kernel1_begin:
	.incbin "stock_zimage"
kernel1_end:
	.align 4, 0
cpio1_begin:
	.incbin "stock_cpio.gz"
cpio1_end:
	.align 4, 0
