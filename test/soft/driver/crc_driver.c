#include <linux/fs.h>
#include <linux/init.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/uaccess.h>
#include <linux/interrupt.h>

#include <linux/sched.h>
#include <linux/poll.h>
#include <linux/wait.h>

#define DRV_NAME "axi_driver"
#define DEV_NAME "CRCSCF"

#define CRC_LW_HPS_FPGA_BASE_ADD 0xFF200000
#define CRC_LW_MAP_SIZE          0x1000

#define CRC_CST 0xBADB100D

#define REG_CST               0x0000
#define REG_TEST              0x0004
#define REG_DATA			  0x0008
#define REG_CRCIN  			  0x000C
#define REG_INIT			  0x0010
#define REG_SIZE			  0x0014
#define REG_XOROUT			  0x0018
#define REG_CRCOUT			  0x001C
#define REG_CTRL_STATUS		  0x0020

#define ST_OUT_READY		  0x0001

#define CRC_IOC_MAGIC 'q'
#define CRC_IOC_GET_CST       _IOR(CRC_IOC_MAGIC, 0, __u32)
#define CRC_IOC_GET_TEST      _IOR(CRC_IOC_MAGIC, 1, __u32)
#define CRC_IOC_SET_TEST      _IOW(CRC_IOC_MAGIC, 2, __u32)
#define CRC_IOC_SET_CRCIN     _IOW(CRC_IOC_MAGIC, 3, __u32)
#define CRC_IOC_SET_INIT      _IOW(CRC_IOC_MAGIC, 4, __u32)
#define CRC_IOC_SET_SIZE      _IOW(CRC_IOC_MAGIC, 5, __u32)
#define CRC_IOC_SET_XOROUT    _IOW(CRC_IOC_MAGIC, 6, __u32)

#define CRC_IO_CHUNK        4


struct crc_priv {
	struct mutex lock;
	void __iomem *regs;
	int irq;
	wait_queue_head_t waitq;
	atomic_t out_ready;          // set in irq_handler, cleared in read()
};

static struct crc_priv g_priv;

static inline u32 crc_reg_read(struct crc_priv *p, u32 reg) {
	return ioread32(p->regs + reg);
}

static inline void crc_reg_write(struct crc_priv *p, u32 reg, u32 val) {
	iowrite32(val, p->regs + reg);
}

// Lecture registre d'état
static u32 crc_status(struct crc_priv *p)
{
	return crc_reg_read(p, REG_CTRL_STATUS);
}

static long crc_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
	struct crc_priv *p = file->private_data;
	u32 val;

	(void)file;

	if (_IOC_TYPE(cmd) != CRC_IOC_MAGIC)
		return -ENOTTY;

	switch (cmd) {
		case CRC_IOC_GET_CST:
			val = crc_reg_read(p, REG_CST);
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case CRC_IOC_GET_TEST:
			val = crc_reg_read(p, REG_TEST);
			if (copy_to_user((u32 __user *)arg, &val, sizeof(val)))
				return -EFAULT;
			return 0;

		case CRC_IOC_SET_TEST:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			crc_reg_write(p, REG_TEST, val);
			return 0;

		case CRC_IOC_SET_CRCIN:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			crc_reg_write(p, REG_CRCIN, val);
			return 0;

		case CRC_IOC_SET_INIT:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			crc_reg_write(p, REG_INIT, val);
			return 0;

		case CRC_IOC_SET_SIZE:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			crc_reg_write(p, REG_SIZE, val);
			return 0;

		case CRC_IOC_SET_XOROUT:
			if (copy_from_user(&val, (u32 __user *)arg, sizeof(val)))
				return -EFAULT;
			crc_reg_write(p, REG_XOROUT, val);
			return 0;

		default:
			return -ENOTTY;
	}
}

static irqreturn_t crc_irq_handler(int irq, void *dev_id)
{
	struct crc_priv *p = dev_id;
	u32 st = crc_status(p);

	if (!(st & ST_OUT_READY))
		return IRQ_NONE;

	atomic_set(&p->out_ready, 1);
	wake_up_interruptible(&p->waitq);
	return IRQ_HANDLED;
}

static ssize_t crc_read(struct file *filp, char __user *buf, size_t count, loff_t *ppos)
{
	struct crc_priv *p = filp->private_data;
	u32 val;
	int ret;

	// IRQ read block
	if (filp->f_flags & O_NONBLOCK) {
	    if (!atomic_read(&p->out_ready))
	        return -EAGAIN;
	} else {
	    ret = wait_event_interruptible(p->waitq, atomic_read(&p->out_ready));
	    if (ret)
	        return ret;
	}
	atomic_set(&p->out_ready, 0);

	if (count < CRC_IO_CHUNK)
		return -EINVAL;

	val = crc_reg_read(p, REG_CRCOUT);
	if (copy_to_user(buf, &val, CRC_IO_CHUNK))
		return -EFAULT;
	return CRC_IO_CHUNK;
}

static ssize_t crc_write(struct file *filp, const char __user *buf, size_t count, loff_t *ppos)
{
	struct crc_priv *p = filp->private_data;
	u32 val;

	if (count != CRC_IO_CHUNK)
		return -EINVAL;
	if (copy_from_user(&val, buf, CRC_IO_CHUNK))
		return -EFAULT;

	crc_reg_write(p, REG_DATA, val);
	return CRC_IO_CHUNK;
}

static const struct file_operations crc_fops = {
	.owner = THIS_MODULE,
	.unlocked_ioctl = crc_ioctl,
    .read           = crc_read,
	.write			= crc_write,
};

static struct miscdevice crc_miscdev = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = DEV_NAME,
	.fops = &crc_fops,
	.mode = 0666,
};

static int __init crc_init(void) {
	int ret;
	u32 cst;

	g_priv.regs = ioremap(CRC_LW_HPS_FPGA_BASE_ADD, CRC_LW_MAP_SIZE);
	if (!g_priv.regs)
		return -ENOMEM;

	cst = crc_reg_read(&g_priv, REG_CST);
	if (cst != CRC_CST) {
		pr_err(DRV_NAME ": invalid CST 0x%08x (expected 0x%08x)\n",
		       cst, CRC_CST);
		iounmap(g_priv.regs);
		return -ENODEV;
	}

	// IRQ fixe pour ne pas devoir changer le DT
	g_priv.irq = 40;
	ret = request_irq(g_priv.irq, crc_irq_handler, IRQF_SHARED,
			  DEV_NAME, &g_priv);
	if (ret) {
		pr_err(DRV_NAME ": request_irq %d failed (%d)\n", g_priv.irq, ret);
		iounmap(g_priv.regs);
		return ret;
	}

	ret = misc_register(&crc_miscdev);
	if (ret) {
		iounmap(g_priv.regs);
		return ret;
	}

	pr_info(DRV_NAME ": loaded, /dev/%s ready\n", DEV_NAME);
	return 0;
}

static void __exit crc_exit(void) {

	if (g_priv.irq > 0)
		free_irq(g_priv.irq, &g_priv);

	misc_deregister(&crc_miscdev);
	if (g_priv.regs) {
		iounmap(g_priv.regs);
		g_priv.regs = NULL;
	}

	pr_info(DRV_NAME ": unloaded\n");
}

module_init(crc_init);
module_exit(crc_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("SCF TE2");
MODULE_DESCRIPTION("CRC FPGA driver");
