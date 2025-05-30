#!/usr/bin/env bash
# This script updates the metadata cache for all enabled repositories on a Gentoo system.
# It:
# 1) Lists enabled repositories using eselect repository.
# 2) Extracts repo names using Perl.
# 3) Runs egencache in parallel for each repo to update the cache.
#
# Requirements:
# - doas or sudo access for eselect and egencache.
# - eselect, egencache, nproc, and perl available in PATH.
# - Gentoo system using eselect repositories.
set -Eeuo pipefail

# Prints an error message, function name, and line number and
# exits with a provided status (default: 1)
error_exit() {
  local msg="${1}"
  local code="${2:-1}"
  local lineno="${BASH_LINENO[0]}"
  local func_name="${FUNCNAME[1]}"

  printf "Error in %s at line %s: %s\n" "${func_name}" "${lineno}" "${msg}" >&2
  exit "${code}"
}

# Verifies that all required commands are available on PATH
check_requirements() {
  local -n deps_to_verify="${1}"

  for cmd in "${deps_to_verify[@]}"; do
    if ! command -v "${cmd}" > /dev/null 2>&1; then
      error_exit "Missing required command: ${cmd}"
    fi
  done

  if eselect modules list | awk '$1 ~ /^repository$/ {found=1} END {exit !found}'; then
    :
  else
    error_exit "eselect-repository not installed"
  fi
}

# Dynamically detect doas or sudo and run command as root
exec_privileged() {
  if declare -f run_privileged > /dev/null 2>&1; then
    run_privileged "$@"
    return
  fi

  if command -v doas > /dev/null 2>&1; then
    run_privileged() { doas -- "$@"; }
  elif command -v sudo > /dev/null 2>&1; then
    run_privileged() { sudo -- "$@"; }
  else
    echo "No doas or sudo found." >&2
    exit 1
  fi

  run_privileged "$@"
}

update_cache() {
  local -n repo_list="${1}"
  (("${#repo_list[@]}" > 0)) || error_exit "Repository list empty.. Exiting"

  local job_count="$(nproc 2> /dev/null || getconf _NPROCESSORS_ONLN)"

  for repo in "${repo_list[@]}"; do
    printf "Updating cache for repo: %s\n" "${repo}"
    exec_privileged egencache --update -j "${job_count}" --repo "${repo}"
  done
}

main() {
  local -a required_deps=(egencache eselect awk perl)
  local -a repos_list

  check_requirements required_deps
  mapfile -t enabled_repos < <(exec_privileged eselect repository list -i | perl -lane 'print $F[1]=~s/\*//r if @F>2')
  update_cache enabled_repos
}

if ! (return 0 2> /dev/null); then
  main
fi
