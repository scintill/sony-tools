/* vi: set sw=4 ts=4: */
/*
 * Mini losetup implementation for busybox
 *
 * Copyright (C) 2002  Matt Kraai.
 *
 * Licensed under GPLv2 or later, see file LICENSE in this source tree.
 */

//usage:#define losetup_trivial_usage
//usage:       "[-r] [-o OFS] LOOPDEV FILE - associate loop devices\n"
//usage:       "	losetup -d LOOPDEV - disassociate\n"
//usage:       "	losetup [-f] - show"
//usage:#define losetup_full_usage "\n\n"
//usage:       "	-o OFS	Start OFS bytes into FILE"
//usage:     "\n	-r	Read-only"
//usage:     "\n	-f	Show first free loop device"
//usage:
//usage:#define losetup_notes_usage
//usage:       "No arguments will display all current associations.\n"
//usage:       "One argument (losetup /dev/loop1) will display the current association\n"
//usage:       "(if any), or disassociate it (with -d). The display shows the offset\n"
//usage:       "and filename of the file the loop device is currently bound to.\n\n"
//usage:       "Two arguments (losetup /dev/loop1 file.img) create a new association,\n"
//usage:       "with an optional offset (-o 12345). Encryption is not yet supported.\n"
//usage:       "losetup -f will show the first loop free loop device\n\n"

/* For 2.6, use the cleaned up header to get the 64 bit API. */
// Commented out per Rob's request
//# include "fix_u32.h" /* some old toolchains need __u64 for linux/loop.h */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <linux/loop.h>
#include <string.h>

typedef struct loop_info64 bb_loop_info;
#define BB_LOOP_SET_STATUS LOOP_SET_STATUS64
#define BB_LOOP_GET_STATUS LOOP_GET_STATUS64
#define LOOP_FORMAT "/dev/block/loop%d"
#define LOOP_NAMESIZE (sizeof("/dev/block/loop") + sizeof(int)*3 + 1)
#define LOOP_NAME "/dev/block/loop"

const char *opt_complementary = "?2:d--of:o--df:f--do";

char queryloop_dev[256];


char* query_loop(const char *device)
{
	int fd;
	bb_loop_info loopinfo;

	fd = open(device, O_RDONLY);
	if (fd >= 0) {
		if (ioctl(fd, BB_LOOP_GET_STATUS, &loopinfo) == 0) {
		  sprintf(queryloop_dev, "%lu %s", (off_t) loopinfo.lo_offset,
					(char *)loopinfo.lo_file_name);
		  return queryloop_dev;
		}
		close(fd);
	}

	return NULL;
}

int del_loop(const char *device)
{
	int fd, rc;

	fd = open(device, O_RDONLY);
	if (fd < 0)
		return 1;
	rc = ioctl(fd, LOOP_CLR_FD, 0);
	close(fd);

	return rc;
}

/* Returns 0 if mounted RW, 1 if mounted read-only, <0 for error.
   *device is loop device to use, or if *device==NULL finds a loop device to
   mount it on and sets *device to a strdup of that loop device name.  This
   search will re-use an existing loop device already bound to that
   file/offset if it finds one.
 */
int set_loop(char **device, const char *file, unsigned long long offset, int ro)
{
	char dev[LOOP_NAMESIZE];
	char *try;
	bb_loop_info loopinfo;
	struct stat statbuf;
	int i, dfd, ffd, mode, rc = -1;

	/* Open the file.  Barf if this doesn't work.  */
	mode = ro ? O_RDONLY : O_RDWR;
	ffd = open(file, mode);
	if (ffd < 0) {
		if (mode != O_RDONLY) {
			mode = O_RDONLY;
			ffd = open(file, mode);
		}
		if (ffd < 0)
			return -errno;
	}

	/* Find a loop device.  */
	try = *device ? *device : dev;
	/* 1048575 is a max possible minor number in Linux circa 2010 */
	for (i = 0; rc && i < 1048576; i++) {
		sprintf(dev, LOOP_FORMAT, i);

 try_to_open:
		/* Open the sucker and check its loopiness.  */
		dfd = open(try, mode);
		if (dfd < 0 && errno == EROFS) {
			mode = O_RDONLY;
			dfd = open(try, mode);
		}
		if (dfd < 0)
			goto try_again;

		rc = ioctl(dfd, BB_LOOP_GET_STATUS, &loopinfo);

		/* If device is free, claim it.  */
		if (rc && errno == ENXIO) {
			memset(&loopinfo, 0, sizeof(loopinfo));
			strncpy((char *)loopinfo.lo_file_name, file, LO_NAME_SIZE);
			loopinfo.lo_offset = offset;
			/* Associate free loop device with file.  */
			if (ioctl(dfd, LOOP_SET_FD, ffd) == 0) {
				if (ioctl(dfd, BB_LOOP_SET_STATUS, &loopinfo) == 0)
					rc = 0;
				else
					ioctl(dfd, LOOP_CLR_FD, 0);
			}

		/* If this block device already set up right, re-use it.
		   (Yes this is racy, but associating two loop devices with the same
		   file isn't pretty either.  In general, mounting the same file twice
		   without using losetup manually is problematic.)
		 */
		} else
		if (strcmp(file, (char *)loopinfo.lo_file_name) != 0
		 || offset != loopinfo.lo_offset
		) {
			rc = -1;
		}
		close(dfd);
 try_again:
		if (*device) break;
	}
	close(ffd);
	if (rc == 0) {
		if (!*device)
			*device = strdup(dev);
		return (mode == O_RDONLY); /* 1:ro, 0:rw */
	}
	return rc;
}


void bb_show_usage()
{
  printf("Usage: losetup [-o OFS] LOOPDEV FILE - associate loop devices\n"
         "losetup -d LOOPDEV - disassociate\n"
         "losetup [-f] - show\n"
	 "\n"
	 "-o OFS  Start OFS bytes into FILE\n"
	 "-f      Show first free loop device\n\n");
}

void bb_simple_perror_msg_and_die(char* s)
{
  fprintf(stderr, "%s error!\n", s);
}


int main(int argc, char **argv)
{
  int n;	
  // Dumb parser, be warned :)

  if(argc == 3) {
    if(strcmp(argv[1],"-d") == 0) {
      if (del_loop(argv[2]))
	bb_simple_perror_msg_and_die(argv[2]);
      return EXIT_SUCCESS;
    }
    else {
      if (set_loop(&argv[1], argv[2], 0, 0))
	bb_simple_perror_msg_and_die(argv[1]);
      return EXIT_SUCCESS;
    }
  }
  n = 0;
  while (1) {
    char *s;
    char dev[LOOP_NAMESIZE];
    sprintf(dev, LOOP_FORMAT, n);
    s = query_loop(dev);
    n++;
    if (n > 9)
      return EXIT_SUCCESS;

    if (!s) {
      printf("%s: %s\n", dev, s);
    }
  }
  return EXIT_SUCCESS;
}
