/*
 * scull.c -- the bare scull char module
 *
 * Copyright (C) 2001 Alessandro Rubini and Jonathan Corbet
 * Copyright (C) 2001 O'Reilly & Associates
 *
 * The source code in this file can be freely used, adapted,
 * and redistributed in source or binary form, so long as an
 * acknowledgment appears in derived source files.  The citation
 * should list that the code comes from the book "Linux Device
 * Drivers" by Alessandro Rubini and Jonathan Corbet, published
 * by O'Reilly & Associates.   No warranty is attached;
 * we cannot take responsibility for errors or fitness for use.
 *
 */

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/init.h>

#include <linux/kernel.h>	/* printk() */
#include <linux/slab.h>		/* kmalloc() */
#include <linux/fs.h>		/* everything... */
#include <linux/errno.h>	/* error codes */
#include <linux/types.h>	/* size_t */
#include <linux/cdev.h>
#include <linux/mutex.h>
#include <linux/list.h>

#include <linux/uaccess.h>	/* copy_*_user */

#include "scull.h"		/* local definitions */

/*
 * Our parameters which can be set at load time.
 */

static int scull_major =   SCULL_MAJOR;
static int scull_minor =   0;
static int scull_quantum = SCULL_QUANTUM;

module_param(scull_major, int, S_IRUGO);
module_param(scull_minor, int, S_IRUGO);
module_param(scull_quantum, int, S_IRUGO);

static DEFINE_MUTEX(mLock);

MODULE_AUTHOR("rmiller6");
MODULE_LICENSE("Dual BSD/GPL");

//define the struct
struct task_info {
		long state; //Task State (0 means running)
		unsigned int cpu; //current
		int prio; //Priority
		pid_t pid; // PID
		pid_t tgid; //TID
		unsigned long nvcsw; // Number of voluntary context switches
		unsigned long nivcsw; // Number of involuntary context switches
		};

struct node {
    pid_t pid;
    pid_t tgid;
    struct node *next;
	};
	//initialize the linked list
	static struct node *head;

static struct cdev scull_cdev;		/* Char device structure */

/*
 * Open and close
 */

static int scull_open(struct inode *inode, struct file *filp)
{
	printk(KERN_INFO "scull open\n");
	return 0;          /* success */
}

static int scull_release(struct inode *inode, struct file *filp)
{
	printk(KERN_INFO "scull close\n");
	return 0;
}

/*
 * The ioctl() implementation
 */

static long scull_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	int err = 0, tmp;
	int retval = 0;
	struct task_info retval2; //get and put user are only for simple variables, cannot use for this
    
	/*
	 * extract the type and number bitfields, and don't decode
	 * wrong cmds: return ENOTTY (inappropriate ioctl) before access_ok()
	 */
	if (_IOC_TYPE(cmd) != SCULL_IOC_MAGIC) return -ENOTTY;
	if (_IOC_NR(cmd) > SCULL_IOC_MAXNR) return -ENOTTY;

	err = !access_ok((void __user *)arg, _IOC_SIZE(cmd));
	if (err) return -EFAULT;

	switch(cmd) {

	case SCULL_IOCRESET:
		scull_quantum = SCULL_QUANTUM;
		break;
        
	case SCULL_IOCSQUANTUM: /* Set: arg points to the value */
		retval = __get_user(scull_quantum, (int __user *)arg);
		break;

	case SCULL_IOCTQUANTUM: /* Tell: arg is the value */
		scull_quantum = arg;
		break;

	case SCULL_IOCGQUANTUM: /* Get: arg is pointer to result */
		retval = __put_user(scull_quantum, (int __user *)arg);
		break;

	case SCULL_IOCQQUANTUM: /* Query: return it (it's positive) */
		return scull_quantum;

	case SCULL_IOCXQUANTUM: /* eXchange: use arg as pointer */
		tmp = scull_quantum;
		retval = __get_user(scull_quantum, (int __user *)arg);
		if (retval == 0)
			retval = __put_user(tmp, (int __user *)arg);
		break;

	case SCULL_IOCHQUANTUM: /* sHift: like Tell + Query */
		tmp = scull_quantum;
		scull_quantum = arg;
		return tmp;

	case SCULL_IOCIQUANTUM : {/*TODO*/
		//get and put user are only for simple variables, cannot use for this
		int check;
		struct node *iterator;
		retval2.state = current->state;
		retval2.cpu = current->cpu;
		retval2.prio = current->prio;
		retval2.pid = current->pid;
		retval2.tgid = current->tgid;
		retval2.nvcsw = current->nvcsw;
		retval2.nivcsw = current->nivcsw;
		mutex_lock(&mLock);
		check =0;
		iterator = head;
		while(iterator != NULL){
			if(iterator->pid == current->pid && iterator->tgid == current->tgid){
				check = 1;
			}
			iterator = iterator->next; 
		}
		if(!(check)){ //task is not found
			struct node *temp_node = (struct node*) kmalloc(sizeof(struct node), GFP_KERNEL);
			if(!(temp_node)){
				printk(KERN_ERR "Failed to allocate memory for node");
				mutex_unlock(&mLock); //cannot forget or else deadlock
				return -ENOMEM;
			}
			//set fields
		temp_node->pid = current->pid;
		temp_node->tgid = current->tgid;
		temp_node->next = NULL;
			if(head == NULL){
				head = temp_node;
			} else {
				iterator = head;
				while(iterator->next != NULL){
					iterator = iterator->next;
				}
				iterator->next = temp_node;
			}
		}
		mutex_unlock(&mLock);
		retval = copy_to_user((struct task_info __user *)arg, &retval2, sizeof(struct task_info));
		break;
	}

	default:  /* redundant, as cmd was checked against MAXNR */
		return -ENOTTY;
	}
	return retval;
}

struct file_operations scull_fops = {
	.owner =    THIS_MODULE,
	.unlocked_ioctl = scull_ioctl,
	.open =     scull_open,
	.release =  scull_release,
};

/*
 * Finally, the module stuff
 */

/*
 * The cleanup function is used to handle initialization failures as well.
 * Thefore, it must be careful to work correctly even if some of the items
 * have not been initialized
 */
void scull_cleanup_module(void)
{
	dev_t devno = MKDEV(scull_major, scull_minor);
	struct node *iterator, *temp_ptr;
	int pCount = 1;
	//iterate through the linked list and remove the elements
	iterator = head;
	while(iterator != NULL){
		printk(KERN_INFO "Task %d: PID %d, TGID %d\n", pCount, iterator->pid, iterator->tgid);
		pCount ++;
		temp_ptr = iterator->next;
        kfree(iterator);
		iterator = temp_ptr;
	}
	/* Get rid of the char dev entry */
	cdev_del(&scull_cdev);

	/* cleanup_module is never called if registering failed */
	unregister_chrdev_region(devno, 1);
}

int scull_init_module(void)
{
	int result;
	dev_t dev = 0;

	/*
	 * Get a range of minor numbers to work with, asking for a dynamic
	 * major unless directed otherwise at load time.
	 */
	if (scull_major) {
		dev = MKDEV(scull_major, scull_minor);
		result = register_chrdev_region(dev, 1, "scull");
	} else {
		result = alloc_chrdev_region(&dev, scull_minor, 1, "scull");
		scull_major = MAJOR(dev);
	}
	if (result < 0) {
		printk(KERN_WARNING "scull: can't get major %d\n", scull_major);
		return result;
	}

	cdev_init(&scull_cdev, &scull_fops);
	scull_cdev.owner = THIS_MODULE;
	result = cdev_add (&scull_cdev, dev, 1);
	/* Fail gracefully if need be */
	if (result) {
		printk(KERN_NOTICE "Error %d adding scull character device", result);
		goto fail;
	}

	return 0; /* succeed */

  fail:
	scull_cleanup_module();
	return result;
}

module_init(scull_init_module);
module_exit(scull_cleanup_module);