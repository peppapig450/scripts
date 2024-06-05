#!/usr/bin/env python

import argparse
from pathlib import Path
import os
from typing import Iterator

def humanize_size(size: float) -> str:
    # Convert size in bytes to a human readable format
    units = ["B", "KB", "MB", "GB", "TB"]
    for unit in units:
        if size < 1025:
            return f"{size:.2f} {unit}"
        size /= 1024
    return f"{size:.2f} PB" # Petabytes just in case

def get_files(directory: Path, recurse: bool) -> Iterator[Path]:
    # Get list of files in the directory, optionally including subdirectories
    if recurse:
        # Walk through directory
        for root, _, files in os.walk(directory):
            for file in files:
                yield (Path(root) / file)
    else:
        # List files in directory non-recursively
        with os.scandir(directory) as it:
            for entry in it:
                if entry.is_file():
                    yield Path(entry.path)

def average_file_size(directory: Path, recurse: bool) -> float:
    # Calculate average file size in the directory or directories
    total_size = 0
    file_count = 0

    for file_path in get_files(directory, recurse):
        if file_path.is_file():
            total_size += os.path.getsize(file_path)
            file_count += 1

    if file_count == 0:
        raise ValueError(f"No files found in directory: {directory}")

    return total_size / file_count

def main():
    # Set up argument parser
    parser = argparse.ArgumentParser(description='Calculate the average file size in a directory.')
    parser.add_argument('directory', type=str, help="Directory to search")
    parser.add_argument('-r', '--recursive', action='store_true', help='Recurse through subdirectories')
    parser.add_argument('--no-humanize', dest='humanize', action='store_false', default=True, help='Disable humanizing the output size')

    args = parser.parse_args()
    
    avg_size = average_file_size(args.directory, args.recursive)

    if not args.humanize:
        print(f"Average file size: {avg_size:.2f} bytes")
    else:
        print(f"Average file size: {humanize_size(avg_size)}")

if __name__ == "__main__":
    main()
