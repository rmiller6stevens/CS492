#include <linux/module.h>
#include <linux/init.h>

static int hello_init(void)
{
	printk(KERN_ALERT "Hello World from Robert Miller(rmiller6)\n");
	return 0;
}

static void hello_exit(void){
	printk(KERN_ALERT "Task \"%s\" with pid %i has been unloaded.\n", current->comm, current->pid);
}
module_init(hello_init);
module_exit(hello_exit);
MODULE_LICENSE("Dual BSD/GPL");

