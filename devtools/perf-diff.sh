#!/usr/bin/env bash
# Script for batch comparison of perf.data files using `perf diff`.
# Compares matching perf records in two directories for a given symbol
# and saves diff outputs under diff-output/.
set -Eeuo pipefail

usage() {
  echo "Usage: $0 --run1 <path> --run2 <path> --symbol <symbol>"
  exit 1
}

# Parse arguments
RUN1_DIR=""
RUN2_DIR=""
SYMBOL=""
OUT_DIR="diff-output"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run1)
      RUN1_DIR="$2"
      shift 2
      ;;
    --run2)
      RUN2_DIR="$2"
      shift 2
      ;;
    --symbol)
      SYMBOL="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

# Validate inputs
if [[ -z "$RUN1_DIR" || -z "$RUN2_DIR" || -z "$SYMBOL" ]]; then
  usage
fi

# Create output directory
OUT_DIR="diff-output/$(basename "$RUN1_DIR")-vs-$(basename "$RUN2_DIR")"
mkdir -p "$OUT_DIR"

# Map from prefix (e.g., ERR204044.data) to full path for run2
declare -A RUN2_FILES

for file2 in "$RUN2_DIR"/*.data.*; do
  base2=$(basename "$file2")
  prefix2="${base2%%.data.*}.data"
  RUN2_FILES["$prefix2"]="$file2"
done

# Iterate through run1 files, try to find match in run2 by prefix
for file1 in "$RUN1_DIR"/*.data.*; do
  base1=$(basename "$file1")
  prefix1="${base1%%.data.*}.data"

  if [[ -n "${RUN2_FILES[$prefix1]:-}" ]]; then
    file2="${RUN2_FILES[$prefix1]}"
    outfile="$OUT_DIR/${prefix1// /_}-${SYMBOL//:/_}.diff"

    echo "Comparing $base1 ↔ $(basename "$file2") for symbol '$SYMBOL'"
    doas perf diff --percentage=absolute -S "$SYMBOL" "$file1" "$file2" | tee "$outfile"
  else
    echo "Warning: No matching file in run2 for $base1"
  fi
done
