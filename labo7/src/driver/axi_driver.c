#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/uaccess.h>

#define DRV_NAME "axi_driver"
#define DEV_NAME "axi_lw"

#define AXI_LW_HPS_FPGA_BASE_ADD 0xFF200000
#define AXI_LW_MAP_SIZE          0x1000

#define AXI_CST 0xBADB100D

#define REG_CST               0x0000
#define REG_TEST              0x0004
#define REG_KEYS_EDGE_CAPTURE 0x000C
#define REG_SWITCHS           0x0010
#define REG_LEDS_OUTSET       0x0018
#define REG_LEDS_OUTCLR       0x001C
#define REG_HEX3_0            0x0020
#define REG_HEX5_4            0x0024

#define BITS_SWITCHS 0x000003FF
#define BITS_LEDS    0x000003FF
#define BITS_KEY     0x0000000F
#define BITS_HEX3_0  0x7F7F7F7F
#define BITS_HEX5_4  0x00007F7F

#define AXI_IOC_MAGIC 'q'
#define AXI_IOC_GET_CST       _IOR(AXI_IOC_MAGIC, 0, __u32)
#define AXI_IOC_GET_TEST      _IOR(AXI_IOC_MAGIC, 1, __u32)
#define AXI_IOC_SET_TEST      _IOW(AXI_IOC_MAGIC, 2, __u32)
#define AXI_IOC_GET_KEYS_EDGE _IOR(AXI_IOC_MAGIC, 4, __u32)
#define AXI_IOC_GET_SWITCH    _IOR(AXI_IOC_MAGIC, 6, __u32)
#define AXI_IOC_SET_LEDS      _IOW(AXI_IOC_MAGIC, 7, __u32)
#define AXI_IOC_CLR_LEDS      _IOW(AXI_IOC_MAGIC, 8, __u32)
#define AXI_IOC_SET_HEX3_0    _IOW(AXI_IOC_MAGIC, 9, __u32)
#define AXI_IOC_SET_HEX5_4    _IOW(AXI_IOC_MAGIC, 10, __u32)

static void __iomem *axi_base;

static inline u32 axi_read(u32 reg) {
	return ioread32(axi_base + reg);
}

static inline void axi_write(u32 reg, u32 val) {
	iowrite32(val, axi_base + reg);
}

static long axi_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
	u32 val;

	(void)file;

	if (_IOC_TYPE(cmd) != AXI_IOC_MAGIC)
		return -ENOTTY;

	switch (cmd) {
		case AXI_IOC_GET_CST:
			val = axi_read(REG_CST);
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case AXI_IOC_GET_TEST:
			val = axi_read(REG_TEST);
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case AXI_IOC_SET_TEST:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			axi_write(REG_TEST, val);
			return 0;

		case AXI_IOC_GET_KEYS_EDGE:
			val = axi_read(REG_KEYS_EDGE_CAPTURE) & BITS_KEY;
			axi_write(REG_KEYS_EDGE_CAPTURE, val);
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case AXI_IOC_GET_SWITCH:
			val = axi_read(REG_SWITCHS) & BITS_SWITCHS;
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case AXI_IOC_SET_LEDS:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			axi_write(REG_LEDS_OUTSET, val & BITS_LEDS);
			return 0;

		case AXI_IOC_CLR_LEDS:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			axi_write(REG_LEDS_OUTCLR, val & BITS_LEDS);
			return 0;

		case AXI_IOC_SET_HEX3_0:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			axi_write(REG_HEX3_0, val & BITS_HEX3_0);
			return 0;

		case AXI_IOC_SET_HEX5_4:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			axi_write(REG_HEX5_4, val & BITS_HEX5_4);
			return 0;

		default:
			return -ENOTTY;
	}
}

static const struct file_operations axi_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = axi_ioctl,
};

static struct miscdevice axi_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DEV_NAME,
	.fops = &axi_fops,
	.mode = 0666,
};

static int __init axi_init(void) {
	int ret;
	u32 cst;

	axi_base = ioremap(AXI_LW_HPS_FPGA_BASE_ADD, AXI_LW_MAP_SIZE);
	if (!axi_base)
		return -ENOMEM;

	cst = axi_read(REG_CST);
	if (cst != AXI_CST) {
		pr_err(DRV_NAME ": invalid CST 0x%08x (expected 0x%08x)\n",
		       cst, AXI_CST);
		iounmap(axi_base);
		axi_base = NULL;
		return -ENODEV;
	}

	ret = misc_register(&axi_miscdev);
	if (ret) {
		iounmap(axi_base);
		axi_base = NULL;
		return ret;
	}

	pr_info(DRV_NAME ": loaded, /dev/%s ready\n", DEV_NAME);
	return 0;
}

static void __exit axi_exit(void) {
	misc_deregister(&axi_miscdev);
	if (axi_base) {
		iounmap(axi_base);
		axi_base = NULL;
	}
	pr_info(DRV_NAME ": unloaded\n");
}

module_init(axi_init);
module_exit(axi_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("SCF Lab");
MODULE_DESCRIPTION("AXI4-Lite char driver with ioctl");
