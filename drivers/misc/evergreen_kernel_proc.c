/*
* Initial proc for evergreen kernel
* by Romi Yusnandar
* Create some file ini /proc/evergreen-kernel
*/

#include <linux/module.h>
#include <linux/proc_fs.h>
#include <linux/uaccess.h>
#include <linux/seq_file.h>

#define PROC_FILENAME "evergreen-kernel"
#define KERNEL_FLAG "evergreen_kernel_verified"

static struct proc_dir_entry *evergreen_entry;

static ssize_t evergreen_read(struct file *file, char __user *buf, size_t count, loff_t *ppos)
{
    const char *kernel_flag = KERNEL_FLAG;
    size_t len = strlen(kernel_flag);
    return simple_read_from_buffer(buf, count, ppos, kernel_flag, len);
}

static const struct file_operations evergreen_ops = {
    .read = evergreen_read,
};

static int __init evergreen_kernel_init(void)
{
    evergreen_entry = proc_create(PROC_FILENAME, 0444, NULL, &evergreen_ops);
    if (!evergreen_entry)
        return -ENOMEM;
    return 0;
}

static void __exit evergreen_kernel_exit(void)
{
    proc_remove(evergreen_entry);
}

module_init(evergreen_kernel_init);
module_exit(evergreen_kernel_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Romi Yusnandar");
MODULE_DESCRIPTION("Evergreen Kernel Verification Module");