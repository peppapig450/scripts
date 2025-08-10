#!/usr/bin/env bash
# Script to link all the scripts to a target bin directory (default: ~/.local/bin) to be on PATH

# Only enable these shell behaviours if we're not being sourced
# Approach via: https://stackoverflow.com/a/28776166/8787985
if ! (return 0 2> /dev/null); then
  # A better class of script...
  set -o errexit  # Exit on most errors (see the manual)
  set -o nounset  # Disallow expansion of unset variables
  set -o pipefail # Use last non-zero exit code in a pipeline
  set -o noclobber
fi

# Enable errtrace or the error trap handler will not work as expected
set -o errtrace # Ensure the error trap handler is inherited

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

TARGET_DIR="$HOME/.local/bin"

usage() {
  cat << EOF
Usage: $(basename "$0") [-t target_dir]

-t DIR  Target bin directory (default: $HOME/.local/bin)
-h      Show this help message
EOF
}

while getopts ":t:h" opt; do
  case "$opt" in
    t) TARGET_DIR="$OPTARG" ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

handle_path() {
  local dir="$1"
  if [[ ":$PATH:" == *":${dir}:"* ]]; then
    echo "${dir} already in \$PATH, continuing."
  else
    echo "${dir} not found in \$PATH"
    read -rp "Do you want to add it to your PATH? 'y' or 'n': " answer
    if [[ "$answer" == "y" ]]; then
      echo "export PATH=${dir}:\$PATH" >> "$HOME/.bashrc"
      echo "Run 'source ~/.bashrc' after this is done to make sure ${dir} is in the PATH"
    elif [[ "$answer" == "n" ]]; then
      echo "There's no point in linking to ${dir} if it's not in path..."
      echo "Run 'export PATH=${dir}:\$PATH' on the command line for temporary adding to PATH"
    else
      echo "Invalid input please enter 'y' or 'n'"
      exit 1
    fi
  fi
}

link_scripts_to_bin() {
  # enable globbing things to make looping easier
  shopt -s globstar failglob nocaseglob

  # loop through all files in the SCRIPT_DIR utilizing globstar
  for script in "${SCRIPT_DIR}"/**; do
    # only operate on files that are executable and skip directories
    # TODO: Maybe in the future automatically make executable OR add to list then print at the end non executable files
    if [[ -x "$script" ]] && [[ -f "$script" ]]; then
      # Remove extension from script so we can call it without adding extension
      filename="${TARGET_DIR}/$(basename "${script%.*}")"
      # link script to bin
      # TODO: investigate using ln -v
      if ln -srn "${script}" "${filename}"; then
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
if [[ -d "$TARGET_DIR" ]]; then
  handle_path "$TARGET_DIR"
  link_scripts_to_bin
else
  # ask user if they want to create TARGET_DIR, if yes handle path things and symlink
  # if not exit the script
  read -rp "Would you like to create ${TARGET_DIR} ? ('y' or 'n'): " create
  if [[ "$create" == "y" ]]; then
    mkdir -pv "$TARGET_DIR"
    handle_path "$TARGET_DIR"
    link_scripts_to_bin
  elif [[ "$create" == "n" ]]; then
    echo "Exiting.."
    exit 1
  fi
fi
