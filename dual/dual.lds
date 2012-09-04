SECTIONS {
	 . = 0x40208000;
	 .text0 : { dual_prolog.o (.text); }
	 . = 0x40208100;
	 .data1 : { dual_kernel_b.o (.data); }
	 . = 0x40600000;
	 .data2 : { dual_kernel_2.o (.data); }
	 . = 0x40d00000;
	 .data3 : { dual_kernel_1.o (.data); }
	 . = 0x4128F800;
	 .text1 : { dual_loader.o (.text); }
}
