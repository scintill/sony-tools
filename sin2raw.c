#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Hardcoding is bad, what if we have more than that ?
struct sin_file {
  unsigned int data_offset;
  unsigned int cert_offset;
  int block_desc_cnt;
  int has_partinfo;
  unsigned int part_id;
  unsigned int part_attribs;
  unsigned int part_start;
  unsigned int part_len;
  size_t raw_size;
  size_t target_size;
} _sin;

struct sin_block_descriptor {
  size_t target_offset;
  size_t length;
  int sin_block_payload_size;
  unsigned char payload[20];
} block_desc[4096];

int block_desc_cnt = 0;
unsigned char empty_block[4096];

unsigned int read_short(FILE *fd)
{
  unsigned int ret;
  unsigned char c[2];
  fread(c, 1, 2, fd);
  return (((unsigned int)c[0]) << 8) + (unsigned int)c[1];
}

unsigned int read_int(FILE *fd)
{
  unsigned int ret;
  unsigned char c[4];
  fread(c, 1, 4, fd);
  return (((unsigned int)c[0]) << 24) + (((unsigned int)c[1]) << 16) + (((unsigned int)c[2]) << 8) + (unsigned int)c[3];
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

void read_sin_header(FILE *fd)
{
  int magic, dummy;
  _sin.has_partinfo = 0;
  _sin.block_desc_cnt = 0;
  _sin.raw_size = 0;

  // 0x0200 0000
  fread(&magic, 1, sizeof(int), fd);
  // header payload (short)
  _sin.data_offset = read_short(fd);
  // 0x0900 ??
  fread(&dummy, 1, 2, fd);
  // 0x0000 0000
  fread(&dummy, 1, 4, fd);
  // 0x00
  fread(&dummy, 1, 1, fd);
  // header offset
  _sin.cert_offset = read_short(fd);
  printf("File data offset   = 0x%04X\n", _sin.data_offset);
  printf("Certificate offset = 0x%04X\n", _sin.cert_offset);
}

void read_block_descriptors(FILE *fd)
{
  // dump sin block
  fseek(fd, 15, SEEK_SET);
  while(ftell(fd) < _sin.cert_offset) {
    unsigned char hash_header[9];
    unsigned char hash[32];
    //    int index, sz, unk1, unk2, bkcnt;
    fread(hash_header, 1, 9, fd);

    block_desc[_sin.block_desc_cnt].target_offset = (((int) hash_header[0]) << 24) + (((int) hash_header[1]) << 16) + (((int) hash_header[2]) << 8) + (int) hash_header[3];
    block_desc[_sin.block_desc_cnt].length = (((int) hash_header[4]) << 24) + (((int) hash_header[5]) << 16) + (((int) hash_header[6]) << 8) + (int) hash_header[7];
    block_desc[_sin.block_desc_cnt].sin_block_payload_size = hash_header[8];

    printf("blk[%04d]@%04lX: offset 0x%08lX, length=0x%08lX  (sz=%02lX)\n", _sin.block_desc_cnt, (unsigned long)ftell(fd), 
	   (unsigned long)block_desc[_sin.block_desc_cnt].target_offset,
	   (unsigned long)block_desc[_sin.block_desc_cnt].length,
	   (unsigned long)block_desc[_sin.block_desc_cnt].sin_block_payload_size);


    // loader has special handling, reset offset to avoid huge file
    if((_sin.block_desc_cnt == 0) && (block_desc[0].target_offset == 0x42300000)){
      printf("Loader detected, using fixup 0x42300000->0\n");
      block_desc[0].target_offset = 0;
    }

    // check if we have partition_info
    if((_sin.block_desc_cnt == 1) &&  (block_desc[1].target_offset == 0)) {
      printf("sin file has partition_info\n");
      _sin.has_partinfo = 1;
    }

    // Too lazy to fill this one, won't be used
    //    block_desc[block_desc_cnt].payload[20];
    if(_sin.raw_size < block_desc[_sin.block_desc_cnt].target_offset + block_desc[_sin.block_desc_cnt].length) {
      _sin.raw_size = block_desc[_sin.block_desc_cnt].target_offset + block_desc[_sin.block_desc_cnt].length;
    }


    // skip hash, don't care for now
    //    fseek(fd, sz, SEEK_CUR);
    fread(hash, 1, block_desc[_sin.block_desc_cnt].sin_block_payload_size, fd);
    _sin.block_desc_cnt++;
  }

  printf("-> %d descriptors, raw size=%lu\n", _sin.block_desc_cnt, (unsigned long)_sin.raw_size);
}

void read_partition_info(FILE *fd)
{
  if(_sin.has_partinfo) {
    // read part_info
    fseek(fd, _sin.data_offset,  SEEK_SET);

    // part bytes are little endian ?
    fread(&_sin.part_id, 4, 1, fd);
    fread(&_sin.part_attribs, 4, 1, fd);
    fread(&_sin.part_start, 4, 1, fd);
    fread(&_sin.part_len, 4, 1, fd);

    printf("--- part_info ---\n");
    printf("part_id      = %08X\n", _sin.part_id);
    printf("part_attribs = %08X\n", _sin.part_attribs);
    printf("part_start   = %08X\n", _sin.part_start);
    printf("part_len     = %08X\n", _sin.part_len);
    printf("\n");
    if(_sin.target_size == 0) {
      _sin.target_size = _sin.part_len * 512;
      printf("-> target size is %lu\n", (unsigned long) _sin.target_size);
    }
  }
}

main(int argc, char **argv)
{
  unsigned int data_offset=0, file_header_offset=0, file_header_size=0, magic=0, dummy, has_partinfo=0;
  FILE *fd, *fo;
  unsigned int i;

  printf("\nsin2raw v0.2 by LeTama\n\n");

  _sin.target_size = 0;
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
    _sin.target_size = mult * atol(argv[3]);
    printf("Target size=%lu\n", (unsigned long)_sin.target_size);
  } else if(argc != 3) {
    printf("usage: sin2raw <input sin> <output> [target size[K/M/G]]\n\n");
    return -1;
  }

  fd = fopen(argv[1], "rb");
  if(fd == NULL) {
    fprintf(stderr, "Error: unable to open %s for reading\n", argv[1]);
    return -2;
  }


  read_sin_header(fd);
  read_block_descriptors(fd);
  read_partition_info(fd);

  // Now prepare output
  // First init output file to proper size
  printf("\nInitializing output (size=%lu)... ", (unsigned long)_sin.target_size);
  fflush(stdout);
  memset(empty_block, 0xff, 4096);
  fo = fopen(argv[2], "wb");
  if(fo == NULL) {
    fprintf(stderr, "Error: unable to open %s for writing\n", argv[2]);
    return -3;
  }

  for(i = 0 ; i < _sin.target_size / 4096 ; i++) {
    fwrite(empty_block, 4096, 1, fo);
  }
  fwrite(empty_block, _sin.target_size % 4096, 1, fo);
  printf(" done!\n");

  // Then write blocks
  printf("Writing output ");
  fseek(fd, _sin.data_offset, SEEK_SET);
  for(i = 0 ; i < _sin.block_desc_cnt ; i++) {
    unsigned char *block;

    printf(".");
    fflush(stdout);

    // move to right location on target
    block = malloc( block_desc[i].length );
    if(!block) {
      fprintf(stderr, "Error, malloc(%lu) failed\n", (unsigned long)block_desc[i].length);
      return -4;
    }
    fseek(fo, block_desc[i].target_offset, SEEK_SET);
    fread(block, block_desc[i].length, 1, fd);
    fwrite(block, block_desc[i].length, 1, fo);
    free(block);
  }

  fclose(fo);
  fclose(fd);
  printf("\n\nFile %s has been successfully extracted.\n\n", argv[2]);
  return 0;
}
