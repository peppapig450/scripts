#!/usr/bin/env bash

# Check if start date and end date are provided
if [ $# -eq 2 ]; then
    start_date=$1
    end_date=$2
elif [ $# -eq 1 ] && [ "$1" = "-t" ]; then
    # Get today's date
    midnight="$(date +%Y-%m-%dT00:00:00)"
    right_now="$(date +%Y-%m-%dT%H:%M:%S)"

    start_date="${midnight}"
    end_date="${right_now}"
else
    cat <<< "Usage: $0 <start_date> <end_date>
       $0 -t
Example: $0 2024-01-01 2024-06-01
Example with today's date: $0 -t"
    exit 1
fi


# Get commit IDs for the specified time period
git log --pretty='%aI %H' | \
    awk -v start_date="$start_date" -v end_date="$end_date" '$1 >= start_date && $1 <= end_date { print $2 }' | \
        git log --no-walk --stdin
