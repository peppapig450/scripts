#!/usr/bin/env bash

# Script to extract files from a ZIP archive and compress them with zstd
# Optimized for larger files with multithreading and better progress feedback
# Usage: ./zip2zstd <zip_file> <output_directory> [compression_level] [--dry-run] [--threads N]

set -e # Exit immediately if a command exits with a non-zero status

# Process command line arguments
zip_file=""
output_dir=""
compression_level="3" # Default compression level
threads=$(nproc)      # Default to number of CPU cores
dry_run=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      dry_run=true
      shift
      ;;
    -h | --help)
      show_usage=true
      shift
      ;;
    -l | --level)
      compression_level="$2"
      shift 2
      ;;
    -t | --threads)
      threads="$2"
      shift 2
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "${zip_file}" ]]; then
        zip_file="$1"
      elif [[ -z "${output_dir}" ]]; then
        output_dir="$1"
      elif [[ "$1" =~ ^[0-9]+$ ]] && [[ -z "${custom_level}" ]]; then
        compression_level="$1"
        custom_level=true
      else
        echo "Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

# Function to display usage information
show_usage() {
  declare script_name
  declare default_threads

  script_name="$(basename -- "${BASH_SOURCE[0]}")"
  default_threads="$(nproc)" || "unknown"

  cat <<USAGE
Usage: ${script_name} <zip_file> <output_directory> [compression_level] [options]

Arguments:
  zip_file          Path to the ZIP file to process
  output_directory  Directory where compressed files will be saved
  compression_level Optional: zstd compression level (1-19, default: 3)

Options:
  --dry-run         Show what would be done without extracting or compressing
  -h, --help        Display this help message
  -l, --level N     Specify compression level (alternative syntax)
  -t, --threads N   Number of threads for zstd (default: ${default_threads})

Examples:
  ${script_name} archive.zip ./output
  ${script_name} archive.zip ./output 6 --threads 4
  ${script_name} archive.zip ./output --dry-run
  ${script_name} archive.zip ./output -l 9 -t 8 --dry-run
USAGE
}

# Show usage if requested
if [[ "${show_usage:-false}" = true ]]; then
  show_usage
  exit 0
fi

# Check if required commands are available
check_requirements() {
  local missing_tools=()

  for cmd in unzip zipinfo zstd nproc; do
    if ! command -v "${cmd}" &>/dev/null; then
      missing_tools+=("${cmd}")
    fi
  done

  if [[ ${#missing_tools[@]} -ne 0 ]]; then
    echo "Error: The following required tools are missing:"
    for tool in "${missing_tools[@]}"; do
      echo "  - ${tool}"
    done
    echo "Please install them and try again."
    exit 1
  fi
}

# Calculate expected file size based on original size and compression level (rough estimate)
estimate_compressed_size() {
  local original_size=$1
  local level=$2

  case ${level} in
    [1-3]) ratio=0.55 ;;    # ~45% reduction
    [4-6]) ratio=0.45 ;;    # ~55% reduction
    [7-9]) ratio=0.40 ;;    # ~60% reduction
    [1][0-9]) ratio=0.35 ;; # ~65% reduction
    *) ratio=0.50 ;;        # default
  esac

  echo $((original_size * ratio))
}

# Get human readable size
human_readable_size() {
  local size=$1
  local units=("B" "KB" "MB" "GB" "TB")
  local unit=0

  while ((size > 1024 && unit < 4)); do
    size=$((size / 1024))
    ((unit++))
  done

  echo "${size} ${units[${unit}]}"
}

# Validate inputs
validate_inputs() {
  if [[ -z "${zip_file}" ]] || [[ -z "${output_dir}" ]]; then
    show_usage
    exit 1
  fi

  if [[ ! -f "${zip_file}" ]]; then
    echo "Error: ZIP file '${zip_file}' not found."
    exit 1
  fi

  if ! [[ "${compression_level}" =~ ^[0-9]+$ ]] || [[ "${compression_level}" -lt 1 ]] || [[ "${compression_level}" -gt 19 ]]; then
    echo "Error: Invalid compression level. Please specify a number between 1 and 19."
    exit 1
  fi

  if ! [[ "${threads}" =~ ^[0-9]+$ ]] || [[ "${threads}" -lt 1 ]]; then
    echo "Error: Invalid thread count. Please specify a positive integer."
    exit 1
  fi

  # Test ZIP integrity
  if ! unzip -t "${zip_file}" &>/dev/null; then
    echo "Error: ZIP file '${zip_file}' appears to be corrupted."
    exit 1
  fi
}

# Process the zip file
process_zip() {
  local total_files
  local processed=0
  local failed=0
  local skipped=0
  local total_size=0
  local estimated_compressed_size=0

  if [[ ! -d "${output_dir}" ]] && [[ "${dry_run}" = false ]]; then
    mkdir -p "${output_dir}" || {
      echo "Error: Failed to create output directory '${output_dir}'."
      exit 1
    }
    echo "Created output directory: ${output_dir}"
  elif [[ ! -d "${output_dir}" ]]; then
    echo "[DRY RUN] Would create directory: ${output_dir}"
  fi

  echo "Analyzing ZIP file content..."
  mapfile -t zip_files < <(zipinfo -1 "${zip_file}")

  if [[ "${dry_run}" = true ]]; then
    mapfile -t zip_details < <(unzip -l "${zip_file}" | tail -n +4 | head -n -2)
  fi

  total_files=${#zip_files[@]}

  echo "Found ${total_files} files in '${zip_file}'"
  echo "Using zstd compression level: ${compression_level}, threads: ${threads}"

  if [[ "${dry_run}" = true ]]; then
    echo "Running in DRY RUN mode - no files will be extracted or compressed"
    echo "----------------------------------------------------------------"
    printf "%-10s %-10s %-10s %s\n" "SIZE" "EST. ZSTD" "SAVINGS" "FILENAME"
    echo "----------------------------------------------------------------"
  else
    echo "Processing files... (Progress updates every second)"
  fi

  # Process each file
  local last_update=0
  for i in "${!zip_files[@]}"; do
    file="${zip_files[${i}]}"

    if [[ "${file}" == */ ]]; then
      ((skipped++))
      continue
    fi

    output_file="${output_dir}/${file}.zst"
    output_dir_path=$(dirname "${output_file}")

    if [[ "${dry_run}" = true ]]; then
      details_line="${zip_details[${i}]}"
      if [[ "${details_line}" =~ ^[[:space:]]*([0-9]+) ]]; then
        file_size="${BASH_REMATCH[1]}"
        estimated_size=$(estimate_compressed_size "${file_size}" "${compression_level}")
        savings=$((file_size - estimated_size))
        savings_percent=$((savings * 100 / file_size))

        total_size=$((total_size + file_size))
        estimated_compressed_size=$((estimated_compressed_size + estimated_size))

        printf "%-10s %-10s %-9s%% %s\n" \
          "$(human_readable_size "${file_size}")" \
          "$(human_readable_size "${estimated_size}")" \
          "${savings_percent}" \
          "${file}"
      else
        echo "  Unknown size: ${file}"
      fi

      if [[ ! -d "${output_dir_path}" ]]; then
        echo "  [DRY RUN] Would create directory: ${output_dir_path}"
      fi

      ((processed++))
    else
      if [[ ! -d "${output_dir_path}" ]]; then
        mkdir -p "${output_dir_path}" || {
          echo "Error: Failed to create directory '${output_dir_path}'."
          ((failed++))
          continue
        }
      fi

      # Update progress periodically (every second)
      current_time=$(date +%s)
      if ((current_time - last_update >= 1)); then
        echo -ne "Processed: ${processed}/${total_files} files, Failed: ${failed}, Skipped: ${skipped}\r"
        last_update=${current_time}
      fi

      # Extract and compress with multithreading
      if unzip -p "${zip_file}" "${file}" 2>/dev/null | zstd -"${compression_level}" -T"${threads}" >"${output_file}" 2>/dev/null; then
        ((processed++))
      else
        echo "Error compressing: ${file}"
        rm -f "${output_file}" # Clean up partial file
        ((failed++))
      fi
    fi
  done

  # Ensure final progress line is cleared
  if [[ "${dry_run}" = false ]]; then
    echo -ne "\033[K" # Clear the line
  fi

  # Print final summary
  echo -e "\nSummary:"
  if [[ "${dry_run}" = true ]]; then
    total_savings=$((total_size - estimated_compressed_size))
    savings_percent=$((total_savings * 100 / (total_size > 0 ? total_size : 1)))

    echo "  Total original size:   $(human_readable_size "${total_size}")"
    echo "  Estimated zstd size:   $(human_readable_size "${estimated_compressed_size}")"
    echo "  Estimated space saved: $(human_readable_size "${total_savings}") (${savings_percent}%)"
    echo "  Files to process:      ${processed}"
    echo "  Directories to skip:   ${skipped}"
    echo ""
    echo "This was a DRY RUN. No files were actually processed."
    echo "Run the command without --dry-run to perform the actual conversion."
  else
    echo "  Processed: ${processed} files"
    echo "  Failed: ${failed} files"
    echo "  Skipped: ${skipped} directories"
    echo "Compression complete."
  fi
}

# Main function
main() {
  check_requirements
  validate_inputs
  process_zip
}

# Execute the script
main
