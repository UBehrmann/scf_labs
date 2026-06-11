#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>

#define DEV_PATH "/dev/CRCSCF"

#define CRC_CST 0xBADB100D

#define CRC_IOC_MAGIC 'q'
#define CRC_IOC_GET_CST       _IOR(CRC_IOC_MAGIC, 0, uint32_t)
#define CRC_IOC_GET_TEST      _IOR(CRC_IOC_MAGIC, 1, uint32_t)
#define CRC_IOC_SET_TEST      _IOW(CRC_IOC_MAGIC, 2, uint32_t)
#define CRC_IOC_SET_CRCIN     _IOW(CRC_IOC_MAGIC, 3, uint32_t)
#define CRC_IOC_SET_INIT      _IOW(CRC_IOC_MAGIC, 4, uint32_t)
#define CRC_IOC_SET_SIZE      _IOW(CRC_IOC_MAGIC, 5, uint32_t)
#define CRC_IOC_SET_XOROUT    _IOW(CRC_IOC_MAGIC, 6, uint32_t)

#define AXI_IO_CHUNK        4

static int dev_fd = -1;

static int ioctl_get(unsigned long req, uint32_t *out) {

	if (ioctl(dev_fd, req, out) != 0) {
		perror("ioctl get");
		return -1;
	}
	return 0;
}

static int ioctl_set(unsigned long req, uint32_t value) {

	if (ioctl(dev_fd, req, &value) != 0) {
		perror("ioctl set");
		return -1;
	}
	return 0;
}

static uint32_t read_cst(void) {

	uint32_t out = 0;
	(void)ioctl_get(CRC_IOC_GET_CST, &out);
	return out;
}

static void write_test(uint32_t value) {

	(void)ioctl_set(CRC_IOC_SET_TEST, value);
}

static uint32_t read_test(void) {

	uint32_t out = 0;
	(void)ioctl_get(CRC_IOC_GET_TEST, &out);
	return out;
}

// Paramètres

static void write_crc_in(uint32_t value) {
	(void)ioctl_set(CRC_IOC_SET_CRCIN, value);
}

static void write_init(uint32_t value) {
	(void)ioctl_set(CRC_IOC_SET_INIT, value);
}

static void write_size(uint32_t value) {
	(void)ioctl_set(CRC_IOC_SET_SIZE, value);
}

static void write_xorout(uint32_t value) {
	(void)ioctl_set(CRC_IOC_SET_XOROUT, value);
}

// Fonction crc32 sur FPGA
uint32_t crc32_fpga(const char *data, size_t length, uint32_t poly, uint32_t init, uint32_t xorout){

	uint32_t out;

	// initialise FPGA
	write_crc_in(poly);
	write_init(init);
	write_size(length);
	write_xorout(xorout);

	// Envoie donnée
	for (size_t i = 0; i < length; i++) {

		if (write(dev_fd, &data[i], AXI_IO_CHUNK) != AXI_IO_CHUNK) {
			perror("write");
			return -1;
		}
		// Doit set status a 1 avant d'envoyer le prochain
		usleep(15000);
	}

	// Block jusqu'à IRQ
	if (read(dev_fd, &out, AXI_IO_CHUNK) != AXI_IO_CHUNK) {
			perror("read");
			return -1;
		}

	return out;
}


/* CRC32 using the given polynomial (MSB-first, non-reflected) */
uint32_t crc32(const char *data, size_t length, uint32_t poly, uint32_t init, uint32_t xorout)
{
    uint32_t crc = init;

    for (size_t i = 0; i < length; i++) {
        crc ^= (uint32_t)(uint8_t)data[i] << 24;
        for (int bit = 0; bit < 8; bit++) {
            if (crc & 0x80000000u)
                crc = (crc << 1) ^ poly;
            else
                crc <<= 1;
        }
    }

    return crc ^ xorout;
}

int main(void) {
	uint32_t cste;
	uint32_t test_val;
	uint32_t test_val_check;

	// Test driver

	dev_fd = open(DEV_PATH, O_RDWR);
	if (dev_fd < 0) {
		perror("open " DEV_PATH);
		return EXIT_FAILURE;
	}

	printf("TE2 - SCF\n");

	// Test simple FPGA

	cste = read_cst();
	printf("Constante : 0x%08" PRIX32 " (lu)\n", cste);
	printf("Constante : 0x%08" PRIX32 " (attendu)\n", (uint32_t)CRC_CST);

	test_val = 0x00C0FFEE;
	write_test(test_val);
	printf("Test : 0x%08" PRIX32 " (ecrit)\n", test_val);
	test_val_check = read_test();
	printf("Test : 0x%08" PRIX32 " (lu)\n", test_val_check);

	if (cste != CRC_CST || test_val != test_val_check) {
		close(dev_fd);
		return EXIT_FAILURE;
	}

	// Test CRC
	const char msg[] = "123456789";
    int nb_errors = 0;
    uint32_t result, result_fpga;

    /* CRC-32/BZIP2: poly=0x04C11DB7, init=0xFFFFFFFF, xorout=0xFFFFFFFF → 0xFC891918 */
    result = crc32(msg, sizeof(msg) - 1, 0x04C11DB7u, 0xFFFFFFFFu, 0xFFFFFFFFu);
	result_fpga = crc32_fpga(msg, sizeof(msg) - 1, 0x04C11DB7u, 0xFFFFFFFFu, 0xFFFFFFFFu);

    printf("CRC-32-CPU  \"%s\" = 0x%08X  ", msg, result);
	printf("CRC-32-FPGA  \"%s\" = 0x%08X  ", msg, result_fpga);

    if (result == 0xFC891918u)
        printf("OK CPU\n");
    else { printf("FAIL CPU (expected 0xFC891918)\n"); nb_errors++; }

	// Test FPGA
	if (result_fpga == 0xFC891918u)
        printf("OK FPGA\n");
    else { printf("FAIL FPGA (expected 0xFC891918)\n"); nb_errors++; }

    /* CRC-32/CKSUM: poly=0x04C11DB7, init=0x00000000, xorout=0xFFFFFFFF → 0x765E7680 */
    result = crc32(msg, sizeof(msg) - 1, 0x04C11DB7u, 0x00000000u, 0xFFFFFFFFu);
	result_fpga = crc32_fpga(msg, sizeof(msg) - 1, 0x04C11DB7u, 0xFFFFFFFFu, 0xFFFFFFFFu);

    printf("CRC-32-CPU  \"%s\" = 0x%08X  ", msg, result);
	printf("CRC-32-FPGA  \"%s\" = 0x%08X  ", msg, result_fpga);

    if (result == 0x765E7680u)
        printf("OK\n");
    else { printf("FAIL CPU (expected 0x765E7680)\n"); nb_errors++; }

    // Test FPGA
	if (result_fpga == 0x765E7680u)
        printf("OK\n");
    else { printf("FAIL FPGA (expected 0xFC891918)\n"); nb_errors++; }
    
    return (nb_errors == 0) ? 0 : 1;
}
