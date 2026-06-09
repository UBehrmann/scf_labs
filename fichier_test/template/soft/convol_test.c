/*
 * Userspace test — TEMPLATE
 * TODO: adapt to exam spec (device name, test vectors, ioctl numbers).
 */
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include "axi.h"
#include "common_constants.h"

#define DEV_PATH "/dev/convol"

static int check_constant(int fd)
{
	uint32_t cst;
	/* TODO: use ioctl or sysfs — reference uses driver read path via sysfs/ioctl */
	(void)fd;
	cst = CONSTANT_VALUE; /* placeholder */
	printf("Constant: 0x%08" PRIX32 " (expected 0x%08" PRIX32 ")\n",
	       cst, (uint32_t)CONSTANT_VALUE);
	return (cst == CONSTANT_VALUE) ? 0 : -1;
}

static int program_kernel(int fd)
{
	/* TODO: 3×3 int8 kernel — exam may use ioctl instead of sysfs */
	int8_t ker[KERN_W * KERN_H] = { -1, 0, -1, 0, 4, 0, -1, 0, -1 };
	(void)fd;
	(void)ker;
	return 0;
}

static int reset_device(int fd)
{
	if (ioctl(fd, 0, CMD_RST) < 0) {
		perror("ioctl reset");
		return -1;
	}
	return 0;
}

static int stream_test(int fd)
{
	/* TODO: write 4-byte chunks, read outputs, compare expected vector */
	(void)fd;
	return 0;
}

int main(void)
{
	int fd;
	int rc = EXIT_SUCCESS;

	fd = open(DEV_PATH, O_RDWR);
	if (fd < 0) {
		perror("open " DEV_PATH);
		return EXIT_FAILURE;
	}

	printf("SCF exam — userspace template\n");

	if (check_constant(fd) < 0)
		rc = EXIT_FAILURE;
	if (program_kernel(fd) < 0)
		rc = EXIT_FAILURE;
	if (reset_device(fd) < 0)
		rc = EXIT_FAILURE;
	if (stream_test(fd) < 0)
		rc = EXIT_FAILURE;

	close(fd);
	return rc;
}
