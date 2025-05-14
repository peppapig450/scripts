#!/usr/bin/env bash
# nvim-wrapper.sh - A wrapper for Neovim that restores the cursor to its
# original shape, preventing it from being an ugly block after exit.
set -Eeuo pipefail

# Print the standard ANSI escape sequence to reset the cursor shape.
# This resets the terminal cursor to the default (usually a blinking line).
reset_cursor_sequence() {
    printf '\033[0 q' # Use octal escape for ASCII 27 (ESC) for POSIX compliance
}

# Function: reset_cursor
# Purpose: Heuristically reset the cursor based on $TERM. Works in tmux, and should work in any terminal.
# Attempts to restore cursor using terminfo via 'tput cnorm' where possible.
# If that fails (e.g. minimal env or cursed terminals), falls back to ANSI escape.
reset_cursor() {
    case "${TERM}" in
        linux)
            # Linux virtual console (tty) - try terminfo, fallback to ANSI
            tput cnorm 2>/dev/null || reset_cursor_sequence
            ;;
        tmux*)
            # Special handling for tmux: wrap the escape sequence in a DCS (Device Control String)
            # so tmux forwards it to the underlying terminal.
            # Sequence:  ESC P tmux; ESC ESC [0 q ESC \
            printf "\ePtmux;\e\e[0 q\e\\" # Use \e for readability (non-POSIX but widely supported)
            ;;
        screen* | rxvt* | xterm*)
            # xterm-style terminals - use direct ANSI escape
            reset_cursor_sequence
            ;;
        *)
            # Unknown terminal - try terminfo first, fallback to ANSI
            tput cnorm 2>/dev/null || reset_cursor_sequence
            ;;
    esac
}

# Function: bail
# Purpose: Exit loudly if Neovim is not installed.
bail() {
    printf "Error: 'nvim' not found in PATH. Please install it and try again.\n" >&2
    exit 127
}

# Function: main
# Purpose: Entry point for the wrapper.
main() {
    # Ensure the real nvim is available
    command -pv nvim >/dev/null 2>&1 || bail

    # Always reset the cursor on exit, even on crash
    trap reset_cursor EXIT

    # Resolve the real nvim full path (skipping local scripts (this), using -p to for default PATH)
    real_nvim="$(command -pv nvim)" || bail

    # Hand off the current process to the real Neovim binary (no return)
    exec "${real_nvim}" "$@"
}

main "$@"
