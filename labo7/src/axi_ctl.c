#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <fcntl.h>

#define DEV_PATH "/dev/axi_lw"

#define AXI_CST 0xBADB100D

#define BITS_SWITCHS 0x000003FF
#define BITS_LEDS    0x000003FF
#define BITS_KEY     0x0000000F

#define KEY0 0x1u
#define KEY1 0x2u
#define KEY2 0x4u
#define KEY3 0x8u

#define AXI_IOC_MAGIC 'q'
#define AXI_IOC_GET_CST       _IOR(AXI_IOC_MAGIC, 0, uint32_t)
#define AXI_IOC_GET_TEST      _IOR(AXI_IOC_MAGIC, 1, uint32_t)
#define AXI_IOC_SET_TEST      _IOW(AXI_IOC_MAGIC, 2, uint32_t)
#define AXI_IOC_GET_KEYS      _IOR(AXI_IOC_MAGIC, 3, uint32_t)
#define AXI_IOC_GET_KEYS_EDGE _IOR(AXI_IOC_MAGIC, 4, uint32_t)
#define AXI_IOC_ACK_KEYS      _IOW(AXI_IOC_MAGIC, 5, uint32_t)
#define AXI_IOC_GET_SWITCH    _IOR(AXI_IOC_MAGIC, 6, uint32_t)
#define AXI_IOC_SET_LEDS      _IOW(AXI_IOC_MAGIC, 7, uint32_t)
#define AXI_IOC_CLR_LEDS      _IOW(AXI_IOC_MAGIC, 8, uint32_t)
#define AXI_IOC_SET_HEX3_0    _IOW(AXI_IOC_MAGIC, 9, uint32_t)
#define AXI_IOC_SET_HEX5_4    _IOW(AXI_IOC_MAGIC, 10, uint32_t)

#define HEX_BITS_OFFSET 8

static const uint8_t VAL2SEG[16] = {
	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
	0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
};

static int dev_fd = -1;

static uint16_t val = 0;
static uint8_t legal = 1;

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
	(void)ioctl_get(AXI_IOC_GET_CST, &out);
	return out;
}

static void write_test(uint32_t value) {

	(void)ioctl_set(AXI_IOC_SET_TEST, value);
}

static uint32_t read_test(void) {

	uint32_t out = 0;
	(void)ioctl_get(AXI_IOC_GET_TEST, &out);
	return out;
}

static uint8_t read_keys_edges(void) {

	uint32_t out = 0;
	(void)ioctl_get(AXI_IOC_GET_KEYS_EDGE, &out);
	return (uint8_t)(out & BITS_KEY);
}

static uint16_t read_switch(void) {

	uint32_t out = 0;
	(void)ioctl_get(AXI_IOC_GET_SWITCH, &out);
	return (uint16_t)(out & BITS_SWITCHS);
}

static void set_leds(uint16_t leds) {

	(void)ioctl_set(AXI_IOC_SET_LEDS, (uint32_t)leds);
}

static void clear_leds(uint16_t leds) {

	(void)ioctl_set(AXI_IOC_CLR_LEDS, (uint32_t)leds);
}

static void seg7_write_int(uint32_t value) {

	uint32_t hex3_0 = 0;
	uint32_t i;

	for (i = 0; i < 4; i++) {
		hex3_0 |= (uint32_t)VAL2SEG[value % 10] << (HEX_BITS_OFFSET * i);
		value /= 10;
	}

	(void)ioctl_set(AXI_IOC_SET_HEX3_0, hex3_0);
	(void)ioctl_set(AXI_IOC_SET_HEX5_4, 0);
}

static void key0(void) {
	val = read_switch();
	legal = 1;
}

static void key1(void) {
	if (val > 0) {
		--val;
		legal = 1;
	} else {
		legal = 0;
	}
}

static void key2(void) {
	if (val < BITS_SWITCHS) {
		++val;
		legal = 1;
	} else {
		legal = 0;
	}
}

static void key3(void) {
	val = 0;
	legal = 1;
}

int main(void) {
	uint32_t cste;
	uint32_t test_val;
	uint32_t test_val_check;

	dev_fd = open(DEV_PATH, O_RDWR);
	if (dev_fd < 0) {
		perror("open " DEV_PATH);
		return EXIT_FAILURE;
	}

	printf("Lab 7 — AXI4-Lite FPGA IO (driver ioctl)\n");

	cste = read_cst();
	printf("Constante : 0x%08" PRIX32 " (lu)\n", cste);
	printf("Constante : 0x%08" PRIX32 " (attendu)\n", (uint32_t)AXI_CST);

	test_val = 0x00C0FFEE;
	write_test(test_val);
	printf("Test : 0x%08" PRIX32 " (ecrit)\n", test_val);
	test_val_check = read_test();
	printf("Test : 0x%08" PRIX32 " (lu)\n", test_val_check);

	if (cste != AXI_CST || test_val != test_val_check) {
		close(dev_fd);
		return EXIT_FAILURE;
	}

	for (;;) {
		uint8_t keys_edges = read_keys_edges();

		if (keys_edges & KEY0) {
			key0();
		}
		if (keys_edges & KEY1) {
			key1();
		}
		if (keys_edges & KEY2) {
			key2();
		}
		if (keys_edges & KEY3) {
			key3();
		}

		if (legal) {
			clear_leds(BITS_LEDS);
		} else {
			set_leds(BITS_LEDS);
		}
		seg7_write_int((uint32_t)val);

		usleep(15000);
	}
}
