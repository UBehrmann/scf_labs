/*
 * Reference userspace demo — 4x4 grayscale patch, 3x3 sharpen kernel.
 * Matches labo7 open/ioctl/read/write flow; register map from labo9.
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

static const uint8_t image_4x4[16] = {
	10, 20, 30, 40,
	50, 60, 70, 80,
	90, 100, 110, 120,
	130, 140, 150, 160
};

static int write_pixels(int fd, const uint8_t *px, size_t count)
{
	size_t i = 0;

	while (i + 3 < count) {
		uint32_t word = px[i] | ((uint32_t)px[i + 1] << 8) |
				((uint32_t)px[i + 2] << 16) | ((uint32_t)px[i + 3] << 24);
		if (write(fd, &word, sizeof(word)) != (ssize_t)sizeof(word)) {
			perror("write");
			return -1;
		}
		i += 4;
	}
	return 0;
}

static int drain_outputs(int fd, size_t max_reads)
{
	size_t n;
	uint32_t out;

	for (n = 0; n < max_reads; n++) {
		if (read(fd, &out, sizeof(out)) != (ssize_t)sizeof(out)) {
			perror("read");
			return -1;
		}
		printf("  out[%zu] = %d (0x%08" PRIX32 ")\n", n, (int)(int32_t)out, out);
	}
	return 0;
}

int main(void)
{
	int fd;
	uint32_t width = 4;
	uint32_t status;

	fd = open(DEV_PATH, O_RDWR);
	if (fd < 0) {
		perror("open " DEV_PATH);
		return EXIT_FAILURE;
	}

	printf("SCF reference — convolution smoke test\n");

	if (ioctl(fd, 0, CMD_RST) < 0) {
		perror("ioctl reset");
		close(fd);
		return EXIT_FAILURE;
	}

	if (ioctl(fd, 2, &width) < 0) {
		perror("ioctl set width");
		close(fd);
		return EXIT_FAILURE;
	}
	printf("Image width = %" PRIu32 "\n", width);
	printf("Streaming 4x4 input (%zu writes)...\n", sizeof(image_4x4) / 4);
	if (write_pixels(fd, image_4x4, sizeof(image_4x4)) < 0) {
		close(fd);
		return EXIT_FAILURE;
	}

	usleep(10000);

	if (ioctl(fd, 1, &status) == 0)
		printf("Status: 0x%08" PRIX32 " (done=%d empty=%d)\n",
		       status, !!(status & BITS_ST_DONE), !!(status & BITS_ST_OUT_EMPTY));

	printf("Reading up to 8 outputs:\n");
	if (drain_outputs(fd, 8) < 0) {
		close(fd);
		return EXIT_FAILURE;
	}

	printf("Done — verify CST in dmesg at insmod.\n");
	close(fd);
	return EXIT_SUCCESS;
}
