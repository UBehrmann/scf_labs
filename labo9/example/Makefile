DRV_NAME		= example

KERNEL_SRC		= <path-to-linux>
ARCH			= arm
CROSS_COMPILE		= arm-linux-gnueabihf-

obj-m			+= $(DRV_NAME).o
dtb-y			+= $(DRV_NAME).dtbo

all:
	make ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) -C $(KERNEL_SRC) M=$(PWD) modules

clean:
	make -C $(KERNEL_SRC) M=$(PWD) clean
