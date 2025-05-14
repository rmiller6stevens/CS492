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
#include <linux/mutex.h>  /*This is for blocking*/
#include <linux/list.h>

#include <linux/uaccess.h>	/* copy_*_user */

#include "scull.h"		/* local definitions */

/*
 * Our parameters which can be set at load time.
 */

static int scull_major =   SCULL_MAJOR;
static int scull_minor =   0;
static int scull_fifo_elemsz = SCULL_FIFO_ELEMSZ_DEFAULT; /* ELEMSZ */
static int scull_fifo_size   = SCULL_FIFO_SIZE_DEFAULT;   /* N      */

static char* circleBuffer;
static char* max_offset;//to make it circular
static char* start;
static char* end;

module_param(scull_major, int, S_IRUGO);
module_param(scull_minor, int, S_IRUGO);
module_param(scull_fifo_size, int, S_IRUGO);
module_param(scull_fifo_elemsz, int, S_IRUGO);

static DEFINE_MUTEX(mLock);
static struct semaphore FULL;
static struct semaphore EMPTY;

//two semaphores here

MODULE_AUTHOR("rmiller6");
MODULE_LICENSE("Dual BSD/GPL");

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
 * Read and Write
 */
static ssize_t scull_read(struct file *filp, char __user *buf, size_t count, loff_t *f_pos) 
{
	/* TODO: implement this function */
	int returned = 0;  //counts bytes returned
	int check = 0;
	int len = *(int*) start;
		if(down_interruptible(&FULL)){
			return -1;
		} //consume one
		if(mutex_lock_interruptible(&mLock)){
			up(&FULL);
			return -1;
		} //lock while editing buffer
		if(count < len){
			check = copy_to_user(buf, start + sizeof(int), count);
			if(check){
					printk(KERN_ERR "Failed to copy from user");
					mutex_unlock(&mLock);
					up(&FULL);
					return -1;
				}
				returned = count;
		} else {
			check = copy_to_user(buf, start + sizeof(int), len);
			returned = scull_fifo_elemsz;
			if(check){
					printk(KERN_ERR "Failed to copy from user");
					mutex_unlock(&mLock);
					up(&FULL);
					return -1;
				}
		}

		start = start + (sizeof(int) + scull_fifo_elemsz);
		if(start == max_offset){
			start = circleBuffer; //reset to the original head of the list
		}
		mutex_unlock(&mLock);
		up(&EMPTY); //new empty space

	printk(KERN_INFO "scull read\n");
	return returned;
}


static ssize_t scull_write(struct file *filp, const char __user *buf, size_t count, loff_t *f_pos)
{
	/* TODO: implement this function */
	int returned = 0;
	int check = 0;
	int *store_len = (int*) end;
	// if((end + (sizeof(int) + scull_fifo_elemsz)) == start){
		//buffer is full so wait
		if(down_interruptible(&EMPTY)){
			return -1;
		} //take an empty slot
		if(mutex_lock_interruptible(&mLock)){
			up(&EMPTY);
			return -1;
		}
		end = end + sizeof(int);
		if(count > scull_fifo_elemsz){
			*store_len = scull_fifo_elemsz;
			check = copy_from_user(end, buf, scull_fifo_elemsz);
			returned = scull_fifo_elemsz;
			if(check){
				printk(KERN_ERR "Failed to copy from user");
				mutex_unlock(&mLock);
				up(&EMPTY);
				return -1;
			}
		} else {
			*store_len = count;
			check = copy_from_user(end, buf, count);
			returned = count;
			if(check){
				printk(KERN_ERR "Failed to copy from user");
				mutex_unlock(&mLock);
				up(&EMPTY);
				return -1;
			}
		}
		end = end + scull_fifo_elemsz; //added sizeof(int) before
		if(end  == max_offset){ //move end first so that we can write a new element in
			end = circleBuffer;
		}
		mutex_unlock(&mLock);
		up(&FULL); //add a full counter
	printk(KERN_INFO "scull write\n");
	return returned;
}

/*
 * The ioctl() implementation
 */
static long scull_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{

	int err = 0;
	int retval = 0;
    
	/*
	 * extract the type and number bitfields, and don't decode
	 * wrong cmds: return ENOTTY (inappropriate ioctl) before access_ok()
	 */
	if (_IOC_TYPE(cmd) != SCULL_IOC_MAGIC) return -ENOTTY;
	if (_IOC_NR(cmd) > SCULL_IOC_MAXNR) return -ENOTTY;

	err = !access_ok((void __user *)arg, _IOC_SIZE(cmd));
	if (err) return -EFAULT;

	switch(cmd) {
	case SCULL_IOCGETELEMSZ:
		return scull_fifo_elemsz;

	default:  /* redundant, as cmd was checked against MAXNR */
		return -ENOTTY;
	}
	return retval;

}

struct file_operations scull_fops = {
	.owner 		= THIS_MODULE,
	.unlocked_ioctl = scull_ioctl,
	.open 		= scull_open,
	.release	= scull_release,
	.read 		= scull_read,
	.write 		= scull_write,
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

	/* TODONE: free FIFO safely here */
	kfree(circleBuffer);

	// while(iterator !== NULL){
	// 	temp_ptr = iterator;
	// 	kfree(iterator);
	// 	if(((sizeof(int) + scull_fifo_elemsz) * scull_fifo_size) > max_offset){ //circular
	// 	temp_ptr = circleBuffer;
	// 		} else {
	// 	*temp_ptr+= (sizeof(int) + scull_fifo_elemsz); //iterate by adding offset
	// 	}
	// 	iterator = temp_ptr;
	// }
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

	/* TODONE: allocate FIFO correctly here */
	circleBuffer = kmalloc((scull_fifo_elemsz + sizeof(int)) * scull_fifo_size, GFP_KERNEL); //sizeof int to account for its len
	if(!(circleBuffer)){
		printk(KERN_ERR "Failed to allocate memory for queue");
		goto fail; //copying what I see above if this fails
	}
	max_offset = circleBuffer + ((sizeof(int) + scull_fifo_elemsz) * scull_fifo_size); 
	start = circleBuffer;
	end = start;

	//init the semaphores
	sema_init(&FULL, 0);
	sema_init(&EMPTY, scull_fifo_size);

	printk(KERN_INFO "scull: FIFO SIZE=%u, ELEMSZ=%u\n", scull_fifo_size, scull_fifo_elemsz);

	return 0; /* succeed */

  fail:
	scull_cleanup_module();
	return result;
}

module_init(scull_init_module);
module_exit(scull_cleanup_module);
