#!/usr/bin/env python
import os
import sys
from pathlib import Path

def get_file_size(filepath):
    try:
        return os.path.getsize(filepath)
    except OSError as e:
        print(f"Error getting file size for {filepath}: {e}")
        return 0

def get_remaining_space(filepath: Path):
    statvfs = os.statvfs(filepath)
    return statvfs.f_bavail * statvfs.f_frsize

def get_boot_dir_path():
    boot_dir = Path("/boot")
    if not boot_dir.is_dir():
        raise FileNotFoundError("'/boot' directory does not exist")

    return boot_dir

def humanize_size(size_bytes) -> str:
    units = ["B", "KB", "MB", "GB"]
    size = float(size_bytes)
    unit_index = 0

    # Convert the size to the appropiate unit
    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1

    # Return the human-readable size
    return f"{size:.2f} {units[unit_index]}"

def main():
    boot_dir = get_boot_dir_path()

    remaining_space = get_remaining_space(boot_dir)
    kernel_files = list(boot_dir.glob("kernel-*"))
    num_kernels = len(kernel_files)
    total_kernel_size = 0

    for kernel_file in kernel_files:
        total_kernel_size += get_file_size(kernel_file)
        kernel_version = kernel_file.name[len("kernel-"):]
        initramfs_file = boot_dir / f"initramfs-{kernel_version}.img"
        if initramfs_file.exists():
            total_kernel_size += get_file_size(initramfs_file)

    if num_kernels == 0:
        raise FileNotFoundError("No kernel files found in the '/boot' directory.")

    avg_kernel_size = total_kernel_size / num_kernels

    # print(f"Remaining space on the boot partition: {humanize_size(remaining_space)}")
    # print(f"Number of kernels: {num_kernels}")
    # print(f"Average size of the kernels (including initramfs): {humanize_size(avg_kernel_size)}")

    if remaining_space < avg_kernel_size:
        print("Warning: You may need to remove a kernel. Remaining space is less than the average kernel size.")
    print("You have enough space on the boot partition. No need to remove any kernels.")

if __name__ == "__main__":
    main()
