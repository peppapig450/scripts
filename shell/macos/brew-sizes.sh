#!/usr/bin/env bash

# get a list of brew installed formulas
formula_output="$(brew list --formula)"

package_info=()

# process the formulas
while IFS= read -r line; do
    info="$(brew info $line)"
    files="$(echo $info | awk -F '[(,]' '/files/ {print $2}')"
    echo "$files"
    size="$(echo $info | awk -F '[(,]' '/files/ {gsub(/[^a-zA-Z0-9]/, "", $3); print $3}')"
    package_info+=("${files} ${sizes}")

done <<< "${formula_output[@]}"

for info in "${package_info[@]}"; do
    echo "$info"
done