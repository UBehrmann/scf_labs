/*
 * Generic userspace demo — works with any stream IP using axi_regs.h layout.
 * Replace test vectors with values from exam handout.
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

#include "axi_regs.h"
#include "ioctl_cmds.h"

#define DEV_PATH "/dev/scf_ip"   /* TODO: match driver DEV_NAME */

static int selftest_regs(int fd)
{
	struct scf_params params = {
		.p0 = 0x00000001,  /* TODO: FIR C0 or kernel col0 */
		.p1 = 0x00000002,
		.p2 = 0x00000003,
	};
	uint32_t status;

	if (ioctl(fd, IOCTL_SCF_RESET, 0) < 0) {
		perror("IOCTL_SCF_RESET");
		return -1;
	}

	if (ioctl(fd, IOCTL_SCF_SET_PARAMS, &params) < 0) {
		perror("IOCTL_SCF_SET_PARAMS");
		return -1;
	}

	if (ioctl(fd, IOCTL_SCF_GET_STATUS, &status) == 0)
		printf("status=0x%08" PRIX32 "\n", status);

	return 0;
}

static int stream_io(int fd)
{
	/* TODO: paste input vector from exam */
	static const uint8_t input[] = { 1, 2, 3, 4, 5, 6, 7, 8 };
	static const uint8_t expected[] = { 0, 0, 0, 0 }; /* TODO */
	size_t i;
	uint32_t word, out;

	for (i = 0; i + AXI_IO_CHUNK <= sizeof(input); i += AXI_IO_CHUNK) {
		memcpy(&word, &input[i], AXI_IO_CHUNK);
		if (write(fd, &word, AXI_IO_CHUNK) != AXI_IO_CHUNK) {
			perror("write");
			return -1;
		}
		/* TODO: wait ST_OUT_READY or IRQ — here naive immediate read */
		if (read(fd, &out, AXI_IO_CHUNK) != AXI_IO_CHUNK) {
			perror("read");
			return -1;
		}
		printf("chunk %zu: out=0x%08" PRIX32 "\n", i / AXI_IO_CHUNK, out);
	}

	(void)expected;
	return 0;
}

int main(void)
{
	int fd;

	fd = open(DEV_PATH, O_RDWR);
	if (fd < 0) {
		perror("open " DEV_PATH);
		return EXIT_FAILURE;
	}

	printf("SCF generic userspace test\n");
	printf("Expected constant in dmesg: 0x%08" PRIX32 "\n", (uint32_t)AXI_CONSTANT);

	if (selftest_regs(fd) < 0 || stream_io(fd) < 0) {
		close(fd);
		return EXIT_FAILURE;
	}

	close(fd);
	return EXIT_SUCCESS;
}
