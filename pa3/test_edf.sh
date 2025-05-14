#!/bin/bash

targetfile=edf.c
cfile=edf.c
maxtime=2

if [ ! -f "$targetfile" ]; then
    echo "Error: file $targetfile not found"
    echo "Final score: score - penalties = 0 - 0 = 0"
    exit 1
fi

# Required by the Honor System
missing_name=0
head -n 20 "$targetfile" | egrep -i "author.*[a-zA-Z]+"
if [ $? -ne 0 ]; then
    echo "Student name missing"
    missing_name=1
fi

# Required by the Honor System
missing_pledge=0
head -n 20 "$targetfile" | egrep -i "I.*pledge.*my.*honor.*that.*I.*have.*abided.*by.*the.*Stevens.*Honor.*System"
if [ $? -ne 0 ]; then
    echo -e "Pledge missing"
    missing_pledge=1
fi

# Compiling
echo
results=$(make 2>&1)
if [ $? -ne 0 ]; then
    echo "$results"
    echo "Final score: score - penalties = 0 - 0 = 0"
    exit 1
fi

num_tests=0
num_right=0
memory_problems=0
command="./${cfile%.*}"

run_test_with_args_and_input() {
    ((num_tests++))
    echo -n "Test $num_tests..."

    args="$1"
    input="$2"
    expected_output="$3"

    outputfile=$(mktemp)
    inputfile=$(mktemp)
    statusfile=$(mktemp)

    echo -e "$input" > "$inputfile"

    start=$(date +%s.%N)
    # Run run run, little program!
    (timeout --preserve-status "$maxtime" "$command" $args < "$inputfile" &> "$outputfile"; echo $? > "$statusfile") &> /dev/null
    end=$(date +%s.%N)
    status=$(cat "$statusfile")

    case $status in
        # $command: 128 + SIGBUS = 128 + 7 = 135 (rare on x86)
        135)
            echo "failed (bus error)"
            ;;
        # $command: 128 + SIGSEGV = 128 + 11 = 139
        139)
            echo "failed (segmentation fault)"
            ;;
        # $command: 128 + SIGTERM (sent by timeout(1)) = 128 + 15 = 143
        143)
            echo "failed (time out)"
            ;;
        *)
            # bash doesn't like null bytes so we substitute by hand.
            computed_output=$(sed -e 's/\x0/(NULL BYTE)/g' "$outputfile")
            if [ "$computed_output" = "$expected_output" ]; then
                ((num_right++))
                echo $start $end | awk '{printf "ok (%.3fs)\tvalgrind...", $2 - $1}'
                # Why 93?  Why not 93!
                (valgrind --leak-check=full --error-exitcode=93 $command $args < "$inputfile" &> /dev/null; echo $? > "$statusfile") &> /dev/null
                vgstatus=$(cat "$statusfile")
                case $vgstatus in
                    # valgrind detected an error when running $command
                    93)
                        ((memory_problems++))
                        echo "failed"
                        ;;
                    # valgrind not installed or not in $PATH
                    127)
                        echo "not found"
                        ;;
                    # valgrind: 128 + SIGBUS = 128 + 7 = 135 (rare on x86)
                    135)
                        ((memory_problems++))
                        echo "failed (bus error)"
                        ;;
                    # valgrind: 128 + SIGSEGV = 128 + 11 = 139
                    139)
                        ((memory_problems++))
                        echo "failed (segmentation fault)"
                        ;;
                    # compare with expected status from running $command without valgrind
                    $status)
                        echo "ok"
                        ;;
                    *)
                        ((memory_problems++))
                        echo "unknown status $vgstatus"
                        ;;
                esac
            else
                echo "failed"
                echo "==================== Expected ===================="
                echo "$expected_output"
                echo "==================== Received ===================="
                echo "$computed_output"
                echo "=================================================="
            fi
            ;;
    esac
    rm -f "$inputfile" "$outputfile" "$statusfile"
}

run_test_with_args() {
    run_test_with_args_and_input "$1" "" "$2"
}
run_test_with_input() {
    run_test_with_args_and_input "" "$1" "$2"
}

############################################################
run_test_with_input "1 2 2" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: 0: processes: 1 (2 ms)"$'\n'"0: process 1 starts"$'\n'"2: process 1 ends"$'\n'"2: Max Time reached"$'\n'"Sum of all waiting times: 0"$'\n'"Number of processes created: 1"$'\n'"Average Waiting Time: 0.00"

run_test_with_input "1 2 4" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: 0: processes: 1 (2 ms)"$'\n'"0: process 1 starts"$'\n'"2: process 1 ends"$'\n'"4: Max Time reached"$'\n'"Sum of all waiting times: 0"$'\n'"Number of processes created: 1"$'\n'"Average Waiting Time: 0.00"

run_test_with_input "2 1 4 3 5" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: 0: processes: 1 (1 ms) 2 (3 ms)"$'\n'"0: process 1 starts"$'\n'"1: process 1 ends"$'\n'"1: process 2 starts"$'\n'"4: process 2 ends"$'\n'"4: processes: 1 (1 ms)"$'\n'"4: process 1 starts"$'\n'"5: process 1 ends"$'\n'"5: processes: 2 (3 ms)"$'\n'"5: process 2 starts"$'\n'"8: process 2 ends"$'\n'"8: processes: 1 (1 ms)"$'\n'"8: process 1 starts"$'\n'"9: process 1 ends"$'\n'"10: processes: 2 (3 ms)"$'\n'"10: process 2 starts"$'\n'"12: processes: 2 (1 ms) 1 (1 ms)"$'\n'"13: process 2 ends"$'\n'"13: process 1 starts"$'\n'"14: process 1 ends"$'\n'"15: processes: 2 (3 ms)"$'\n'"15: process 2 starts"$'\n'"16: processes: 2 (2 ms) 1 (1 ms)"$'\n'"18: process 2 ends"$'\n'"18: process 1 starts"$'\n'"19: process 1 ends"$'\n'"20: Max Time reached"$'\n'"Sum of all waiting times: 4"$'\n'"Number of processes created: 9"$'\n'"Average Waiting Time: 0.44"

run_test_with_input "2 25 50 35 80" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: 0: processes: 1 (25 ms) 2 (35 ms)"$'\n'"0: process 1 starts"$'\n'"25: process 1 ends"$'\n'"25: process 2 starts"$'\n'"50: processes: 2 (10 ms) 1 (25 ms)"$'\n'"60: process 2 ends"$'\n'"60: process 1 starts"$'\n'"80: processes: 1 (5 ms) 2 (35 ms)"$'\n'"85: process 1 ends"$'\n'"85: process 2 starts"$'\n'"100: processes: 2 (20 ms) 1 (25 ms)"$'\n'"100: process 2 preempted!"$'\n'"100: process 1 starts"$'\n'"125: process 1 ends"$'\n'"125: process 2 starts"$'\n'"145: process 2 ends"$'\n'"150: processes: 1 (25 ms)"$'\n'"150: process 1 starts"$'\n'"160: processes: 1 (15 ms) 2 (35 ms)"$'\n'"175: process 1 ends"$'\n'"175: process 2 starts"$'\n'"200: processes: 2 (10 ms) 1 (25 ms)"$'\n'"210: process 2 ends"$'\n'"210: process 1 starts"$'\n'"235: process 1 ends"$'\n'"240: processes: 2 (35 ms)"$'\n'"240: process 2 starts"$'\n'"250: processes: 2 (25 ms) 1 (25 ms)"$'\n'"250: process 2 preempted!"$'\n'"250: process 1 starts"$'\n'"275: process 1 ends"$'\n'"275: process 2 starts"$'\n'"300: process 2 ends"$'\n'"300: processes: 1 (25 ms)"$'\n'"300: process 1 starts"$'\n'"320: processes: 1 (5 ms) 2 (35 ms)"$'\n'"325: process 1 ends"$'\n'"325: process 2 starts"$'\n'"350: processes: 2 (10 ms) 1 (25 ms)"$'\n'"360: process 2 ends"$'\n'"360: process 1 starts"$'\n'"385: process 1 ends"$'\n'"400: Max Time reached"$'\n'"Sum of all waiting times: 130"$'\n'"Number of processes created: 13"$'\n'"Average Waiting Time: 10.00"

run_test_with_input "3 2 4 4 8 3 6" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: Enter the CPU time of process 3: Enter the period of process 3: 0: processes: 1 (2 ms) 2 (4 ms) 3 (3 ms)"$'\n'"0: process 1 starts"$'\n'"2: process 1 ends"$'\n'"2: process 3 starts"$'\n'"4: processes: 2 (4 ms) 3 (1 ms) 1 (2 ms)"$'\n'"5: process 3 ends"$'\n'"5: process 2 starts"$'\n'"6: processes: 2 (3 ms) 1 (2 ms) 3 (3 ms)"$'\n'"8: process 1 missed deadline (2 ms left)"$'\n'"8: process 2 missed deadline (1 ms left)"$'\n'"8: processes: 2 (1 ms) 1 (2 ms) 3 (3 ms) 1 (2 ms) 2 (4 ms)"$'\n'"8: process 2 preempted!"$'\n'"8: process 1 starts"$'\n'"10: process 1 ends"$'\n'"10: process 3 starts"$'\n'"12: process 1 missed deadline (2 ms left)"$'\n'"12: process 3 missed deadline (1 ms left)"$'\n'"12: processes: 2 (1 ms) 3 (1 ms) 1 (2 ms) 2 (4 ms) 1 (2 ms) 3 (3 ms)"$'\n'"12: process 3 preempted!"$'\n'"12: process 2 starts"$'\n'"13: process 2 ends"$'\n'"13: process 1 starts"$'\n'"15: process 1 ends"$'\n'"15: process 2 starts"$'\n'"16: process 1 missed deadline (2 ms left)"$'\n'"16: process 2 missed deadline (3 ms left)"$'\n'"16: processes: 3 (1 ms) 2 (3 ms) 1 (2 ms) 3 (3 ms) 1 (2 ms) 2 (4 ms)"$'\n'"16: process 2 preempted!"$'\n'"16: process 3 starts"$'\n'"17: process 3 ends"$'\n'"17: process 3 starts"$'\n'"18: process 3 missed deadline (2 ms left)"$'\n'"18: processes: 2 (3 ms) 1 (2 ms) 3 (2 ms) 1 (2 ms) 2 (4 ms) 3 (3 ms)"$'\n'"18: process 3 preempted!"$'\n'"18: process 1 starts"$'\n'"20: process 1 ends"$'\n'"20: process 1 missed deadline (2 ms left)"$'\n'"20: processes: 2 (3 ms) 3 (2 ms) 1 (2 ms) 2 (4 ms) 3 (3 ms) 1 (2 ms)"$'\n'"20: process 2 starts"$'\n'"23: process 2 ends"$'\n'"23: process 3 starts"$'\n'"24: Max Time reached"$'\n'"Sum of all waiting times: 81"$'\n'"Number of processes created: 13"$'\n'"Average Waiting Time: 6.23"

run_test_with_input "4 1 2 2 4 3 6 5 10" "Enter the number of processes to schedule: Enter the CPU time of process 1: Enter the period of process 1: Enter the CPU time of process 2: Enter the period of process 2: Enter the CPU time of process 3: Enter the period of process 3: Enter the CPU time of process 4: Enter the period of process 4: 0: processes: 1 (1 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms)"$'\n'"0: process 1 starts"$'\n'"1: process 1 ends"$'\n'"1: process 2 starts"$'\n'"2: processes: 2 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms)"$'\n'"3: process 2 ends"$'\n'"3: process 1 starts"$'\n'"4: process 1 ends"$'\n'"4: processes: 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)"$'\n'"4: process 3 starts"$'\n'"6: process 1 missed deadline (1 ms left)"$'\n'"6: process 3 missed deadline (1 ms left)"$'\n'"6: processes: 3 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)"$'\n'"6: process 3 preempted!"$'\n'"6: process 1 starts"$'\n'"7: process 1 ends"$'\n'"7: process 2 starts"$'\n'"8: process 1 missed deadline (1 ms left)"$'\n'"8: process 2 missed deadline (1 ms left)"$'\n'"8: processes: 3 (1 ms) 4 (5 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)"$'\n'"8: process 2 preempted!"$'\n'"8: process 4 starts"$'\n'"10: process 1 missed deadline (1 ms left)"$'\n'"10: process 1 missed deadline (1 ms left)"$'\n'"10: process 4 missed deadline (3 ms left)"$'\n'"10: processes: 3 (1 ms) 4 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms)"$'\n'"10: process 4 preempted!"$'\n'"10: process 3 starts"$'\n'"11: process 3 ends"$'\n'"11: process 2 starts"$'\n'"12: process 2 ends"$'\n'"12: process 1 missed deadline (1 ms left)"$'\n'"12: process 1 missed deadline (1 ms left)"$'\n'"12: process 1 missed deadline (1 ms left)"$'\n'"12: process 2 missed deadline (2 ms left)"$'\n'"12: process 3 missed deadline (3 ms left)"$'\n'"12: processes: 4 (3 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)"$'\n'"12: process 1 starts"$'\n'"13: process 1 ends"$'\n'"13: process 1 starts"$'\n'"14: process 1 ends"$'\n'"14: process 1 missed deadline (1 ms left)"$'\n'"14: process 1 missed deadline (1 ms left)"$'\n'"14: processes: 4 (3 ms) 3 (3 ms) 2 (2 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)"$'\n'"14: process 2 starts"$'\n'"16: process 2 ends"$'\n'"16: process 1 missed deadline (1 ms left)"$'\n'"16: process 1 missed deadline (1 ms left)"$'\n'"16: process 1 missed deadline (1 ms left)"$'\n'"16: process 2 missed deadline (2 ms left)"$'\n'"16: processes: 4 (3 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms)"$'\n'"16: process 3 starts"$'\n'"18: process 1 missed deadline (1 ms left)"$'\n'"18: process 1 missed deadline (1 ms left)"$'\n'"18: process 1 missed deadline (1 ms left)"$'\n'"18: process 1 missed deadline (1 ms left)"$'\n'"18: process 3 missed deadline (1 ms left)"$'\n'"18: process 3 missed deadline (3 ms left)"$'\n'"18: processes: 4 (3 ms) 3 (1 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)"$'\n'"18: process 3 preempted!"$'\n'"18: process 4 starts"$'\n'"20: process 1 missed deadline (1 ms left)"$'\n'"20: process 1 missed deadline (1 ms left)"$'\n'"20: process 1 missed deadline (1 ms left)"$'\n'"20: process 1 missed deadline (1 ms left)"$'\n'"20: process 1 missed deadline (1 ms left)"$'\n'"20: process 2 missed deadline (2 ms left)"$'\n'"20: process 2 missed deadline (2 ms left)"$'\n'"20: process 4 missed deadline (1 ms left)"$'\n'"20: process 4 missed deadline (5 ms left)"$'\n'"20: processes: 4 (1 ms) 3 (1 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms)"$'\n'"20: process 4 preempted!"$'\n'"20: process 1 starts"$'\n'"21: process 1 ends"$'\n'"21: process 1 starts"$'\n'"22: process 1 ends"$'\n'"22: process 1 missed deadline (1 ms left)"$'\n'"22: process 1 missed deadline (1 ms left)"$'\n'"22: process 1 missed deadline (1 ms left)"$'\n'"22: process 1 missed deadline (1 ms left)"$'\n'"22: processes: 4 (1 ms) 3 (1 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms)"$'\n'"22: process 3 starts"$'\n'"23: process 3 ends"$'\n'"23: process 2 starts"$'\n'"24: process 1 missed deadline (1 ms left)"$'\n'"24: process 1 missed deadline (1 ms left)"$'\n'"24: process 1 missed deadline (1 ms left)"$'\n'"24: process 1 missed deadline (1 ms left)"$'\n'"24: process 1 missed deadline (1 ms left)"$'\n'"24: process 2 missed deadline (1 ms left)"$'\n'"24: process 2 missed deadline (2 ms left)"$'\n'"24: process 2 missed deadline (2 ms left)"$'\n'"24: process 3 missed deadline (3 ms left)"$'\n'"24: process 3 missed deadline (3 ms left)"$'\n'"24: processes: 4 (1 ms) 4 (5 ms) 2 (1 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)"$'\n'"24: process 2 preempted!"$'\n'"24: process 1 starts"$'\n'"25: process 1 ends"$'\n'"25: process 1 starts"$'\n'"26: process 1 ends"$'\n'"26: process 1 missed deadline (1 ms left)"$'\n'"26: process 1 missed deadline (1 ms left)"$'\n'"26: process 1 missed deadline (1 ms left)"$'\n'"26: process 1 missed deadline (1 ms left)"$'\n'"26: processes: 4 (1 ms) 4 (5 ms) 2 (1 ms) 3 (3 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)"$'\n'"26: process 2 starts"$'\n'"27: process 2 ends"$'\n'"27: process 2 starts"$'\n'"28: process 1 missed deadline (1 ms left)"$'\n'"28: process 1 missed deadline (1 ms left)"$'\n'"28: process 1 missed deadline (1 ms left)"$'\n'"28: process 1 missed deadline (1 ms left)"$'\n'"28: process 1 missed deadline (1 ms left)"$'\n'"28: process 2 missed deadline (1 ms left)"$'\n'"28: process 2 missed deadline (2 ms left)"$'\n'"28: process 2 missed deadline (2 ms left)"$'\n'"28: processes: 4 (1 ms) 4 (5 ms) 3 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms)"$'\n'"28: process 2 preempted!"$'\n'"28: process 4 starts"$'\n'"29: process 4 ends"$'\n'"29: process 4 starts"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 1 missed deadline (1 ms left)"$'\n'"30: process 3 missed deadline (3 ms left)"$'\n'"30: process 3 missed deadline (3 ms left)"$'\n'"30: process 3 missed deadline (3 ms left)"$'\n'"30: process 4 missed deadline (4 ms left)"$'\n'"30: process 4 missed deadline (5 ms left)"$'\n'"30: processes: 4 (4 ms) 3 (3 ms) 2 (1 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms)"$'\n'"30: process 4 preempted!"$'\n'"30: process 2 starts"$'\n'"31: process 2 ends"$'\n'"31: process 1 starts"$'\n'"32: process 1 ends"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 1 missed deadline (1 ms left)"$'\n'"32: process 2 missed deadline (2 ms left)"$'\n'"32: process 2 missed deadline (2 ms left)"$'\n'"32: process 2 missed deadline (2 ms left)"$'\n'"32: processes: 4 (4 ms) 3 (3 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)"$'\n'"32: process 1 starts"$'\n'"33: process 1 ends"$'\n'"33: process 1 starts"$'\n'"34: process 1 ends"$'\n'"34: process 1 missed deadline (1 ms left)"$'\n'"34: process 1 missed deadline (1 ms left)"$'\n'"34: process 1 missed deadline (1 ms left)"$'\n'"34: process 1 missed deadline (1 ms left)"$'\n'"34: process 1 missed deadline (1 ms left)"$'\n'"34: processes: 4 (4 ms) 3 (3 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)"$'\n'"34: process 3 starts"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 1 missed deadline (1 ms left)"$'\n'"36: process 2 missed deadline (2 ms left)"$'\n'"36: process 2 missed deadline (2 ms left)"$'\n'"36: process 2 missed deadline (2 ms left)"$'\n'"36: process 2 missed deadline (2 ms left)"$'\n'"36: process 3 missed deadline (1 ms left)"$'\n'"36: process 3 missed deadline (3 ms left)"$'\n'"36: process 3 missed deadline (3 ms left)"$'\n'"36: process 3 missed deadline (3 ms left)"$'\n'"36: processes: 4 (4 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)"$'\n'"36: process 3 preempted!"$'\n'"36: process 1 starts"$'\n'"37: process 1 ends"$'\n'"37: process 1 starts"$'\n'"38: process 1 ends"$'\n'"38: process 1 missed deadline (1 ms left)"$'\n'"38: process 1 missed deadline (1 ms left)"$'\n'"38: process 1 missed deadline (1 ms left)"$'\n'"38: process 1 missed deadline (1 ms left)"$'\n'"38: process 1 missed deadline (1 ms left)"$'\n'"38: processes: 4 (4 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms)"$'\n'"38: process 4 starts"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 1 missed deadline (1 ms left)"$'\n'"40: process 2 missed deadline (2 ms left)"$'\n'"40: process 2 missed deadline (2 ms left)"$'\n'"40: process 2 missed deadline (2 ms left)"$'\n'"40: process 2 missed deadline (2 ms left)"$'\n'"40: process 2 missed deadline (2 ms left)"$'\n'"40: process 4 missed deadline (2 ms left)"$'\n'"40: process 4 missed deadline (5 ms left)"$'\n'"40: process 4 missed deadline (5 ms left)"$'\n'"40: processes: 4 (2 ms) 3 (1 ms) 3 (3 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms)"$'\n'"40: process 4 preempted!"$'\n'"40: process 3 starts"$'\n'"41: process 3 ends"$'\n'"41: process 3 starts"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 1 missed deadline (1 ms left)"$'\n'"42: process 3 missed deadline (2 ms left)"$'\n'"42: process 3 missed deadline (3 ms left)"$'\n'"42: process 3 missed deadline (3 ms left)"$'\n'"42: process 3 missed deadline (3 ms left)"$'\n'"42: processes: 4 (2 ms) 3 (2 ms) 2 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms)"$'\n'"42: process 3 preempted!"$'\n'"42: process 2 starts"$'\n'"44: process 2 ends"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 1 missed deadline (1 ms left)"$'\n'"44: process 2 missed deadline (2 ms left)"$'\n'"44: process 2 missed deadline (2 ms left)"$'\n'"44: process 2 missed deadline (2 ms left)"$'\n'"44: process 2 missed deadline (2 ms left)"$'\n'"44: process 2 missed deadline (2 ms left)"$'\n'"44: processes: 4 (2 ms) 3 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)"$'\n'"44: process 1 starts"$'\n'"45: process 1 ends"$'\n'"45: process 1 starts"$'\n'"46: process 1 ends"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: process 1 missed deadline (1 ms left)"$'\n'"46: processes: 4 (2 ms) 3 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)"$'\n'"46: process 3 starts"$'\n'"48: process 3 ends"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 1 missed deadline (1 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 2 missed deadline (2 ms left)"$'\n'"48: process 3 missed deadline (3 ms left)"$'\n'"48: process 3 missed deadline (3 ms left)"$'\n'"48: process 3 missed deadline (3 ms left)"$'\n'"48: process 3 missed deadline (3 ms left)"$'\n'"48: processes: 4 (2 ms) 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms)"$'\n'"48: process 4 starts"$'\n'"50: process 4 ends"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 1 missed deadline (1 ms left)"$'\n'"50: process 4 missed deadline (5 ms left)"$'\n'"50: process 4 missed deadline (5 ms left)"$'\n'"50: process 4 missed deadline (5 ms left)"$'\n'"50: processes: 4 (5 ms) 2 (2 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms)"$'\n'"50: process 2 starts"$'\n'"52: process 2 ends"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 1 missed deadline (1 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: process 2 missed deadline (2 ms left)"$'\n'"52: processes: 4 (5 ms) 3 (3 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms)"$'\n'"52: process 3 starts"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 1 missed deadline (1 ms left)"$'\n'"54: process 3 missed deadline (1 ms left)"$'\n'"54: process 3 missed deadline (3 ms left)"$'\n'"54: process 3 missed deadline (3 ms left)"$'\n'"54: process 3 missed deadline (3 ms left)"$'\n'"54: process 3 missed deadline (3 ms left)"$'\n'"54: processes: 4 (5 ms) 3 (1 ms) 2 (2 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms)"$'\n'"54: process 3 preempted!"$'\n'"54: process 2 starts"$'\n'"56: process 2 ends"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 1 missed deadline (1 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: process 2 missed deadline (2 ms left)"$'\n'"56: processes: 4 (5 ms) 3 (1 ms) 3 (3 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms)"$'\n'"56: process 1 starts"$'\n'"57: process 1 ends"$'\n'"57: process 1 starts"$'\n'"58: process 1 ends"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: process 1 missed deadline (1 ms left)"$'\n'"58: processes: 4 (5 ms) 3 (1 ms) 3 (3 ms) 4 (5 ms) 2 (2 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 4 (5 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 1 (1 ms) 2 (2 ms) 3 (3 ms) 1 (1 ms) 4 (5 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms) 3 (3 ms) 1 (1 ms) 2 (2 ms) 1 (1 ms)"$'\n'"58: process 4 starts"$'\n'"60: Max Time reached"$'\n'"Sum of all waiting times: 926"$'\n'"Number of processes created: 61"$'\n'"Average Waiting Time: 15.18"

############################################################
echo
echo "Total tests run: $num_tests"
echo "Number correct : $num_right"
score=$((100 * $num_right / $num_tests))
echo "Percent correct: $score%"
if [ $missing_name == 1 ]; then
    echo "Missing Name: -5"
fi
if [ $missing_pledge == 1 ]; then
    echo "Missing or incorrect pledge: -5"
fi

if [ $memory_problems -gt 1 ]; then
    echo "Memory problems: $memory_problems (-5 each, max of -15)"
    if [ $memory_problems -gt 3 ]; then
        memory_problems=3
    fi
fi

penalties=$((5 * $missing_name + 5 * $missing_pledge + 5 * $memory_problems))
final_score=$(($score - $penalties))
if [ $final_score -lt 0 ]; then
    final_score=0
fi
echo "Final score: score - penalties = $score - $penalties = $final_score"

make clean > /dev/null 2>&1
