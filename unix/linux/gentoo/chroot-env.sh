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
	$(basename "$0") [-p/--partition </dev/sdX> -c/--chroot-dir </mnt/chroot> -a/--auto -t/--tmp -h/--help]

Description:
	Automates setting up and entering a chroot environment for testing Gentoo packages

Options:
	-h | --help		Displays this help
	-p | --partition	The partition we are mounting in the chroot
						- Default: unmounted partition
	-c | --chroot-dir	The chroot dir we are mounting the partition in
						- Default: wherever specified partition is mounted OR /mnt/chroot
	-a | --auto		Automatically create necessary directories
						- Default: prompt when directories need to be created
	-t | --temp		Whether or not to mount root's /tmp in the chroot
						- Default: no
	-s | --stage3		Whether to download a stage3 archive and unpack it
						- Default: no (assumes already unpacked)
HELP
	exit
}

# option --partition/-p requires a partition as argument,
# option --chroot-dir/-c requires a directory as argument,
LONGOPTS=partition::,chroot-dir::,auto,tmp,help
OPTIONS=p::c::ath

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt's output this way to handle quoting correctly
eval set -- "$PARSED"

while (( $# > 0 )); do
	case "$1" in
		-p|--partition)
			PARTITION="${2:-n}"
			shift 2
			;;
		-c|--chroot-dir)
			CHROOTDIR="${2:-n}"
			shift 2
			;;
		-a|--auto)
			AUTO="${Y:-n}"
			shift
			;;
		-t|--tmp)
			TMP="${Y:-n}"
			shift
			;;
		-h|--help)
			show_usage
			;;
		--)
			shift
			break
			;;
		*)
			echo "Invalid options passed.\t Try running $0 -h."
			exit 3
			;;
	esac
	if [[ ${PARTITION-} == "n" ]]; then
		echo "partition"
	fi
done

# set this to PARTITION if not set
UNMOUNTED_PART=$(lsblk -ipnl | awk '{ if (($6 ~ /part/) && ($7 !~ /[[:alnum:]\/]/)) { print $1 }}')

# get the chroot directory from a mounted
CHROOTDIR="$(findmnt -nt btrfs -o TARGET)"

target_dirs=(
	"${CHROOTDIR}/proc"
	"${CHROOTDIR}/dev"
	"${CHROOTDIR}/usr/portage"
	"${CHROOTDIR}/usr/src/linux"
	"${chro}"
)
