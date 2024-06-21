#!/bin/sh
# Posix compliant script to copy a system from one disk to another.
#
set -e

# Function to display usage
usage() {
	echo "Usage: $0 -s <source_device> -d <destination_device> -m <mount_point> -b <current_boot_dir> -t <destination_boot_dir> [-e <efi_device> | -i <bios_device>"
	echo "Try '$0 --help' for more information."
	exit 1
}

# Function to display help
help() {
    cat << EOF
Usage: $0 [OPTIONS]

This script automates the process of transferring a system from one disk to another,
ensuring the new disk is bootable, and handles both UEFI and BIOS systems.

Options:
  -s <source_device>          Source device containing the system to be transferred
  -d <destination_device>     Destination device to which the system will be transferred
  -m <mount_point>            Temporary mount point for mounting source and destination devices
  -b <current_boot_dir>       Current boot directory of the source system
  -t <destination_boot_dir>   Destination boot directory on the destination device
  -e <efi_device>             Destination device for EFI system partition (required for UEFI systems)
  -i <bios_device>            Destination device for BIOS boot partition (required for BIOS systems)
  --help                      Display this help message and exit

Example:
  sudo $0 -s /dev/sdX1 -d /dev/sdY1 -m /mnt/tmp -b /boot -t /mnt/tmp/boot -e /dev/sdY2

EOF
    exit 0
}

# Function to check if a device is mounted
is_mounted() {
	findmnt -rn -S "$1" > /dev/null 2>&1
}

# Function to detect UEFI systems
is_uefi() {
	[ -d /sys/firmware/efi ]
}

# Function to get device for a given mount point
get_device_for_mount() {
	findmnt -n -o SOURCE -T "$1"
}

# Function to handle rsync operations
# Parameters: $1 - rsync options, $2 - source directory, $3 - destination directory
perform_rsync() {
	OPTIONS="$1"
	SOURCE_DIR="$2"
	DEST_DIR="$3"

	rsync "$OPTIONS" "$SOURCE_DIR" "$DEST_DIR"
	if [ $? -eq 0 ]; then
		echo "$SOURCE_DIR copied successfully to $DEST_DIR."
	else
		echo "An error occured while copying the directory $SOURCE_DIR to $DEST_DIR."
		cleanup_mounts
		exit 1
	fi
}

# Function to cleanup the mounts and temporary directories
cleanup_mounts() {
	umount "$SOURCE_MOUNT_POINT" && echo "Successfully unmounted $SOURCE_MOUNT_POINT" || echo "Failed to unmount $SOURCE_MOUNT_POINT"
	umount "$DESTINATION_MOUNT_POINT" && echo "Successfully unmounted $DESTINATION_MOUNT_POINT" || echo "Failed to unmount $DESTINATION_MOUNT_POINT"
	rmdir "$SOURCE_MOUNT_POINT" && echo "Successfully removed $SOURCE_MOUNT_POINT" || echo "Failed to remove $SOURCE_MOUNT_POINT"
	rmdir "$DESTINATION_MOUNT_POINT" && echo "Successfully removed $DESTINATION_MOUNT_POINT" || echo "Failed to remove $DESTINATION_MOUNT_POINT"
}

# Define options string
options="s:d:m:b:t:e:i:-:"

# Initialize variables
SOURCE_DEVICE=""
DESTINATION_DEVICE=""
TEMP_MOUNT_POINT=""
CURRENT_BOOT_DIR=""
DESTINATION_BOOT_DIR=""
EFI_DEVICE=""
BIOS_DEVICE=""

# Loop through options using getopt
while getopt "$options" opt; do
  case $opt in
    s) SOURCE_DEVICE="$OPTARG" ;;  # Use double quotes for argument assignment
    d) DESTINATION_DEVICE="$OPTARG" ;;
    m) TEMP_MOUNT_POINT="$OPTARG" ;;
    b) CURRENT_BOOT_DIR="$OPTARG" ;;
    t) DESTINATION_BOOT_DIR="$OPTARG" ;;
    e) EFI_DEVICE="$OPTARG" ;;
    i) BIOS_DEVICE="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;  # Error handling
    -)  # Handle long options (if any)
      case "$OPTARG" in
        help) help ;; 
        *) usage ;;     
      esac
      ;;
  esac
done

# Check if all the required options are set
if [ -z "$SOURCE_DEVICE" ] || [ -z "$DESTINATION_DEVICE" ] || [ -z "$TEMP_MOUNT_POINT" ] || \
	[ -z "$CURRENT_BOOT_DIR" ] || [ -z "$DESTINATION_BOOT_DIR" ]; then
	echo "Error: Missing required arguments."
	usage
fi

# Check if EFI_DEVICE or BIOS_DEVICE is required based on the system
if is_uefi && [ -z "$EFI_DEVICE" ]; then
	echo "Error: EFI device (-e) is required for UEFI systems."
	usage
fi

if ! is_uefi && [ -z "$BIOS_DEVICE" ]; then
	echo "Error: BIOS device (-i) is required for BIOS systems."
	usage
fi

# Check if the source and destination devices are not already mounted
if is_mounted "$SOURCE_DEVICE"; then
	EXISTING_MOUNT_POINT="$(get_device_mount_point "$SOURCE_DEVICE")"
	echo "Source device $SOURCE_DEVICE is already mounted on $EXISTING_MOUNT_POINT. Exiting."
	exit 1
fi

if is_mounted "$DESTINATION_DEVICE"; then
	EXISTING_MOUNT_POINT="$(get_device_mount_point "$DESTINATION_DEVICE")"
	echo "Destination device $DESTINATION_DEVICE is already mounted on $EXISTING_MOUNT_POINT. Exiting."
	exit 1
fi

# Determine the device for the current boot directory
CURRENT_BOOT_DEVICE="$(get_device_for_mount "$CURRENT_BOOT_DIR")"
if [ -z "$CURRENT_BOOT_DEVICE" ]; then
	echo "Error: failed to determine device for current boot directory $CURRENT_BOOT_DIR"
	exit 1
fi

# Create temporary mount points
SOURCE_MOUNT_POINT="${TEMP_MOUNT_POINT}/source"
DESTINATION_MOUNT_POINT="${TEMP_MOUNT_POINT}/destination"

mkdir -p "$SOURCE_MOUNT_POINT" "$DESTINATION_MOUNT_POINT"

# Mount the source and destination devices
# NOTE: not sure this works with BTRFS or XFS 'mount -t' might be needed
mount "$SOURCE_DEVICE" "$SOURCE_MOUNT_POINT"
if [ $? -ne 0 ]; then
	echo "Failed to mount source device ${SOURCE_DEVICE} on ${SOURCE_MOUNT_POINT}. Exiting"
	exit 1
fi

mount "$DESTINATION_DEVICE" "$DESTINATION_MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "Failed to mount destination device ${DESTINATION_DEVICE} on ${DESTINATION_MOUNT_POINT}. Exiting."
    umount "$SOURCE_MOUNT_POINT"
    exit 1
fi

# Rsync options to handle root directory
ROOT_RSYNC_OPTIONS="-aAXv --progress --exclude='/dev/*' --exclude='/proc/*' --exclude='/sys/*' --exclude='/tmp/*' --exclude='/run/*' --exclude='/mnt/*' --exclude='/media/*' --exclude='/lost+found'"

# Run rsync to copy contents old root source to the new root's destination
perform_rsync "$ROOT_RSYNC_OPTIONS" "${SOURCE_MOUNT_POINT}/" "${DESTINATION_MOUNT_POINT}/"

# Rsync options to handle the boot directory
BOOT_RSYNC_OPTIONS="-aAXv --progress"

# Run rsync to copy the contents of the old boot to the new boot destination
perform_rsync "$BOOT_RSYNC_OPTIONS" "${CURRENT_BOOT_DIR}/" "${DESTINATION_BOOT_DIR}/"

# Mount necessary filesystems for chroot
mount --bind /dev "${DESTINATION_MOUNT_POINT}/dev"
mount --bind /proc "${DESTINATION_MOUNT_POINT}/proc"
mount --bind /sys "${DESTINATION_MOUNT_POINT}/sys"

# Chroot into the destination and reinstall grub based on the system type
if is_uefi; then
	echo "Installing grub on $EFI_DEVICE for UEFI..."
	chroot "$DESTINATION_MOUNT_POINT" /bin/sh -c '
		if [ -d /sys/firmware/efi ]; then
			mount --bind /sys/firmware/efi/efivars /sys/firmware/efi/efivars
			grub-install --target=x86_64-efi --efi-directory='"$DESTINATION_BOOT_DIR"' --bootloader-id=GRUB --recheck
		else
			echo '"/sys/firmware/efi not found.. Something went wrong."'
		fi
	'
else
    echo "Installing GRUB for BIOS..."
    chroot "$DESTINATION_MOUNT_POINT" /bin/sh -c '
        grub-install --target=i386-pc '"$BIOS_DEVICE"'
    '
fi

# Check if GRUB was installed successfully
if [ $? -eq 0 ]; then
    echo "GRUB installed successfully."
else
    echo "An error occurred while installing GRUB."
fi

# Clean up bind mounts
umount "$DESTINATION_MOUNT_POINT/dev"
umount "$DESTINATION_MOUNT_POINT/proc"
umount "$DESTINATION_MOUNT_POINT/sys"

# Clean up mounts and temporary directories
cleanup_mounts

echo "System transfer completed."

exit 0

