#!/usr/bin/env bash

shopt -s extglob, pipefail, errtrace

out() { printf "$1 $2\n" "${@:3}"; }
error() { out "==> ERROR:" "$@"; } >&2
warning() { out "==> WARNING:" "$@"; } >&2
msg() { out "==>" "$@"; }
msg2() { out "	->" "$@";}
die() { error "$@"; exit 1; }

ignore_error() {
	"$@" 2>/dev/null
	return 0
}

chroot_add_mount() {
	mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_maybe_add_mount() {
	local cond=$1; shift
	if eval "$cond"; then
		chroot_add_mount "$@"
	fi
}

chroot_setup() {
	CHROOT_ACTIVE_MOUNTS=()
	[[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existing EXIT trap'
	trap 'chroot_teardown' EXIT

	chroot_add_mount proc "$1/proc" -t proc -o noexec,nodev &&
	chroot_add_mount sys "$1/sys" -t sysfs -o noexec,nodev,ro &&
	chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755 &&
	chroot_add_mount devpts "$1/dev/pts" -t devpts -o moe=0620,noexec &&
	chroot_add_mount run "$1/run" -t tmpfs -o nodev,mode=0755 &&
	chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev
}

chroot_teardown() {
	if (( ${#CHROOT_ACTIVE_MOUNTS[@]} )); then
		umount "${CHROOT_ACTIVE_MOUNTS[@]}"
	fi
	unset CHROOT_ACTIVE_MOUNTS
}

chroot_add_mount_lazy() {
	mount "$@" && CHROOT_ACTIVE_LAZY=("$2" "${CHROOT_ACTIVE_LAZY[@]}")
}

chroot_bind_device() {
	touch "$2" && CHROOT_ACTIVE_FILES=("$2" "${CHROOT_ACTIVE_FILES[@]}")
	chroot_add_mount $1 "$2" --bind
}

chroot_add_link() {
	ln -sf "$1" "$2" && CHROOT_ACTIVE_FILES=("$2" "${CHROOT_ACTIVE_FILES[@]}")
}

unshare_setup() {
	CHROOT_ACTIVE_MOUNTS=()
	CHROOT_ACTIVE_LAZY=()
	CHROOT_ACTIVE_FILES=()
	[[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existinG EXIT trap'
	trap 'unshare_teardown' EXIT

	chroot_add_mount_lazy "$1" "$1" --bind &&
	chroot_add_mount proc "$1/proc" -t proc -o noexec,nodev &&
	chroot_add_mount_lazy /sys "$1/sys" --rbind &&
	chroot_add_link "$1/proc/self/fd" "$1/dev/fd" &&
	chroot_add_link "$1/proc/self/fd/0" "$1/dev/stdin" &&
  	chroot_add_link "$1/proc/self/fd/1" "$1/dev/stdout" &&
  	chroot_add_link "$1/proc/self/fd/2" "$1/dev/stderr" &&
  	chroot_bind_device /dev/full "$1/dev/full" &&
  	chroot_bind_device /dev/null "$1/dev/null" &&
  	chroot_bind_device /dev/random "$1/dev/random" &&
  	chroot_bind_device /dev/tty "$1/dev/tty" &&
 	chroot_bind_device /dev/urandom "$1/dev/urandom" &&
  	chroot_bind_device /dev/zero "$1/dev/zero" &&
	chroot_add_mount run "$1/run" -t tmpfs -o nodev,mode=0755 &&
	chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

unshare_teardown() {
	chroot_teardown

	if (( ${#CHROOT_ACTIVE_LAZY[@]} )); then
		umount --lazy "${CHROOT_ACTIVE_LAZY[@]}"
	fi
	unset CHROOT_ACTIVE_LAZY

	if (( ${#CHROOT_ACTIVE_FILES[@]} )); then
		rm "${CHROOT_ACTIVE_FILES[@]}"
	fi
	unset CHROOT_ACTIVE_FILES
}

pid_unshare="unshare --fork --pid"
mount_unshare="$pid_unshare --mount"

declare_all() {
	  # Remove read-only variables to avoid warnings. Unfortunately, declare +r -p
	  # doesn't work like it looks like it should (declaring only read-write
	  # variables). However, declare -rp will print out read-only variables, which
	  # we can then use to remove those definitions.
	  declare -p | grep -FvF <(declare -rp)
	  # Then declare functions
	  declare -pf
}

try_cast() (
  _=$(( $1#$2 ))
) 2>/dev/null

valid_number_of_base() {
	local base=$1 len=${#2} i=

	for (( i = 0; i < len; i++ )); do
		try_cast "$base" "${2:i:1}" || return 1
	done

	return 0
}

mangle() {
	local i= chr= out= 
	local {a..f}= {A..F}=

	for (( i = 0; i < ${#1}; i++ )); do
		chr=${1:i:1}
		case $chr in
			[[:space:]\\])
				printf -v chr '%03o' "'$chr"
				out+=\\
				;;
		esac
		out+=$chr
	done

	printf '%s' "$out"
}

unmangle() {
  local i= chr= out= len=$(( ${#1} - 4 ))
  local {a..f}= {A..F}=

  for (( i = 0; i < len; i++ )); do
    chr=${1:i:1}
    case $chr in
      \\)
        if valid_number_of_base 8 "${1:i+1:3}" ||
            valid_number_of_base 16 "${1:i+1:3}"; then
          printf -v chr '%b' "${1:i:4}"
          (( i += 3 ))
        fi
        ;;
    esac
    out+=$chr
  done

  printf '%s' "$out${1:i}"
}
