#include <linux/io.h>
#include <linux/of.h>
#include <linux/platform_device.h>

#define EXPECTED_VALUE 0xBADB100D

static int example_probe(struct platform_device *pdev)
{
	void *base_addr;
	struct resource *mem_info;
	uint32_t constant_value;

	mem_info = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	if (unlikely(!mem_info)) {
		dev_err(&pdev->dev, "Failed to get memory resource from device "
				    "tree!\n");
		return -EINVAL;
	}

	dev_info(&pdev->dev, "Got address from device tree 0x%X - 0x%X\n",
		 mem_info->start, resource_size(mem_info));

	base_addr = devm_ioremap(&pdev->dev, mem_info->start,
				 resource_size(mem_info));
	if (base_addr == NULL) {
		dev_err(&pdev->dev, "Couldn't ioremap given address\n");
		return -EFAULT;
	}

	/* Constant is at offset 0 */
	constant_value = ioread32((uint32_t *)base_addr);

	if (constant_value != EXPECTED_VALUE) {
		dev_err(&pdev->dev,
			"Got bad constant value 0x%X, expected 0x%X\n",
			constant_value, EXPECTED_VALUE);
		return -EINVAL;
	}

	dev_info(&pdev->dev, "Got correct constant value 0x%X\n",
		 constant_value);

	return 0;
}

static void example_remove(struct platform_device *pdev)
{
	/* Resource are free up by devm_... */
}

static const struct of_device_id example_id[] = {
	{ .compatible = "example" },
	{ /* END */ },
};
MODULE_DEVICE_TABLE(of, example_id);

static struct platform_driver example = {
	.driver = {
		.name = "example",
		.owner = THIS_MODULE,
		.of_match_table = of_match_ptr(example_id),
	},
	.probe = example_probe,
	.remove = example_remove,
};
module_platform_driver(example);

MODULE_DESCRIPTION("Simple example driver for DTSO");
MODULE_LICENSE("GPL");
MODULE_AUTHOR("ReDS");
