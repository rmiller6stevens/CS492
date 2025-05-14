#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <linux/types.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <pthread.h>

#include "scull.h"

#define CDEV_NAME "/dev/scull"

/* Quantum command line option */
static int g_quantum;

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

static void usage(const char *cmd)
{
	printf("Usage: %s <command>\n"
	       "Commands:\n"
	       "  R          Reset quantum\n"
	       "  S <int>    Set quantum\n"
	       "  T <int>    Tell quantum\n"
	       "  G          Get quantum\n"
	       "  Q          Query quantum\n"
	       "  X <int>    Exchange quantum\n"
	       "  H <int>    Shift quantum\n"
		   "  i          Info\n"
		   "  p          4 Forks Test\n"
		   "  t          Thread Test\n"
	       "  h          Print this message\n",
	       cmd);
}

typedef int cmd_t;
//child code

//Thread job code
static void * job(void *fd){
	struct task_info output;
	int ret; 
	ret = ioctl(*(int*) fd, SCULL_IOCIQUANTUM, &output);
	if(ret == 0){
		printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
		}
	ret = ioctl(*(int *) fd, SCULL_IOCIQUANTUM, &output);
	if(ret == 0){
		printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
		}
	pthread_exit(0);
}



static cmd_t parse_arguments(int argc, const char **argv)
{
	cmd_t cmd;

	if (argc < 2) {
		fprintf(stderr, "%s: Invalid number of arguments\n", argv[0]);
		cmd = -1;
		goto ret;
	}

	/* Parse command and optional int argument */
	cmd = argv[1][0];
	switch (cmd) {
	case 'S':
	case 'T':
	case 'H':
	case 'X':
		if (argc < 3) {
			fprintf(stderr, "%s: Missing quantum\n", argv[0]);
			cmd = -1;
			break;
		}
		g_quantum = atoi(argv[2]);
		break;
	case 'R':
	case 'G':
	case 'Q':
	case 'i':
	case 'p':
	case 't':
	case 'h':
		break;
	default:
		fprintf(stderr, "%s: Invalid command\n", argv[0]);
		cmd = -1;
	}

ret:
	if (cmd < 0 || cmd == 'h') {
		usage(argv[0]);
		exit((cmd == 'h')? EXIT_SUCCESS : EXIT_FAILURE);
	}
	return cmd;
}

static int do_op(int fd, cmd_t cmd)
{
	struct task_info output;
	int ret, q;
	pthread_t *threadArr;
	switch (cmd) {
	case 'R':
		ret = ioctl(fd, SCULL_IOCRESET);
		if (ret == 0)
			printf("Quantum reset\n");
		break;
	case 'Q':
		q = ioctl(fd, SCULL_IOCQQUANTUM);
		printf("Quantum: %d\n", q);
		ret = 0;
		break;
	case 'G':
		ret = ioctl(fd, SCULL_IOCGQUANTUM, &q);
		if (ret == 0)
			printf("Quantum: %d\n", q);
		break;
	case 'T':
		ret = ioctl(fd, SCULL_IOCTQUANTUM, g_quantum);
		if (ret == 0)
			printf("Quantum set\n");
		break;
	case 'S':
		q = g_quantum;
		ret = ioctl(fd, SCULL_IOCSQUANTUM, &q);
		if (ret == 0)
			printf("Quantum set\n");
		break;
	case 'X':
		q = g_quantum;
		ret = ioctl(fd, SCULL_IOCXQUANTUM, &q);
		if (ret == 0)
			printf("Quantum exchanged, old quantum: %d\n", q);
		break;
	case 'H':
		q = ioctl(fd, SCULL_IOCHQUANTUM, g_quantum);
		printf("Quantum shifted, old quantum: %d\n", q);
		ret = 0;
		break;
	case 'i':
		ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
		if(ret == 0){
		printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
		}
		break;
	case 'p':
	{
		pid_t firstChild_pid = fork(); //one child
		if(firstChild_pid != 0){ //parents code
			pid_t secondChild_pid = fork(); //second child
			if(secondChild_pid != 0){
				pid_t thirdChild_pid = fork(); //thid child
				if(thirdChild_pid != 0){
					pid_t fourthChild_pid = fork(); //fourth child
					if(fourthChild_pid == 0){
						//fourth child
								ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
								if(ret == 0){
								printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
								}
								ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
								if(ret == 0){
								printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
								}
								exit(0);
					}
				} else {
					//third child
						ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
							if(ret == 0){
							printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
						}
						ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
							if(ret == 0){
							printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
						}
						exit(0);
				}
			} else {
				//second child
					ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
						if(ret == 0){
						printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
					}
					ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
						if(ret == 0){
						printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
					}
					exit(0);
			}
		} else {
			//first child
			ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
				if(ret == 0){
				printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
			}
			ret = ioctl(fd, SCULL_IOCIQUANTUM, &output);
				if(ret == 0){
				printf("state %ld, cpu %u, prio %d, pid %ld, tgid %ld, nv %lu, niv %lu\n", output.state, output.cpu, output.prio, (long) output.pid, (long) output.tgid, output.nvcsw, output.nivcsw); //TODO
			}
			exit(0);
		}
		int pCount = 4;
		int status;
		ret = 0;
		while(pCount > 0){
			wait(&status);
			pCount --;
		}
		break;
	}
	case 't':{
		threadArr = malloc(4 * sizeof(threadArr));
		for(int i = 0; i < 4; i++){
			pthread_create(&threadArr[i], NULL, job, (void*) &fd);
		}
		for(int j = 0; j < 4; j++){
			pthread_join(threadArr[j], NULL);
		}
		free(threadArr);
		ret = 0;
	break;
		}
	default:
		/* Should never occur */
		abort();
		ret = -1; /* Keep the compiler happy */
	}

	if (ret != 0)
		perror("ioctl");
	return ret;
}

int main(int argc, const char **argv)
{
	int fd, ret;
	cmd_t cmd;

	cmd = parse_arguments(argc, argv);

	fd = open(CDEV_NAME, O_RDONLY);
	if (fd < 0) {
		perror("cdev open");
		return EXIT_FAILURE;
	}

	printf("Device (%s) opened\n", CDEV_NAME);

	ret = do_op(fd, cmd);

	if (close(fd) != 0) {
		perror("cdev close");
		return EXIT_FAILURE;
	}

	printf("Device (%s) closed\n", CDEV_NAME);

	return (ret != 0)? EXIT_FAILURE : EXIT_SUCCESS;
}