#!/usr/bin/env bash
# This script cleans up those annoying /tmp/tmp-dir-* directories that some Apple process creates every
# hour and refuses to cleanup. Very rude. Refusing to clean up after yourself in /tmp/ is not acceptable,
# so to rectify the issue we go through and obliterate these miscreant temporary directories. I will
# not have my MacBook's /tmp being a littered mess.
#
# Also note this script needs root permissions to delete the directories.
set -eu # we don't know what shell we are in yet, so use posix defaults

# we early exit here if the bash version is not supported before anything else gets parsed or ran
if ((BASH_VERSINFO[0] > 4)) || { ((BASH_VERSINFO[0] == 4)) && ((BASH_VERSINFO[1] >= 0)); }; then
  : # good to go!
else
  printf "No nameref support = no run; install Bash from homebrew and come back later." >&2
  exit 69
fi

# flip on the bashisms!
set -Eo pipefail

check_environment() {
  if ! command -v rmdir &> /dev/null; then
    printf "rmdir is not installed. Should be impossible since it is installed by default, but here we are." >&2
    exit 1
  fi

  if ((${EUID:-} != 0)); then
    printf "This script needs to be ran as root to delete the temporary directories. Exiting.." >&2
    exit 1
  fi
}

log_to_fd() {
  local level="${1:-INFO}"
  local message="$2"
  local fd="${3:-1}" # Default to stdout

  if [[ -z ${message:-} ]]; then
    echo "No log message provided" >&2
    return 1
  fi

  printf '%(%Y-%m-%d %H:%M:%S)T [%s] %s\n' -1 "$level" "$message" >&"$fd"
}

build_dir_list() {
  local -n _dirs_ref="$1"

  # use -L here because /tmp is symlinked to /private/tmp because.. who knows tbh apple is odd
  # we then pipe to perl for filtering because find's regex is inferior to the crusty demon of PCRE
  mapfile -t _dirs_ref < <(find -L /tmp -maxdepth 1 -type d | perl -nE 'print if /\/tmp-mount-[A-Za-z0-9]{6}$/')
}

remove_dirs() {
  local -n dirs_list="$1"
  local fd="$2"

  ((${#dirs_list[@]})) || {
    log_to_fd "INFO" "Directory list empty. Nothing more to do here." "$fd"
    return 1
  }

  local -i count=0
  for dir in "${dirs_list[@]}"; do
    # we use rmdir because it doesnt nuke non-empty directories in case something is actually using these
    # temporary directories when this script is ran. however, theoretically if this is ran as the directories are
    # created and somehow we delete the directory before the process does whatever it does in there, which would be
    # considered bad normally, but i dont really care because its an apple process and i dont want it littering.
    if rmdir -- "$dir" 2> /dev/null; then
      log_to_fd "INFO" "Removed directory: $dir" "$fd"
      ((++count))
    else
      log_to_fd "ERROR" "Failed to remove directory: $dir" "$fd"
    fi
  done

  log_to_fd "INFO" "Successfully terminated $count directories. Cleanliness restored." "$fd"
}

main() {
  # mute shellcheck because it's been 10 years and it still cannot figure out namerefs
  # shellcheck disable=SC2034
  local -a dirs=()

  exec {fd}>> /var/log/cleanup-tmp-mounts.log

  check_environment && log_to_fd "INFO" "Starting the cleansing purification of /tmp from the thralls of Apple" "$fd"

  build_dir_list dirs
  remove_dirs dirs "$fd"

  log_to_fd "INFO" "Cleansing complete. Have a fantastic day." "$fd"

  # bash guarantees this to be numeric so we dont need to quote
  exec ${fd}>&-
}

# do not run this when being sourced
if ! (return 0 2> /dev/null); then
  main "$@"
fi
