#!/usr/bin/env bash
# Detect the latest bcachefs version supported by the kernel by parsing the superblock.
# This version is used to pin the bcachefs-tools package so userspace and kernel-space remain compatible.
# The superblock version is updated at mount, making it a reliable indicator of kernel support.
#
# Gentoo-only: This script assumes you're using Portage to manage bcachefs-tools.
# If you're not on Gentoo, please enjoy this cryptic artifact from a parallel universe.
shopt -s shift_verbose
set -Eeuo pipefail

# Trap any error and invoke error_exit with the function name and line number
trap 'error_exit "An unexpected error occured: ${BASH_COMMAND}"' ERR

# Tools we need for this job
# NOTE: if you're not me running this, make sure you swap doas out for sudo if you need :p
REQUIRED_CMDS=(findmnt bcachefs eix perl)

# Prints an error message, function name, and line number and
# exits with a provided status (default: 1)
error_exit() {
    local msg="${1}"
    local code="${2:-1}"
    local lineno="${BASH_LINENO[0]}"
    local func_name="${FUNCNAME[1]}"

    printf "Error in %s at line %s: %s\n" "${func_name}" "${lineno}" "${msg}" >&2
    exit "${code}"
}

# Dynamically detect doas or sudo and run command as root
exec_privileged() {
    if command -v doas >/dev/null 2>&1; then
        doas -- "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo -- "$@"
    else
        error_exit "No doas or sudo found. Is everything okay?"
    fi
}

# Verifies that all required commands are available on PATH
check_requirements() {
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            error_exit "Missing required command: ${cmd}"
        fi
    done
}

# Gets a value from findmnt for the first mounted bcachefs volume
# Usage: get_fs_field PARTUUID | UUID | SOURCE | etc
get_fs_field() {
    local field="${1}"

    findmnt -f -t bcachefs -o "${field}" -rn 2>/dev/null || true
}

# Returns PARTUUID or UUID of the first mounted bcachefs filesystem.
# Falls back to UUID if PARTUUID is unavailable. Exits on failure.
get_fs_id() {
    local fs_id

    fs_id="$(get_fs_field PARTUUID)"
    [[ -n ${fs_id} ]] || fs_id="$(get_fs_field UUID)"
    [[ -n ${fs_id} ]] || error_exit "No bcachefs filesystem found with PARTUUID or UUID"

    printf '%s' "${fs_id}"
}

# Returns the kernel-supported bcachefs version from the superblock of the given PARTUUID or UUID.
# Tries /dev/disk/by-partuuid first, then by-uuid. Exits on failure.
get_kernel_version() {
    local id="${1}"
    local version
    local path

    for type in partuuid uuid; do
        path="/dev/disk/by-${type}/${id}"
        if [[ -e ${path} ]]; then
            version="$(exec_privileged bcachefs show-super "${path}" |
                perl -lne 'print $1 and exit if /^\s*Version:\s*([\d.]+)/')"
            [[ -n ${version} ]] && break
        fi
    done

    [[ -n ${version} ]] || error_exit "Could not extract bcachefs version from superblock (${id})."
    printf '%s' "${version}"
}

# Queries eix for available bcachefs-tools versions
# Populates the provided array reference
# NOTE: The fallback for this would be with emerge --search
# which has messy output.
get_available_versions() {
    local -n versions_ref="${1}"
    local tmp_output
    local -a eix_args=(
        -A 'sys-fs/bcachefs-tools'
        -u
        --format '<availableversions:NAMEVERSION>'
    )

    if ! tmp_output="$(eix "${eix_args[@]}")"; then
        error_exit "Failed to query available bcachefs-tools versions via eix."
    fi

    mapfile -t versions_ref <<<"${tmp_output}"
    ((${#versions_ref[@]} > 0)) || error_exit "No available bcachefs-tools versions found."
}

# Pads a version string to be in the form X.Y.Z (adds trailing ".0" if needed)
# E.g., "1.20" -> "1.20.0", "1.20.1" -> "1.20.1"
normalize_version() {
    local version="${1}"
    local -a parts

    IFS="." read -r -a parts <<<"${version}"

    case "${#parts[@]}" in
        2) printf '%s.%s.0\n' "${parts[0]}" "${parts[1]}" ;;
        3) printf '%s\n' "${version}" ;;
        *) error_exit "unsupported version format: ${version}" ;;
    esac
}

# Find a matching version <= kernel version; falls back to the kernel version if none found
# Args: kernel_version, list of available versions
find_matched_version() {
    (($# < 1)) && error_exit "Need at least one argument (kernel version)"

    local kernel_version="${1}"
    shift
    local versions=("$@")
    ((${#versions[@]} >= 1)) || error_exit "Need at least one version (portage)"

    local version_num
    local normalized_kernel

    # We handle the error manually so set -e not firing is fine
    # shellcheck disable=SC2310
    if ! normalized_kernel="$(normalize_version "${kernel_version}")"; then
        return 1
    fi

    for version in "${versions[@]}"; do
        version_num="${version#sys-fs/bcachefs-tools-}"
        if [[ ${version_num} == "${normalized_kernel}" ]]; then
            printf '%s' "${version_num}"
            return
        fi
    done

    # No exact match found; fallback
    printf '%s' "${normalized_kernel}"
}

# Pins the kernel version in the Portage package.mask file
# Requires the matched version as argument
pin_version() {
    local matched_version="${1}"
    local package="sys-fs/bcachefs-tools"
    local pinned="${package}-${matched_version}"
    local mask_root="/etc/portage/package.mask"
    local mask_target

    if [[ -d ${mask_target:-} ]]; then
        mask_target="${mask_root}/bcachefs-tools"
    elif [[ -f ${mask_target:-} ]]; then
        mask_target="${mask_root}"
    else
        # We handle the error manually
        # shellcheck disable=SC2310
        if ! exec_privileged mkdir -p -- "${mask_root}"; then
            error_exit "Failed to create directory: ${mask_root}"
        fi
        mask_target="${mask_root}/bcachefs-tools"
    fi

    printf 'Pinning bcachefs-tools version: %s\n' "${matched_version}"

    local tmpfile
    tmpfile="$(mktemp)"
    cat >"${tmpfile}" <<-PIN_IT_DOWN
	# Auto generated ${package} mask to pin kernel-supported version
	>${pinned}
	<${pinned}
	PIN_IT_DOWN

    # Install atomically with install
    # shellcheck disable=SC2310
    if ! exec_privileged install -m 644 "${tmpfile}" "${mask_target}"; then
        rm -f -- "${tmpfile}"
        error_exit "Failed to write pinning masks to: ${mask_target}"
    fi
    rm -f -- "${tmpfile}"
}

# Main entry point of the script
main() {
    check_requirements

    # Identify partition identifier and kernel-supported version
    local fs_id kernel_version available_versions matched_version
    fs_id="$(get_fs_id)"
    kernel_version="$(get_kernel_version "${fs_id}")"
    printf "Kernel-supported bcachefs version: %s\n" "${kernel_version}"

    # Fetch available tool versions and determine version to pin
    get_available_versions available_versions
    matched_version="$(find_matched_version "${kernel_version}" "${available_versions[@]}")"

    # Warn if falling back to kernel version without an exact match
    if [[ ${matched_version} != "${kernel_version}" ]]; then
        printf "Warning: No matching version found in Portage; using kernel version for mask anyway.\n"
    fi

    # Pin the version
    pin_version "${matched_version}"
    printf "Done. Portage will now refuse to install newer versions of bcachefs-tools.\n"
}

# if this file is being sourced, `return 0` will succeed;
# if it's being executed, the subshell `return` will fail
if ! (return 0 2>/dev/null); then
    main "$@"
fi
