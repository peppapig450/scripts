#!/bin/bash
set -eu

# Enable globstar and extglob to use later for finding the script
shopt -s globstar

# Default values
DEFAULT_BIN_DIR="$HOME/.local/bin"
BIN_DIR="$DEFAULT_BIN_DIR"
PYTHON_SCRIPT_NAME=""
PYTHON_SCRIPT_PATH=""
USE_RELATIVE=false

# Function to display usage information
usage() {
    echo "Usage: $0 -s <script_name> -p <script_path> [-d <bin_directory>] [-r]"
    echo "  -s  Name of the Python script (without .py extension)"
    echo "  -p  Path to the Python script (can be relative or absolute)"
    echo "  -d  Directory to place the wrapper script or symlink (default: $DEFAULT_BIN_DIR)"
    echo "  -r  Use relative path and create a symlink in the specified directory"
    exit 1
}

# Function to check if the bin dir exists and is in the path
verify_bin_dir() {
    local TARGET_DIR="$1"
    
    if [[ ! -d $TARGET_DIR ]]; then
        echo "${TARGET_DIR} doesn't exist, exiting."
        return 1
    fi
    
    if [[ $PATH =~ :$TARGET_DIR: ]]; then
        return 0
    else
        echo "$TARGET_DIR exists, but is not in the \$PATH"
        return 1
    fi
}

# Parse command-line options
while getopts ":s:p:d:r" opt; do
    case $opt in
        s)
            PYTHON_SCRIPT_NAME=$OPTARG
        ;;
        p)
            PYTHON_SCRIPT_PATH=$OPTARG
        ;;
        d)
            BIN_DIR=$OPTARG
        ;;
        r)
            USE_RELATIVE=true
        ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
        ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
        ;;
    esac
done

# Check if the script name and path are provided
if [[ -z $PYTHON_SCRIPT_NAME ]] || [[ -z $PYTHON_SCRIPT_PATH ]]; then
    echo "Error: Script name and script path are requried."
    usage
fi

# If bin directory doesn't exist and isn't in $PATH, exit.
# TODO: functionality to automatically crete an add to path maybe with an input read -p
if ! verify_bin_dir "$BIN_DIR"; then
    exit 1
fi

# Find the script specified using globbing, and get the realpath
if [[ ! -f "${PYTHON_SCRIPT_PATH}/${PYTHON_SCRIPT_NAME}.py" ]]; then
    
    # Glob for script with .py extension in current dir and subdirectories
    shopt -s nullglob
    FOUND_SCRIPT=("$PYTHON_SCRIPT_PATH"/**/"${PYTHON_SCRIPT_NAME}.py")
    shopt -u nullglob
    
    # Check if the script is found
    if [[ ${#FOUND_SCRIPT[@]} -eq 0 ]]; then
        echo "Error: Python script '$PYTHON_SCRIPT_NAME' not found in the target directory."
        exit 1
    else
        ABSOLUTE_SCRIPT_PATH=$(realpath "${FOUND_SCRIPT[0]}")
    fi
else
    ABSOLUTE_SCRIPT_PATH=$(realpath "${PYTHON_SCRIPT_PATH}/${PYTHON_SCRIPT_NAME}.py")
fi

# Location for the wraper script
WRAPPER_SCRIPT_PATH="${BIN_DIR}/${PYTHON_SCRIPT_NAME}"

# If using relative path, create a symlink from the script we're wrapping around to the bin dir, and then the wrapper script
if $USE_RELATIVE; then
    SYMLINK_PATH="${BIN_DIR}/${PYTHON_SCRIPT_NAME}.py"
    ln -sfrn "${ABSOLUTE_SCRIPT_PATH}" "$SYMLINK_PATH"
    echo "Symlink created at $SYMLINK_PATH"
    
    # if symlink is created use the symlink as the absolute path for wrapper script
    if [[ -L  $SYMLINK_PATH ]]; then
        ABSOLUTE_SCRIPT_PATH="$SYMLINK_PATH"
    fi
fi

if command -v python >/dev/null 2>&1; then
    PYTHON_EXEC="python"
else
    PYTHON_EXEC="python3"
fi

# Create the wrapper script
cat << EOF > "$WRAPPER_SCRIPT_PATH"
#/usr/bin/env bash
"$PYTHON_EXEC" "$ABSOLUTE_SCRIPT_PATH" "\$@"
EOF

# Make the wrapper script executable
chmod u+x "$WRAPPER_SCRIPT_PATH"

echo "Wrapper script created for $PYTHON_SCRIPT_NAME at $WRAPPER_SCRIPT_PATH"