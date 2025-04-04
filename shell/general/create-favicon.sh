#!/usr/bin/env bash
set -e

function display_help() {
  cat <<EOF
  Usage $0 -i input.svg -o output.ico [-h]

    -i, --input       Input SVG file name
    -o, --output      Output ICO file name
    -h, --help        Display this help message

    This script converts converts an SVG file to multiple PNG sizes, optimizes them, and combines them into an .ico file using Inkscape, pngquant, and ImageMagick.

    Example:
      $0 -i logo.svg -o favicon.ico
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -i | --input)
      INPUT_FILE="$2"
      shift
      ;;
    -o | --output)
      OUTPUT_FILE="$2"
      shift
      ;;
    -h | --help) display_help ;;
    *)
      echo "Unknown parameter passed: $1"
      display_help
      ;;
  esac
  shift
done

# Check for both input and output files
if [[ -z $INPUT_FILE ]] || [[ -z $OUTPUT_FILE ]]; then
  echo "Error: Both input and output files must be specified."
  display_help
fi

# Check if Inkscape, ImageMagick, and pngquant are installed
if ! command -v inkscape >/dev/null 2>&1; then
  echo "Error: Inkscape is not installed. Please install it and try again."
  exit 1
fi

if ! command -v pngquant >/dev/null 2>&1; then
  echo "Error: Pngquant is not installed. Please install it and try again."
  exit 1
fi

if ! command -v convert >/dev/null 2>&1; then
  echo "Error: ImageMagick is not installed. Please install it and try again."
  exit 1
fi

sizes=(16 32 48 64 128 256)

# create a temporary directory for the PNG files
TMP_DIR=$(mktemp -d)

# Loop through each size and export the PNG file
for size in "${sizes[@]}"; do
  inkscape "$INPUT_FILE" --export-type=png --export-width="${size}" --export-filename=- --export-png-color-mode=RGBA_16 | pngquant --ext .png --speed 1 --quality=65-80 - >"${TMP_DIR}/icon_${size}x${size}.png"
done

# Combine PNGs into a single ICO file
convert "${TMP_DIR}/icon_*.png" "$OUTPUT_FILE"

# Clean up temporary directory
rm -r "$TMP_DIR"

echo "ICO file created successfully: $OUTPUT_FILE"
