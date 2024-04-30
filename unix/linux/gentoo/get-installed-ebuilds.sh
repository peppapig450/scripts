#!/usr/bin/env bash

# TODO: ability to print to command line
# Get a list of installed packages and their corresponding installed files
readarray -t packages < <(equery l -F '\$cp' '*')
readarray -t installed_ebuild_paths < <(equery  w "${packages[@]}")

# Ouput the formatted output to a file
for ((i = 0; i < ${#packages[@]}; i++)); do
	echo "${packages[i]}:  ${installed_ebuild_paths[i]}"
done > "$HOME/stuff/installed-package-ebuilds.txt"
