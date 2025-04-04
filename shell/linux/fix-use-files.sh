#!/usr/bin/env bash

declare -a pkgs
readarray -t pkgs < <(rg --files-without-match ">=" /etc/portage/package.use)

for pkg in "${pkgs[@]}" ; do
	check="${pkg##*/}"
	sub=$(eix-installed -a | grep "$check")
	
	if [[ -z "$sub" ]]; then
		continue
	else
		final_sub=">=$sub"
		echo "$final_sub"
	fi
done
