#!/usr/bin/env bash
# Only enable if we're not being sourced
if ! (return 0 2>/dev/null); then
	set -o errexit # Exit on most errors
	set -o nounset # Disallow expansion of unset variables
	set -o pipefail # Use last non-zero exit code in pipeline
	set -o noclobber
fi

set -o errtrace # Make sure error trap handler works

# Make sure we're a root user
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root!!!" >&2
	exit 2
fi

# test that enhanced getopt works
getopt --test >/dev/null 2>&1 && true

if [[ $? -ne 4 ]]; then
	echo "'getopt --test' failed somehow. Install util-linux silly goose or your system install is probably already busted."
	exit 1
fi

function show_usage() {
	cat -- <<HELP
Usage:
	$(basename "$0") [-p/--package <atom> -P/--partition </dev/sdX> -c/--chroot-dir </mnt/chroot> -a/--auto -t/--tmp -h/--help]

Description:
	Automates setting up and entering a chroot environment for testing Gentoo packages

Options:
	-h | --help		Displays this help
	-p | --package 		Package name we are testing (determines mount point)
	-P | --partition	The partition we are mounting in the chroot
						- Default: unmounted partition
	-c | --chroot-dir	The chroot dir we are mounting the partition in
						- Default: wherever specified partition is mounted OR /mnt/chroot
	-a | --auto		Automatically create necessary directories
						- Default: prompt when directories need to be created
	-t | --temp		Whether or not to mount root's /tmp in the chroot
						- Default: no
HELP
	exit
}

# option --partition/-p requires a partition as argument,
# option --chroot-dir/-c requires a directory as argument,
LONGOPTS=package:,partition::,chroot-dir::,auto,tmp,help
OPTIONS=p:P::c::ath

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt's output this way to handle quoting correctly
eval set -- "$PARSED"

while [[ $# -gt 0 ]]; do
	case "$1" in
		-p|--package)
			PACKAGE="$2"
			PACKAGE="${PACKAGE##*/}"
			shift 2
			;;
		-P|--partition)
			PARTITION="${2:-n}"
			shift 2
			;;
		-c|--chroot-dir)
			CHROOTDIR="${2:-n}"
			shift 2
			;;
		-a|--auto)
			AUTO="1"
			;;
		-t|--tmp)
			TMP="1"
			;;
		-h|--help)
			show_usage
			;;
		--)
			shift
			break
			;;
	esac
done

# set this to PARTITION if not set
#UNMOUNTED_PART=$(lsblk -ipnl | awk '{ if (($6 ~ /part/) && ($7 !~ /[[:alnum:]\/]/)) { print $1 }}')

# get the chroot directory from a mounted
if [[ ${CHROOTDIR:-n} == "n" ]]; then
	CHROOTDIR="$(findmnt -nt btrfs -o TARGET)"
fi

declare -A target_dirs
target_dirs=(
	["proc"]="${CHROOTDIR}/proc"
	["dev"]="${CHROOTDIR}/dev"
	["sys"]="${CHROOTDIR}/sys"
	["resolv"]="${CHROOTDIR}/etc/resolv.conf"
)


chroot_commands=(
	"mount --type proc /proc ${target_dirs["proc"]}"
	"mount --rbind /sys ${target_dirs["sys"]}"
	"mount --make-rslave ${target_dirs["sys"]}"
	"mount --rbind /dev ${target_dirs["dev"]}"
	"mount --make-rslave ${target_dirs["dev"]}"
	"cp /etc/resolv.conf ${target_dirs["resolv"]}"
)

# mount /tmp if TMP is set
if [[ ${TMP:-0} == "1" ]]; then
	target_dirs+=(["tmp"]="${CHROOTDIR}/tmp")
fi

echo "${}

for mount_command in "${chroot_commands[@]}"; do
	echo "${mount_command}"
done