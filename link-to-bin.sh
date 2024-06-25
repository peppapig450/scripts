#!/usr/bin/env bash
# Script to link all the scripts to ~/.local/bin to be on PATH

# TODO: Maybe add ability to change target dir.

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2>/dev/null); then
  # A better class of script...
  set -o errexit  # Exit on most errors (see the manual)
  set -o nounset  # Disallow expansion of unset variables
  set -o pipefail # Use last non-zero exit code in a pipeline
  set -o noclobber
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# pre check if ~/.local/bin exists and is in path or not and handle creation
DIR="$HOME/.local/bin"

function handle_path() {
	DIR="$1"
	if [[ ":$PATH:" == *":${DIR}:"* ]]; then
        	echo "${DIR} already in \$PATH, continuing."
    	else
        	echo "${DIR} not found in \$PATH"
        	read -rp "Do you want to add it to your PATH? 'y' or 'n': " answer
        	if [[ "$answer" == "y" ]]; then
            		echo "export PATH=$DIR:\$PATH" >> "$HOME/.bashrc"
            		echo "Run 'source ~/.bashrc' after this is done to make sure $DIR is in the PATH"
        	elif [[ "$answer" == "n" ]]; then
            		echo "There's no point in linking to $DIR if it's not in path..."
            		echo "Run 'export $PATH=$DIR:$PATH' on the command line for temporary adding to PATH"
        	else
            		echo "Invalid input please enter 'y' or 'n'"
			exit 1
        	fi
	fi
}

function link_scripts_to_bin() {
	# enable globbing things to make looping easier
	shopt -s globstar failglob nocaseglob

	# loop through all files in the SCRIPT_DIR utilizing globstar
	for script in "${SCRIPT_DIR}"/** ; do
		# only operate on files that are executable and skip directories
		# TODO: Maybe in the future automatically make executable OR add to list then print at the end non executable files
		if [[ -x "$script" ]] && [[ -f "$script" ]] ; then
			# Remove extension from script so we can call it without adding extension
			filename="${DIR}/$(basename ${script%.*})"
			# link script to bin 
			# TODO: investigate using ln -v
			ln -srn "${script}" "${filename}"
			
			# print message depending on success or failure of symlinking
			if [[ $? -eq 0 ]]; then
				echo "Created symlink ${script} -> ${filename}"
			else
				echo "Something went wrong symlinking ${script} to ${filename}"
			fi
		fi
	done
	# unset because we're done
	shopt -u globstar failglob nocaseglob
}

# if directory exists handle path stuff then symlink
if [[ -d "$DIR" ]]; then
	handle_path "$DIR"
	link_scripts_to_bin
else
	# ask user if they want to create DIR, if yes handle path things and symlink
	# if not exit the script
	read -rp "Would you like to create ${DIR} ? ('y' or 'n'): " create
	if [[ "$create" == "y" ]]; then
		mkdir -pv "$DIR"
		handle_path "$DIR"
		link_scripts_to_bin
	elif [[ "$create" == "n" ]]; then
		echo "Exiting.."
		exit 1
	fi
fi
