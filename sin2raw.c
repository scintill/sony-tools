#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// #define VERBOSE

// Hardcoding is bad, what if we have more than that ?
struct sin_block_descriptor {
  int target_offset;
  int block_count;
  int unknown1;
  int unknown2;
  int sin_block_payload_size;
  unsigned char payload[20];
} block_desc[1024];

int block_desc_cnt = 0;
unsigned char empty_block[4096];

unsigned int read_short(FILE *fd)
{
  unsigned int ret;
  unsigned char c[2];
  fread(c, 1, 2, fd);
  return (((unsigned int)c[0]) << 8) + (unsigned int)c[1];
}

void dump(unsigned char *buffer, int size)
{
  int i;
  for(i = 0 ; i < size ; i++) {
    printf("%02X ", buffer[i]);
    if(i % 8 == 7) printf(" ");
    if(i % 16 == 15) printf("\n");
  }
  printf("\n");
}

main(int argc, char **argv)
{
  unsigned int data_offset=0, file_header_offset=0, file_header_size=0, magic=0, dummy;
  FILE *fd, *fo;
  char *header;
  int target_size, raw_size;
  int i, j;

  printf("\n\nsin2raw v0.1 by LeTama\n\n");

  if(argc == 4)  {
    int mult=1;
    // target size defined
    char e = argv[3][strlen(argv[3]) - 1];
    switch(e) {
    case 'K':
      mult = 1024;
      break;
    case 'M':
      mult = 1024*1024;
      break;
    case 'G':
      mult = 1024*1024*1024;
      break;
    }
    if(mult > 1) {
      argv[3][strlen(argv[3]) - 1] = 0;
    }
    target_size = mult * atoi(argv[3]);
#ifdef VERBOSE
    printf("Target size=%d\n", target_size);
#endif
  } else if(argc != 3) {
    printf("usage: sin2raw <input sin> <output> [target size[K/M/G]]\n\n");
    return -1;
  }

  fd = fopen(argv[1], "r");
  // 0x0200 0000
  fread(&magic, 1, sizeof(int), fd);
  // header payload (short)
  data_offset = read_short(fd);
  // 0x0900 ??
  fread(&dummy, 1, 2, fd);
  // 0x0000 0000
  fread(&dummy, 1, 4, fd);
  // 0x00 
  fread(&dummy, 1, 1, fd);
  // header offset
  file_header_offset = read_short(fd);

  printf("File data offset   = 0x%04X\n", data_offset);
  printf("File header offset = 0x%04X\n", file_header_offset);

#if 0
  // Dump header
  fseek(fd, file_header_offset, SEEK_SET);
  file_header_size = data_offset - file_header_offset;
  printf("File header size = %d\n", file_header_size);
  header = (char *)malloc(file_header_size);
  fread(header, 1, file_header_size, fd);
  fo = fopen(argv[2], "w");
  fwrite(header, 1, file_header_size, fo);
  fclose(fo);
  free(header);
#endif

  // dump sin block
  fseek(fd, 15, SEEK_SET);
  
  while(ftell(fd) < file_header_offset) {
    unsigned char hash_header[9];
    unsigned char hash[32];
    int index, sz, unk1, unk2, bkcnt;
    fread(hash_header, 1, 9, fd);

#ifdef VERBOSE
    printf("---- block_desc ------\n");
    dump(hash_header, 9);
#endif
    // hash index (int) 
    index = (((int) hash_header[0]) << 24) + (((int) hash_header[1]) << 16) + (((int) hash_header[2]) << 8) + (int) hash_header[3];

    unk1 = (int) hash_header[4];
    
    // word bkcnt
    bkcnt = (((int) hash_header[5]) << 8) + (int)hash_header[6];

    unk2 = (int) hash_header[7];
    // char, sz
    sz =  hash_header[8];

    printf("blk[%04d]@%04lX: offset 0x%08X, blocks=%04X  (unk1=%02X unk2=%02X sz=%02X)\n", block_desc_cnt, ftell(fd), index, bkcnt, unk1, unk2, sz);

    block_desc[block_desc_cnt].target_offset = index;
    block_desc[block_desc_cnt].block_count = bkcnt;
    block_desc[block_desc_cnt].unknown1 = unk1;
    block_desc[block_desc_cnt].unknown2 = unk2;
    block_desc[block_desc_cnt].sin_block_payload_size = sz;
    // Too lazy to fill this one, won't be used
    //    block_desc[block_desc_cnt].payload[20];

    if(raw_size < index + bkcnt * 256) {
      raw_size = index + bkcnt * 256;
    }

    block_desc_cnt++;

    // skip hash, don't care for now
    //    fseek(fd, sz, SEEK_CUR);
    fread(hash, 1, sz, fd);
#ifdef VERBOSE
    printf("--- hash:\n");
    dump(hash, sz);
    printf("\n");
#endif
  }

  printf("-> %d descriptors, raw size=%d\n", block_desc_cnt, raw_size);
  if(target_size == 0) {
    target_size = raw_size;
  }

  // Now prepare output
  // First init output file to proper size
  printf("\nInitializing output ... ");
  fflush(stdout);
  memset(empty_block, 0xff, 1024);
  fo = fopen(argv[2], "w");

  // We should figure out target size somehow
  while(target_size > 1024) {
    fwrite(empty_block, 1, 1024, fo);
    target_size -= 1024;
  }
  if(target_size) {
    fwrite(empty_block, 1, target_size, fo);
  }	 
  printf(" done!\n");


  // Rewind input file
  // +16 to skip header
  fseek(fd, data_offset  + 16, SEEK_SET);


  printf("Writing output ");
  for(i = 0 ; i < block_desc_cnt ; i++) {
    // move to right location on target
    printf(".");
    fflush(stdout);

#ifdef VERBOSE
    printf("Writing block at %08X\n", block_desc[i].target_offset);
#endif
    fseek(fo, block_desc[i].target_offset, SEEK_SET);
    for(j = 0; j < block_desc[i].block_count ; j++) {
      fread(empty_block, 1, 256, fd);
      fwrite(empty_block, 1, 256, fo);
    }
  }

  fclose(fo);
  fclose(fd);
  printf("\n\nFile has been successfully extracted.\n\n", argv[2]);
}
