# labo7/src/driver/Makefile
KERNELDIR ?= /home/baer/linux-6.18/
CROSS_COMPILE=arm-linux-gnueabihf-
ARCH ?= arm

obj-m := axi_driver.o

all:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) clean