#include <linux/syscalls.h>
#include <linux/kernel.h>
#include <linux/export.h>
#include <linux/uaccess.h>
#include <linux/compat.h>

SYSCALL_DEFINE1(rmiller6_syscall, char *, str)
{
char buffer[32];
long i = 0;
long count = 0;
	if(str == NULL){
	return -1;
	}
	if(strlen(str) + 1 > 32){
	return -1;
	}
if(copy_from_user(buffer, str, sizeof(buffer)) != 0){
	return -1;
	}
printk(KERN_ALERT "before: %s\n", buffer);
for(i = 0; i< sizeof(buffer) - 1; i++){
	if(buffer[i] == 'a' || buffer[i] == 'e' || buffer[i] == 'i' || buffer[i] == 'o' || buffer[i] == 'u' || buffer[i] == 'y'){
	count ++;
	buffer[i] = 'R';
	}
}
printk(KERN_ALERT "after: %s\n", buffer);
if(copy_to_user(str, buffer, sizeof(buffer))!= 0){
	return -1;
	}
return count;
}
