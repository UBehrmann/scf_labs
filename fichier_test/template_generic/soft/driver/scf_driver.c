/*
 * Generic SCF exam driver — labo7 miscdevice pattern.
 *
 * TODO at exam start (from subject sheet):
 *   1. DEV_NAME          → e.g. "FIRSCF", "convol", ...
 *   2. AXI_CONSTANT      → match FPGA constant register
 *   3. REG_* indices     → match your address map
 *   4. ioctl handlers    → reset, set params, ...
 *   5. IRQ               → request_irq() if spec requires it
 *   6. DT probe          → platform_driver + compatible OR fixed ioremap
 */
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>

#include "../axi_regs.h"
#include "../ioctl_cmds.h"

#define DRV_NAME "scf_driver"
#define DEV_NAME "scf_ip"   /* TODO: exam device name → /dev/scf_ip */

struct scf_priv {
	struct mutex lock;
	void __iomem *regs;
	int irq;
};

static struct scf_priv g_priv;

static inline u32 scf_reg_read(struct scf_priv *p, u32 idx)
{
	return ioread32(p->regs + (idx * 4));
}

static inline void scf_reg_write(struct scf_priv *p, u32 idx, u32 val)
{
	iowrite32(val, p->regs + (idx * 4));
}

static u32 scf_status(struct scf_priv *p)
{
	return scf_reg_read(p, REG_CTRL_STATUS);
}

/* TODO: IRQ handler if exam requires interrupt on output ready */
static irqreturn_t scf_irq_handler(int irq, void *dev_id)
{
	struct scf_priv *p = dev_id;

	(void)p;
	/* wake poll / kill_fasync / complete() */
	return IRQ_HANDLED;
}

static int scf_open(struct inode *inode, struct file *filp)
{
	if (!mutex_trylock(&g_priv.lock))
		return -EBUSY;
	filp->private_data = &g_priv;
	return 0;
}

static int scf_release(struct inode *inode, struct file *filp)
{
	mutex_unlock(&g_priv.lock);
	filp->private_data = NULL;
	return 0;
}

static ssize_t scf_read(struct file *filp, char __user *buf, size_t count, loff_t *ppos)
{
	struct scf_priv *p = filp->private_data;
	u32 val;

	/* TODO: block until ST_OUT_READY, or return -EAGAIN */
	if (count < AXI_IO_CHUNK)
		return -EINVAL;

	val = scf_reg_read(p, REG_DATA_OUT);
	if (copy_to_user(buf, &val, AXI_IO_CHUNK))
		return -EFAULT;
	return AXI_IO_CHUNK;
}

static ssize_t scf_write(struct file *filp, const char __user *buf, size_t count, loff_t *ppos)
{
	struct scf_priv *p = filp->private_data;
	u32 val;

	if (count != AXI_IO_CHUNK)
		return -EINVAL;
	if (copy_from_user(&val, buf, AXI_IO_CHUNK))
		return -EFAULT;

	scf_reg_write(p, REG_DATA_IN, val);
	return AXI_IO_CHUNK;
}

static long scf_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	struct scf_priv *p = filp->private_data;
	struct scf_params params;
	u32 st;

	switch (cmd) {
	case IOCTL_SCF_RESET:
		scf_reg_write(p, REG_CTRL_STATUS, CMD_RESET);
		return 0;

	case IOCTL_SCF_GET_STATUS:
		st = scf_status(p);
		if (copy_to_user((u32 __user *)arg, &st, sizeof(st)))
			return -EFAULT;
		return 0;

	case IOCTL_SCF_SET_PARAMS:
		if (copy_from_user(&params, (struct scf_params __user *)arg, sizeof(params)))
			return -EFAULT;
		scf_reg_write(p, REG_PARAM_0, params.p0);
		scf_reg_write(p, REG_PARAM_1, params.p1);
		scf_reg_write(p, REG_PARAM_2, params.p2);
		return 0;

	default:
		return -ENOTTY;
	}
}

static const struct file_operations scf_fops = {
	.owner          = THIS_MODULE,
	.open           = scf_open,
	.release        = scf_release,
	.read           = scf_read,
	.write          = scf_write,
	.unlocked_ioctl = scf_ioctl,
};

static struct miscdevice scf_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name  = DEV_NAME,
	.fops  = &scf_fops,
	.mode  = 0666,
};

static int scf_hw_selftest(struct scf_priv *p)
{
	u32 cst, test = 0x00C0FFEE;

	cst = scf_reg_read(p, REG_CONSTANT);
	if (cst != AXI_CONSTANT) {
		pr_err(DRV_NAME ": CST 0x%08x != 0x%08x\n", cst, AXI_CONSTANT);
		return -ENODEV;
	}

	scf_reg_write(p, REG_TEST, test);
	if (scf_reg_read(p, REG_TEST) != test) {
		pr_err(DRV_NAME ": test register R/W failed\n");
		return -ENODEV;
	}
	return 0;
}

static int __init scf_init(void)
{
	int ret;

	mutex_init(&g_priv.lock);

	/* TODO: replace with platform_driver probe + devm_ioremap_resource */
	g_priv.regs = ioremap(AXI_HPS_FPGA_BASE, AXI_MAP_SIZE);
	if (!g_priv.regs)
		return -ENOMEM;

	ret = scf_hw_selftest(&g_priv);
	if (ret) {
		iounmap(g_priv.regs);
		return ret;
	}

	/* TODO: g_priv.irq = ...; request_irq(...) */

	ret = misc_register(&scf_misc);
	if (ret) {
		iounmap(g_priv.regs);
		return ret;
	}

	pr_info(DRV_NAME ": /dev/%s @ 0x%08x\n", DEV_NAME, AXI_HPS_FPGA_BASE);
	return 0;
}

static void __exit scf_exit(void)
{
	if (g_priv.irq > 0)
		free_irq(g_priv.irq, &g_priv);
	misc_deregister(&scf_misc);
	if (g_priv.regs) {
		iounmap(g_priv.regs);
		g_priv.regs = NULL;
	}
}

module_init(scf_init);
module_exit(scf_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Generic SCF exam IP driver");
