#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "../axi.h"
#include "../common_constants.h"

#define DRV_NAME "convol_driver"
#define DEV_NAME "convol"

struct convol_priv {
	struct mutex lock;
	void __iomem *regs;
};

static struct convol_priv g_priv;

static inline u32 reg_read(struct convol_priv *p, u32 idx)
{
	return ioread32(p->regs + (idx * 4));
}

static inline void reg_write(struct convol_priv *p, u32 idx, u32 val)
{
	iowrite32(val, p->regs + (idx * 4));
}

static u32 reg_status(struct convol_priv *p)
{
	return reg_read(p, REG_STATUS_CONTROL) & 0x3FFu;
}

static int convol_open(struct inode *inode, struct file *filp)
{
	if (!mutex_trylock(&g_priv.lock))
		return -EBUSY;
	filp->private_data = &g_priv;
	return 0;
}

static int convol_release(struct inode *inode, struct file *filp)
{
	mutex_unlock(&g_priv.lock);
	filp->private_data = NULL;
	return 0;
}

static ssize_t convol_read(struct file *filp, char __user *buf, size_t count, loff_t *ppos)
{
	struct convol_priv *p = filp->private_data;
	u32 val;

	if (count < sizeof(val))
		return -EINVAL;

	val = reg_read(p, REG_DATA_OUT);
	if (copy_to_user(buf, &val, sizeof(val)))
		return -EFAULT;
	return sizeof(val);
}

static ssize_t convol_write(struct file *filp, const char __user *buf, size_t count, loff_t *ppos)
{
	struct convol_priv *p = filp->private_data;
	u32 val;

	if (count != sizeof(val))
		return -EINVAL;
	if (copy_from_user(&val, buf, sizeof(val)))
		return -EFAULT;

	reg_write(p, REG_DATA_IN, val);
	return sizeof(val);
}

static long convol_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	struct convol_priv *p = filp->private_data;

	if (cmd == 0 && arg == CMD_RST) {
		reg_write(p, REG_STATUS_CONTROL, BITS_CMD_RST);
		return 0;
	}
	if (cmd == 1) {
		u32 st = reg_status(p);
		if (copy_to_user((u32 __user *)arg, &st, sizeof(st)))
			return -EFAULT;
		return 0;
	}
	if (cmd == 2) {
		u32 width;
		if (copy_from_user(&width, (u32 __user *)arg, sizeof(width)))
			return -EFAULT;
		reg_write(p, REG_WIDTH, width);
		return 0;
	}
	return -ENOTTY;
}

static const struct file_operations convol_fops = {
	.owner          = THIS_MODULE,
	.open           = convol_open,
	.release        = convol_release,
	.read           = convol_read,
	.write          = convol_write,
	.unlocked_ioctl = convol_ioctl,
};

static struct miscdevice convol_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name  = DEV_NAME,
	.fops  = &convol_fops,
	.mode  = 0666,
};

static int program_kernel_regs(struct convol_priv *p, const int8_t *ker, size_t len)
{
	u32 col[3];
	size_t i;

	if (len < 9)
		return -EINVAL;

	for (i = 0; i < 3; i++) {
		col[i] = (u8)ker[i * 3 + 0] |
			 ((u32)(u8)ker[i * 3 + 1] << 8) |
			 ((u32)(u8)ker[i * 3 + 2] << 16);
		reg_write(p, REG_KERN_COL_0 + i, col[i]);
	}
	return 0;
}

static int __init convol_init(void)
{
	u32 cst, test_wr = 0x600DD060;
	int ret;
	static const int8_t default_ker[9] = {
		-1, 0, -1, 0, 4, 0, -1, 0, -1
	};

	mutex_init(&g_priv.lock);
	g_priv.regs = ioremap(AXI_HPS_FPGA_BASE_ADD, 0x1000);
	if (!g_priv.regs)
		return -ENOMEM;

	cst = reg_read(&g_priv, REG_CONSTANT);
	if (cst != CONSTANT_VALUE) {
		pr_err(DRV_NAME ": bad CST 0x%08x (want 0x%08x)\n", cst, CONSTANT_VALUE);
		iounmap(g_priv.regs);
		return -ENODEV;
	}

	reg_write(&g_priv, REG_TEST, test_wr);
	if (reg_read(&g_priv, REG_TEST) != test_wr) {
		pr_err(DRV_NAME ": test reg R/W failed\n");
		iounmap(g_priv.regs);
		return -ENODEV;
	}

	if (program_kernel_regs(&g_priv, default_ker, sizeof(default_ker)) < 0) {
		iounmap(g_priv.regs);
		return -EINVAL;
	}

	ret = misc_register(&convol_misc);
	if (ret) {
		iounmap(g_priv.regs);
		return ret;
	}

	pr_info(DRV_NAME ": /dev/%s ready (labo7 base 0x%08x)\n",
		DEV_NAME, AXI_HPS_FPGA_BASE_ADD);
	return 0;
}

static void __exit convol_exit(void)
{
	misc_deregister(&convol_misc);
	if (g_priv.regs) {
		iounmap(g_priv.regs);
		g_priv.regs = NULL;
	}
}

module_init(convol_init);
module_exit(convol_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("SCF exam reference convolver driver");
