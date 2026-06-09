KERNELDIR ?= /home/baer/linux-6.18/
ARCH      ?= arm
CROSS_COMPILE ?= arm-linux-gnueabihf-

obj-m := convol_driver.o

.PHONY: all clean

all:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) clean
