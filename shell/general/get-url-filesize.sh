#!/usr/bin/env bash

# ==============================================================================
# fetch_file_size.sh — Fetch the file size of a URL in a robust, logged manner
#
# Requirements:
#   - Bash 4.x+
#   - curl, awk, bc
#   - logging.shlib in the same directory (or adjust path as needed)
#
# This script:
#   - Validates the input URL
#   - Follows redirects to get final headers
#   - Extracts the HTTP status and Content-Length
#   - Downloads the file as a fallback to get size if necessary
#   - Logs every step using logging.shlib (timestamped, color-coded)
# ==============================================================================
set -Eeuo pipefail

# Resolve path to this script (even if it's symlinked)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the logging library for color-coded, timestamped log output and error handling.
# Make sure this path points to your logging.shlib file.
LOGGING_PATH="${SCRIPT_DIR}/logging.shlib"
# Check and source the logging library
if [[ -f ${LOGGING_PATH} ]]; then
  # shellcheck source=./logging.shlib
  source "${LOGGING_PATH}"
else
  printf "Something went wrong sourcing the logging lib: %s\n" "${LOGGING_PATH}" >&2
  exit 1
fi

# Set up a robust error trap that logs uncaught errors with file/line context.
logging::add_err_trap

# usage: Show usage info and exit.
usage() {
  cat <<-CONTENT_LENGTH_MAYBE
  Usage: $0 <url>

  Fetches the final content size for the given URL.
  Will try to use Content-Length or fall back to download if needed.

  Example:
    $0 https://example.com/file.zip
CONTENT_LENGTH_MAYBE
  exit 1
}

# check_requirements: validate the tools we need are installed
check_requirements() {
  local -a missing

  for cmd in curl perl awk; do
    command -v "${cmd}" >/dev/null 2>&1 || missing+=("${cmd}")
  done

  if ((${#missing[@]} > 0)); then
    logging::log_fatal "Missing required command(s): ${missing[*]}"
  fi
}

# validate_url: Checks that a URL starts with valid schema by comparing
# it against schemas the curl version supports.
validate_url() {
  local url="${1}"
  local protocols

  protocols="$(curl --version | grep '^Protocols:' | cut -d' ' -f2-)"

  perl -Mstrict -Mwarnings -e '
    use feature "say";

    my ($url, $protocols) = @ARGV;

    # Parse the scheme (protocol)
    my ($scheme) = $url =~ m{^([a-zA-Z][a-zA-Z0-9+.-]*)://};

    # Build hash of supported protocols
    my %supported = map { $_ => 1 } split(/\s+/, $protocols // "");

    unless ($scheme && $supported{$scheme}) {
      say STDERR "Unsupported or missing URL scheme: '"'"'$scheme'"'"'";
      exit 1;
    }
  ' "${url}" "${protocols}" || logging::log_fatal "Invalid or unsupported URL: ${url}"
}

# fetch_final_headers: Uses curl to get the final headers after redirects
# Args: $1 = URL
# Output: Raw HTTP headers to stdout
fetch_final_headers() {
  local url="${1}"

  if ! curl -sSLI --max-time 30 --retry 3 -- "${url}"; then
    logging::log_fatal "curl failed to fetch headers from: ${url}"
  fi
}

# get_status_code: Extracts HTTP status code from headers (expects HTTP/1.x 200 ...)
# Reads from stdin, outputs status code
# NOTE: this does NOT work for following redirects
get_status_code() {
  env LC_ALL=C awk 'NR==1 {print $2}'
}

# get_content_length: Extracts Content-Length header (case-insensitive) from headers
# Reads from stdin, outputs value
get_content_length() {
  env LC_ALL=C awk -F ': ' 'tolower($1) == "content-length" {print $2; exit}'
}

# download_size_fallback: Uses curl to get the download size if Content-Length missing
# Args: $1 = URL
# Output: Size in bytes
download_size_fallback() {
  local url="${1}"

  curl -sSL --max-time 30 --retry 3 --output /dev/null --write-out "%{size_download}" -- "${url}"
}

# format_size: Prints a human-readable size (GB, MB, KB, TB, PB, bytes)
# Args: $1 = size in bytes
format_size() {
  local bytes="${1:-0}"

  # Try GNU numfmt first (homebrew installs it under gnumfmt)
  if command -v numfmt >/dev/null 2>&1; then
    command numfmt --to=iec --format="%.2f" -- "${bytes}"
  elif command -v gnufmt >/dev/null 2>&1; then
    command gnumfmt --to=iec --format="%.2f" -- "${bytes}"
  else
    # Fallback: manual loop + awk
    local -a suffixes=(bytes KB MB GB TB PB)
    local idx=0
    local count="${bytes}"
    local scaled

    # keep dividing until it's <1024 or we run out of suffixes
    while ((count >= 1024 && idx < ${#suffixes[@]} - 1)); do
      count=$((count / 1024))
      ((idx++))
    done

    # scale original bytes by 1024^idx
    scaled="$(env LC_NUMERIC=C awk -v b="${bytes}" -v u="${idx}" 'BEGIN{ printf "%.2f", b/(1024^u) }')"

    printf "%s %s\n" "${scaled}" "${suffixes[${idx}]}"
  fi
}

main() {
  # Ensure a URL is provided as argument
  if (($# == 0)); then
    usage
  fi

  local url="${1}"
  local headers status_code file_size_bytes

  validate_url "${url}"
  logging::log_info "Fetch headers for ${url}..."

  # Fetch headers, exit fatally if curl fails
  if ! headers="$(fetch_final_headers "${url}")"; then
    logging::log_fatal "Failed to fetch headers for URL: ${url}"
  fi

  # Extract and check HTTP status code
  status_code="$(get_status_code <<<"${headers}")"
  if ((status_code != 200)); then
    logging::log_warn "HTTP status code: ${status_code} for URL: ${url}"
    exit 1
  fi

  # Try to get Content-Length from headers
  file_size_bytes="$(get_content_length <<<"${headers}" | tr -d '\r')"

  if [[ -z ${file_size_bytes} ]]; then
    logging::log_warn "Content-Length header not found. Trying to determine size by downloading..."
    file_size_bytes="$(download_size_fallback "${url}")"
    if [[ -z ${file_size_bytes:-} || ${file_size_bytes:-} -eq 0 ]]; then
      logging::log_error "Could not determine file size for URL: ${url}"
      exit 1
    fi
  fi

  # Validate Content-Length value is numeric
  if ! [[ ${file_size_bytes} =~ ^[0-9]+$ ]]; then
    logging::log_fatal "Invalid Content-Length value: ${file_size_bytes}"
  fi

  # Print formatted file size to stdout
  format_size "${file_size_bytes}"
}

# Make sure main is only ran if executed and not
# if it is sourced.
if ! (return 0 2>/dev/null); then
  main "$@"
fi
