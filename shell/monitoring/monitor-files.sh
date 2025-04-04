#!/bin/sh

"$@" &

PID=$!

lsof -p "$PID" -f | tee -a -p ~/monitor.log
