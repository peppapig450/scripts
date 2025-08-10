#!/usr/bin/env bash
set -e

# Make sure the dpkg-query command is available (check if we're on a debian based system)
if ! command -v dpkg-query >/dev/null 2>&1; then
	echo "'dpkg-query' not available. Are you on a Debian based distro?"
	exit 1
fi

# Default variable values
PACKAGE_NAME=""
LIST=false
SUMMARIZE=false
BOTH=false


# Function to  display usage information
usage() {
	cat << EOF
Usage: $(basename "${BASH_SOURCE[0]}") -p <package_name> [-h] [-l | -s | -b]
	-h			Displays this help.
	-p <package_name>	Specify the package to examine.
	-l			List each file with its type.
	-s 			Summarize the file types by number and type.
	-b			Both list and summarize the file types.
EOF
	exit 1
}

# Function to list files and their types
list_files() {
	while read -r file; do
		if [[ -f "${file}" ]]; then
			file -L "$file"
		fi
	done < <(dpkg-query -L "$PACKAGE_NAME")
}

#TODO: not working as of right now
# Function to summarize file types
summarize_files() {
	# Use an associative (key, value) array to store the unique file types
	declare -A file_types

	while read -r file; do
		if [[ -f "${file}" ]]; then
			file_type="$(file -L "$file" | cut -d: -f2- | xargs)"
			((file_types["$file_type"]++))
		fi
	done < <(dpkg-query -L "$PACKAGE_NAME")

	for file_type in "${!file_types[@]}"; do
		echo "${file_types[$file_type]} $file_type"
	done | sort -nr
}

while getopts "hp:lsb" opt; do
	case $opt in
		h)
			usage
			;;
		p)
			PACKAGE_NAME="$OPTARG"
			;;
		l)
			LIST=true
			;;
		s)
			SUMMARIZE=true
			;;
		b)
			BOTH=true
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2; exit 1
			;;

		*)
			usage
			;;
	esac
done

# Check to make sure (-p) is used and that the passed package name is valid
if [[ -n "${PACKAGE_NAME}" ]]; then
	if ! dpkg-query -l "$PACKAGE_NAME" >/dev/null 2>&1; then
		printf "Error: Package '%s' not found, make sure it's installed and you spelled correctly.\n" "${PACKAGE_NAME}" >&2
		exit 1
	fi
else
	echo "Error: Missing required argument -p (package name)" >&2
	usage
fi

# Make sure a formatting option is passed
if [[ "${LIST}" = false ]] && [[ "${SUMMARIZE}" = false ]] && [[ "${BOTH}" = false ]]; then
	echo "Error: at least one of these options (-l, -s, -b) must be specified." >&2
	usage
fi

# Mutually exclude the list and summarize, if passed tell user to use (-b)
if [[ "${LIST}" = true ]] && [[ "${SUMMARIZE}" = true ]]; then
	echo "Error: to list and summarize use (-b) not (-l and -p)." >&2
	usage
fi

# Main script logic
if [[ "${LIST}" = true ]]; then
	list_files
fi

if [[ "${SUMMARIZE}" = true ]]; then
	summarize_files
fi

if [[ "${BOTH}" = true ]]; then
	echo "Individual File Types:"
	list_files
	echo "\nSummary of File Types:"
	summarize_files
fi
