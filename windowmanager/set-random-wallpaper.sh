#!/usr/bin/env bash

# --- Purpose ---
#
# This script selects a random wallpaper from a user-defined directory, applies a color theme transformation
# using "lutgen", caches the themed result, sets it as the current wallpaper via "swww", and updates a symlink
# for reference. It optionally accepts a theme as a positional argument or falls back to the THEME environment variable.
# Light palettes are excluded by default.

set -Eeuo pipefail

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

populate_paths() {
  local -n paths="$1"

  paths=(
    ["config_home"]="${XDG_CONFIG_HOME:-${HOME}/.config}"
    ["cache_home"]="${XDG_CACHE_HOME:-${HOME}/.cache}"
    ["wp_dir"]="${XDG_DATA_HOME:-${HOME}/.local/share}/wallpapers/unthemed"
    ["cache_dir"]="${XDG_DATA_HOME:-${HOME}/.local/share}/wallpapers/themed"
    ["symlink_path"]="${XDG_CONFIG_HOME}/.wallpaper"
  )
}

#
# Check required commands exist
#
check_dependencies() {
  local -a missing=()

  for cmd in lutgen swww; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      missing+=("${cmd}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    die "Missing required commands: ${missing[*]}"
  fi
}

#
# Create necessary directories
#
create_theme_cache() {
  local -n paths_ref="$1"
  local theme_name="$2"

  local cache_dir="${paths_ref[cache_dir]}"
  local theme_cache="${cache_dir}/${theme_name}"

  mkdir -p -- "${theme_cache}"
  paths_ref[theme_cache]="$theme_cache"
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
  local -a wallpapers

  # Use compgen -G + extglob for fast case-insensitive globbing
  shopt -s -- extglob
  mapfile -t wallpapers < <(compgen -G -- \
    "${wp_dir}/**/*.+(j|J)p?(e|E)g" \
    "${wp_dir}/**/*/*.{png,gif,webp,heic,heif,avif}")

  ((${#wallpapers[@]} > 0)) || die "No wallpapers found in ${wp_dir}"

  shopt -u -- extglob
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
    lutgen apply -p "${theme}" -o "${output_file}" -S "${input_file}" # Use Shepards Method with lutgen
  else
    log "Using cached themed wallpaper."
  fi
}

#
# Set the wallpaper using swww and update the symlink
#
set_wallpaper() {
  local file="$1"
  local symlink_path="$2"

  log "Setting wallpaper."
  local -a transition_opts=(--transition-step 40 --transition-fps 60 --transition-type center)

  swww img "${file}" "${transition_opts[@]}"
  ln -sf "${file}" "${symlink_path}"
}

# --- Main ---

# TODO: preselect 5 themes to apply lutgen to, and then select from that cache, add a new wallpaper
# and so on.

main() {
  local -A paths
  populate_paths paths

  check_dependencies
  init_directories

  local output
  output="$(get_available_themes)"
  mapfile -t available_themes <<<"${output}"

  local requested_theme="${1:-${THEME:-}}"
  local theme
  theme="$(validate_theme "${requested_theme}" "${available_themes[*]}")"
  log "Using theme: ${theme}"

  create_theme_cache paths theme

  local wallpaper
  wallpaper="$(pick_random_wallpaper)"
  [[ -n ${wallpaper} ]] || die "No wallpapers found in ${wp_dir}"

  local base_name
  base_name="$(basename "${wallpaper}")"

  local themed_file
  themed_file="${paths[theme_cache]}/themed_${theme}_${base_name}"

  apply_theme "${theme}" "${wallpaper}" "${themed_file}"
  set_wallpaper "${themed_file}"
}

# Execute the main function
main "$@"
