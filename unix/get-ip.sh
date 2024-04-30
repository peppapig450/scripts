#!/usr/bin/env bash

# =========================================================================
#
# Getting both internal and external IP addresses used for outgoing
# Internet connections.
#
# Internal IP address is the IP address of your computer network interface
# that would be used to connect to Internet.
#
# External IP address is the IP address that is visible by external
# servers that you connect to over Internet.
#
# Copyright (C) 2024 peppapig450 - Nick
#
# =========================================================================

# TODO: add ipv6 functionality
# TODO: test on bsd

show_usage() {
  cat - <<HELP
USAGE
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Display the internal and/or external IP addresses

OPTIONS
    -i  Display the internal IP address
    -e  Dispaly the external ip address
    -v  Turn on verbosity
    -h  Display this help and exit
HELP
  exit
}

die() {
  echo "$(basename "$0"): $@" >&2
  exit 2
}

# =========================================================================

show_internal=""
show_external=""
show_verbose=""

while getopts ":ievh" opt; do
  case "$opt" in
    i)
      show_internal=1
      ;;
    e)
      show_external=1
      ;;
    v)
      show_verbose=1
      ;;
    h)
      show_usage
      ;;
    \?)
      die "Illegal option: $OPTARG"
      ;;
  esac
done

if [ -z "$show_internal" ] && [ -z "$show_external" ]; then
  show_internal=1
  show_external=1
fi

# =========================================================================

# Use Google's public DNS to resolve the internal IP address
[ -n "$TARGETADDR" ] || TARGETADDR="8.8.8.8"

# Query the specific URL to resolve the external IP address
[ -n "$IPURL" ] || IPURL="ipecho.net/plain"

# Define explicitly $IPCMD to gather $IPURL using another tool
[ -n "$IPCMD" ] || {
  if command -v curl >/dev/null 2>&1; then
    IPCMD="curl -s"
  elif command -v wget >/dev/null 2>&1; then
    IPCMD="wget -qO -"
  elif command -v fetch >/dev/null 2>&1; then
    IPCMD="fetch -qo -"
  else
    die "Neither curl, wget, nor fetch installed"
  fi
}

# =========================================================================

internalip() {
  [ -n "$show_verbose" ] && printf "Internal: "

  case "$(uname | tr '[:upper:]' '[:lower:]')" in
    cygwin* | mingw* | msys*)
      netstat -rn \
        | grep -w '0.0.0.0' \
        | awk '{ print $4 }'
      return
      ;;
  esac

  ip route get "$TARGETADDR" \
    | awk -F"src " 'NR==1{split($2,a," ");print a[1]}'
}

externalip() {
  [ -n "$show_verbose" ] && printf "External: "

  eval "$IPCMD $IPURL $IPOPEN"
}

# =========================================================================

[ -n "$show_internal" ] && internalip
[ -n "$show_external" ] && externalip

# =========================================================================

# EOF
