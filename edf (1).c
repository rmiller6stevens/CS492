/******************************************************************************* 
     * Filename    : edf.c 
     * Author      : Robert Miller
     * Date        : 3/6/2023
     * Description : Earliest Deadline First Scheduling Algorithm 
     * Pledge      : I pledge my honor that I have abided by the Stevens Honor System
     ******************************************************************************/ 
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include <limits.h>

    struct Processes {
        int pid;
        int CPU_Time;
        int period;
        int deadline;
        int remaining_Time;
        int preempted;
        int age;
    };
    int isEqual(struct Processes *a, struct Processes *b){
        if(a->pid != b->pid || a->CPU_Time != b->CPU_Time || a->period != b->period || a->deadline != b->deadline || a->remaining_Time != b->remaining_Time || a-> preempted != b-> preempted || a->age != b-> age){
            return 0;
        }
        return 1;
    }

    void swap(struct Processes *a, struct Processes *b){ //simple swap function
        struct Processes temp = *a;
        *a = *b;
        *b = temp;
    }

    void deadline_Sort(struct Processes process[], int num_proc){ //sorts array by deadline, main function handles by array[0], sorry its not insertion sort!
        for(int j = 0; j < num_proc -1; j++){
            for(int i = 0; i < num_proc - j - 1; i++){ //it is not num_proc - i because it would unorder the "queue"
                if(process[i].deadline > process[i + 1].deadline){ 
                    swap(&process[i], &process[i+1]);  
                }
                if(process[i].deadline == process[i + 1].deadline){ //same deadline, check age
                   if(process[i].age > process[i+1].age){
                        swap(&process[i], &process[i+1]);  
                    }
                    if(process[i].age == process[i+ 1].age){
                        if(process[i].pid > process[i+1].pid){
                            swap(&process[i], &process[i+1]);  
                        }
                    }
                }
            }
        }
    }

    void removeElement(struct Processes schedule[], int *cur_size){
        for(int i = 0; i < *cur_size -1; i++){
            schedule[i] = schedule[i + 1]; //"removes" the first element of the array
        }
        *cur_size = *cur_size - 1;
    }

    void printSchedule(struct Processes schedule[], struct Processes process[], int num_proc, int *cur_size, int current_Time){ //just prints elements of schedule
        printf("%d: processes:", current_Time);
        int min_Age = 0; //The age here is so that I print everything in the order it is meant to be in, from my understanding the queue's deadline changes when a new period is reached.
        int max_Age = current_Time; 
        while(min_Age <= max_Age){
        for(int j = 0; j < num_proc; j++){
            for(int i = 0; i < *cur_size; i++){
                if(schedule[i].pid == process[j].pid && schedule[i].age == min_Age){
                    printf(" %d (%d ms)", schedule[i].pid, schedule[i].remaining_Time);
                    }
                }
            }
            min_Age++;
        }
        printf("\n");
    }


    void setPreempt(struct Processes schedule[], struct Processes *wasRunning, int* cur_size, int current_Time){
        for(int i = 0; i < *cur_size; i++){
            if(isEqual(&schedule[i], wasRunning)){
                schedule[i].preempted = current_Time;
            }
        }
    }

    int check_Deadlines(struct Processes process[], struct Processes *schedule[], struct Processes *running, int num_proc, int *cur_size, int current_Time, int *procs_created, int* max_Size, int* waited){
        int original_size = *cur_size;
        struct Processes temp = *running;
        struct Processes *wasRunning = &temp;
        for(int i = 0; i < num_proc; i++){
            if(current_Time % process[i].period == 0){
                for(int j = 0; j < *cur_size; j++){
                    if((*schedule)[j].pid == process[i].pid && current_Time == (*schedule)[j].deadline){ //checking schedule for if a process missed its deadline
                            printf("%d: process %d missed deadline (%d ms left)\n", current_Time, (*schedule)[j].pid, (*schedule)[j].remaining_Time);
                            (*schedule)[j].deadline = current_Time + (*schedule)[j].period;
                        if(j == 0){
                            wasRunning->deadline = current_Time + (*schedule)[j].period;
                        }
                    }
                }
                    if(*cur_size == *max_Size){ //if size is at its max
                        // struct Processes *new_schedule;
                        *max_Size = *max_Size *2;
                        //malloc new
                        struct Processes* new_schedule =  malloc(*max_Size * sizeof(struct Processes)); //dynamically double it
                        // //copy elements
                        for(int i = 0; i < *cur_size ; i++){
                            new_schedule[i] = (*schedule)[i];
                        }
                        // //free scheudle
                        free(*schedule);
                        //reset pointer?
                        *schedule = new_schedule;
                        if(schedule == NULL){
                            printf("Failed to reallocate\n");
                            return -1;
                        }
                        // schedule = new_schedule;
                    } 
                    //adding new process to schedule
                    (*schedule)[*cur_size] = process[i]; //last element of schedule is set to new process
                    (*schedule)[*cur_size].deadline = current_Time + process[i].period;
                    (*schedule)[*cur_size].age = current_Time; //new age
                    *cur_size = *cur_size + 1;
                    *procs_created = *procs_created + 1;
            }
        }
        if(*cur_size > 0 && (original_size != *cur_size || running->pid == 0)){ 
            if(running->pid != 0){ //something may be preempted!
                printSchedule(*schedule, process, num_proc, cur_size, current_Time);
                deadline_Sort(*schedule, *cur_size);
                *running = (*schedule)[0];
                if(!isEqual(running, wasRunning)){
                    printf("%d: process %d preempted!\n", current_Time, wasRunning->pid);
                    printf("%d: process %d starts\n", current_Time, running->pid);
                    setPreempt(*schedule, wasRunning, cur_size,  current_Time);
                    if(schedule[0]->preempted == 0){
                        *waited = *waited + current_Time - (*schedule)[0].age;
                    } else {
                        *waited = *waited + current_Time - (*schedule)[0].preempted;
                    }
                }
            } else {
                //Running was null (nothing was running)
                deadline_Sort(*schedule, *cur_size);
                if(original_size != *cur_size) {//if something was added
                printSchedule(*schedule, process, num_proc, cur_size, current_Time);
                }
                *running = (*schedule)[0];
                printf("%d: process %d starts\n", current_Time, running->pid);
                if((*schedule)[0].preempted == 0){
                    *waited = *waited + current_Time - (*schedule)[0].age;
                } else {
                    *waited = *waited + current_Time - (*schedule)[0].preempted;
                }
            }
        } //if cur_size = 0, then there is nothing running AND nothing to run, wait is handled in my check_event
        return 0;
    }

    /*
    Check that the curretly running program is the one from the start of the event check
    if a process ends at the start of the loop, it is not preempted, can do a running = NULL?
    we shall see
    */
    int check_Event(struct Processes process[], struct Processes *schedule[], struct Processes *running, int num_proc, int *cur_size, int current_Time, int *procs_created, int *waited, int* max_Size, int max_Time){//bulk of the functionality
        if(current_Time == 0){
            printSchedule((*schedule), process, num_proc, cur_size, current_Time);
            printf("%d: process %d starts\n", current_Time, running->pid);
            (*schedule)[0].remaining_Time = (*schedule)[0].remaining_Time - 1;
            running->remaining_Time = running->remaining_Time - 1;
        } else {
            if(running-> pid != 0 && running->remaining_Time == 0){ //check if a process finished
                printf("%d: process %d ends\n", current_Time, running->pid);
                if(current_Time == max_Time){
                return 0;
            }
                removeElement(*schedule, cur_size);
                running->pid = 0;
            }
            if(current_Time == max_Time){
                return 0;
            }
            if(check_Deadlines(process, schedule, running, num_proc, cur_size, current_Time, procs_created, max_Size, waited) == -1){
                return -1;
            }
            if(*cur_size != 0){//nothing is running, this is a basic wait
                running->remaining_Time = running->remaining_Time - 1; //must be last line IF there is a running function
                (*schedule)[0].remaining_Time = (*schedule)[0].remaining_Time -1;
            }
        }
        return 0;
    }

    int least_common_multiple(int a, int b){
        int lcm = a;
        while(1){
            if(lcm % a == 0 && lcm % b == 0){
                break;
            }
            lcm += a;
        }
        return lcm;
    }

    int main(){
        int num_proc = 0;
        long max_Time = 0; //lcm of all process periods and CPU times

        printf("Enter the number of processes to schedule: ");
        scanf("%d", &num_proc);
        //set an array of processes
        struct Processes* process = (struct Processes*) malloc(num_proc * sizeof(struct Processes));
        if(process == NULL){
            printf("Malloc failed!");
            return -1;
        }

        for(int i = 0; i < num_proc; i++){ // setting fields of Processes
            printf("Enter the CPU time of process %d: ", i + 1);
            scanf("%d", &process[i].CPU_Time);
            printf("Enter the period of process %d: ", i + 1);
            scanf("%d", &process[i].period);
            process[i].pid = i + 1;
            process[i].deadline = process[i].period;
            process[i].age = 0;
            process[i].preempted = 0;
            process[i].remaining_Time = process[i].CPU_Time;
        }
        max_Time = process[0].period;
        if(num_proc != 1){
            for(int i = 0; i < num_proc - 1; i++){
                max_Time = least_common_multiple(max_Time, process[i+1].period);
            }
        }
        int cur_size = num_proc;
        int max_Size = cur_size; //for doubling
        struct Processes* schedule = (struct Processes*) malloc(cur_size * sizeof(struct Processes)); //this is the array for scheduled processes (I was going to do stacks, but didnt realize how much I would have to implement in here, so I'm doing this instead)
        if(schedule == NULL){
            printf("Malloc failed!");
            return -1;
        }
        for(int i = 0; i < num_proc; i++){ //copy array into schedule

            schedule[i] = process[i];
        }
        deadline_Sort(schedule, cur_size); //sort it first, this is the initial order of processes
        struct Processes running = schedule[0]; //wont be null since it is strictly positive
        int procs_created = num_proc;
        int waited = 0;
        
        //scheduling loop
        for(int current_Time = 0; current_Time <= max_Time; current_Time++){
            if(check_Event(process, &schedule, &running, num_proc, &cur_size, current_Time, &procs_created, &waited, &max_Size, max_Time) == -1){
                return -1;
            }
        }
        for(int i = 1; i < cur_size; i++){ //didnt remove last element, if it executed
            if(schedule[i].preempted == 0){
            waited += max_Time - schedule[i].age;
            } else {
                waited += max_Time - schedule[i].preempted;
            }
        }
        //end block
        printf("%ld: Max Time reached\n", max_Time);
        printf("Sum of all waiting times: %d\n", waited);
        printf("Number of processes created: %d\n", procs_created);
        printf("Average Waiting Time: %0.2f\n", (double)waited/procs_created);
        //dont forget
        free(process);
        free(schedule);
        return 0;
    }