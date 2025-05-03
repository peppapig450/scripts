#!/usr/bin/env bash

# --- Purpose ---
#
# This script selects a random wallpaper from a user-defined directory, applies a color theme transformation
# using "lutgen", caches the themed result, sets it as the current wallpaper via "swww", and updates a symlink
# for reference. It optionally accepts a theme as a positional argument or falls back to the THEME environment variable.
# Light palettes are excluded by default.

set -euo pipefail


# --- Configuration --

readonly wp_dir="${HOME}/media/Wallpapers" # Source directory for wallpapers
readonly theme_dir="${HOME}/.cache/themed_wallpapers" # Directory for storing themed wallpapers
readonly symlink_path="${HOME}/.config/.wallpaper" # Symlink to the current wallpapers
readonly transition_opts=(--transition-step 40 --transition-fps 60 --transition-type center) # swww transition settings

# --- Functions ---

#
# Log informational messages
#
log() {
  printf '[INFO] %s\n' "${1}"
}

#
# Log error messages and exit
#
die() {
  printf '[ERROR] %s\n' "${1}" >&2
  exit 1
}

#
# Check required commands exist
#
check_dependencies() {
  local missing=()

  for cmd in lutgen swww; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    die "Missing required commands: ${missing[*]}"
  fi
}

#
# Create necessary directories
#
init_directories() {
  mkdir -p "${theme_dir}"
}

#
# Get available dark-themed palettes from lutgen
#
get_available_themes() {
  lutgen palette names | grep -vE '(-light|-dawn|papercolor-light|solarized-light|zenwritten-light|catppuccin-latte)'
}

#
# Randomly pick a wallpaper from the specified directory
#
pick_random_wallpaper() {
  shopt -s nullglob globstar
  local wallpapers=("${wp_dir}"/**/*.{jpg,jpeg,png,gif,heif,webp,avif})

  (( ${#wallpapers[@]} > 0 )) || die "No wallpapers found in ${wp_dir}"

  printf '%s\n' "${wallpapers[RANDOM % ${#wallpapers[@]}]}"
}

#
# Validate if the requested theme exists, else pick a random one
#
validate_theme() {
  local requested="${1}"
  local available=("${2}")

  for theme in "${available[@]}"; do
    if [[ ${theme} == "${requested}" ]]; then
      printf '%s\n' "${requested}"
      return
    fi
  done

  local random_theme
  random_theme="$(shuf -n1 -e "${available[@]}")"
  printf '%s\n' "${random_theme}"
}

#
# Apply a color scheme to selected wallpaper, if not already themed
#
apply_theme() {
  local theme="${1}"
  local input_file="${2}"
  local output_file="${3}"

  if [[ ! -f ${output_file} ]]; then
    log "Apply theme '${theme}' to wallpaper."
    lutgen apply -p "${theme}" -o "${output_file}" -S "${input_file}"  # Use Shepards Method with lutgen
  else
    log "Using cached themed wallpaper."
  fi
}

#
# Set the wallpaper using swww and update the symlink
#
set_wallpaper() {
  local file="${1}"
  log "Setting wallpaper."

  swww img "${file}" "${transition_opts[@]}"
  ln -sf "${file}" "${symlink_path}"
}

# --- Main ---

main() {
  check_dependencies
  init_directories

  local output
  output="$(get_available_themes)"
  mapfile -t available_themes <<< "${output}"

  local requested_theme="${1:-${THEME:-}}"
  local theme
  theme="$(validate_theme "${requested_theme}" "${available_themes[*]}")"
  log "Using theme: ${theme}"

  local wallpaper
  wallpaper="$(pick_random_wallpaper)"
  [[ -n ${wallpaper} ]] || die "No wallpapers found in ${wp_dir}"

  local base_name
  base_name="$(basename "${wallpaper}")"

  local themed_file
  themed_file="${theme_dir}/themed_${theme}_${base_name}"

  apply_theme "${theme}" "${wallpaper}" "${themed_file}"
  set_wallpaper "${themed_file}"
}

# Execute the main function
main "$@"
