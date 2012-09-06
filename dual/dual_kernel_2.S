	.data
	.global kernel2_start
	.global kernel2_size
	.global cpio2_start
	.global cpio2_size
/* first kernel, bootloader kernel */

kernel2_magic:
	.ascii	"KRN2"
kernel2_start:
	.word	kernel2_begin
kernel2_size:
	.word 	kernel2_end - kernel2_begin
cpio2_start:
	.word	cpio2_begin
cpio2_size:
	.word 	cpio2_end - cpio2_begin

	.balign 4, 0
kernel2_begin:
	.incbin "custom_zimage"
kernel2_end:
	.balign 4, 0
cpio2_begin:
	.incbin "custom_cpio.gz"
cpio2_end:
	.balign 4, 0
