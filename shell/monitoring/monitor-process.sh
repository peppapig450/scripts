#!/bin/sh

# Start strace in the background to trace file accesses and execve system calls
strace -f -e trace=open,execve -o "$HOME"/build_trace.log "$@" &

# Capture the PID of the strace process
PID="$!"

lsof -r -p "$PID" > "$HOME"/lsof_output.log
