# Out-of-tree kernel module — adjust KERNELDIR to your tree
KERNELDIR ?= /home/baer/linux-6.18/
ARCH      ?= arm
CROSS_COMPILE ?= arm-linux-gnueabihf-

obj-m := convol_driver.o

# Uncomment when using device-tree overlay built with the module:
# dtb-y += convol.dtbo

.PHONY: all clean

all:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(CURDIR) clean
