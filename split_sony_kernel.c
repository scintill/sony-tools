#include <elf.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
  Elf32_Ehdr header;
  Elf32_Phdr *phdr;
  int i;
  printf("Sony kernel splitter v 0.1 by LeTama\n\n");
  FILE *fi = fopen(argv[1], "r");
  fread(&header, 1, sizeof(header), fi);
  if(header.e_ident[0] != ELFMAG0 || header.e_ident[1] != ELFMAG1 || header.e_ident[2] != ELFMAG2 || header.e_ident[3] != ELFMAG3) {
    printf("ELF magic not found, exiting\n");
    return 1;
  }

  printf("ELF magic found\n");
  printf("Entry point          : 0x%08X\n", header.e_entry);
  printf("Program Header start : 0x%x\n", header.e_phoff);
  printf("Program Header size  : %d\n", header.e_phentsize);
  printf("Program Header count : %d\n" , header.e_phnum);
  
  phdr = malloc(sizeof(Elf32_Phdr) * header.e_phnum);
  fseek(fi, header.e_phoff, SEEK_SET);
  for(i = 0; i < header.e_phnum ; i++) {
    fread(&phdr[i], 1, sizeof(Elf32_Phdr), fi);
    printf("-> PH[%d], type=%d, offset=%08X, virtual=%08X, phy=%08X, size=%d\n", i, 
	   phdr[i].p_type,
	   phdr[i].p_offset,
	   phdr[i].p_vaddr,
	   phdr[i].p_paddr,
	   phdr[i].p_filesz
	   );
  }

  for(i = 0; i < header.e_phnum ; i++) {
    char fname[256];
    FILE *fo;
    char *buff;
    sprintf(fname, "sec%d-0x%08X.bin", i, phdr[i].p_vaddr);
    printf("... dumping %s\n", fname);
    buff = malloc(phdr[i].p_filesz);
    fo = fopen(fname, "w");
    fseek(fi, phdr[i].p_offset, SEEK_SET);
    fread(buff, 1, phdr[i].p_filesz, fi);
    fwrite(buff, 1, phdr[i].p_filesz, fo);
    fclose(fo);
    free(buff);
  }
  return 0;
}
