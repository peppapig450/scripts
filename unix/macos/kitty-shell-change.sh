#!/usr/bin/env bash
set -eu

usage() {
    echo "Syntax: $0 [-h] [-p] [-s <shell>]"
    echo "For more info on how to run this script run $0 -h"
}

help() {
    cat <<EOF
A script to easily change the shell that kitty launches.

Syntax: $0 [-h] [-p] [-s <shell>]

Options:
-h              Print this help message
-p              Print the current shell that kitty launches.
-s <shell>      Change the shell that kitty launches to <shell>.
-i              Interactively select the shell that kitty launches.
EOF
}

config="{$XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf" # use XDG_CONFIG_HOME if it exists (linux) and fall back to ~/.config if it doesn't
shell_pattern='/shell {print $3}'
possible_shells=("bash" "zsh" "fish" "tcsh" "ksh" "sh" "dash") # Common shells to check for existance

print_current_shell() {
    if [[ -f $config ]]; then
        current_shell=$(awk "$shell_pattern" "$config")
        if [[ -n "$current_shell" ]]; then
            echo "Current shell is $current_shell shell."
        else
            echo "Shell configuration not found in $config"
        fi
    else
        echo "Configuration file $config not found. echo If you have a custom configuration, update the 'config' variable in the script."
        exit 1
    fi
}

change_shell() {
    new_shell="$1"
    if ! command -v "$new_shell" > /dev/null 2>&1; then
        echo "Error: $new_shell is not a valid shell or not installed."
        exit 1
    fi
    
    if [[ -f $config ]]; then
        current_shell=$(awk "$shell_pattern" "$config")
        if [[ -n $current_shell ]]; then
            # specify gawk explcitly for macos and linux compatability
            gawk -v c="$current_shell" -v s="$new_shell" -i inplace '{gsub(c, s); print}' "$config"
            echo "Replaced $current_shell with $new_shell in $config."
        else
            echo "Shell configuration not found in $config."
        fi
    else
        echo "Configuration file $config not found."
    fi
}

select_shell() {
    echo "Available shells on your system:"
    valid_shells=()
    
    for shell in "${possible_shells[@]}"; do
        if command -v "$shell" > /dev/null 2>&1; then
            valid_shells+=("$shell")
        fi
    done
    
    if [ ${#valid_shells[@]} -eq 0 ]; then
        echo "No valid shells found."
        exit 1
    fi
    
    select shell in "${valid_shells[@]}"; do
        if [[ -n "$shell" ]]; then
            change_shell "$shell"
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

[[ $# -eq 0 ]] && usage && exit 0

while getopts "hps:i" arg; do
    case "$arg" in
        s)
            change_shell "${OPTARG}"
        ;;
        p)
            print_current_shell
        ;;
        i)
            select_shell
        ;;
        h)
            help
            exit 0
        ;;
        \?)
            usage
            exit 1
        ;;
    esac
done
