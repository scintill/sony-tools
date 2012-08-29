dual.elf: dual.bin
	mkelf.py -o dual.elf ./dual.bin@0x40208000 dummy.bin.gz@0x41300000,ramdisk sec2-0x00020000.bin@0x20000,rpm

dual.bin: dual
	~/arm-2011.03/bin/arm-none-eabi-objcopy -O binary dual dual.bin

dual: dual_prolog.o dual_kernel_b.o dual_kernel_1.o dual_kernel_2.o dual_loader.o dual.lds
	~/arm-2011.03/bin/arm-none-eabi-ld -T dual.lds -o dual dual_prolog.o dual_kernel_1.o dual_kernel_2.o dual_kernel_b.o dual_loader.o

dual_prolog.o: dual_prolog.S
	~/arm-2011.03/bin/arm-none-eabi-as dual_prolog.S  -o dual_prolog.o 

dual_kernel_b.o: dual_kernel_b.S bl_zimage bl_cpio.gz
	~/arm-2011.03/bin/arm-none-eabi-as dual_kernel_b.S  -o dual_kernel_b.o 

dual_kernel_1.o: dual_kernel_1.S custom_zimage custom_cpio.gz
	~/arm-2011.03/bin/arm-none-eabi-as dual_kernel_1.S  -o dual_kernel_1.o 

dual_kernel_2.o: dual_kernel_2.S stock_zimage stock_cpio.gz
	~/arm-2011.03/bin/arm-none-eabi-as dual_kernel_2.S  -o dual_kernel_2.o 

dual_loader.o: dual_loader.S
	~/arm-2011.03/bin/arm-none-eabi-as dual_loader.S  -o dual_loader.o 

