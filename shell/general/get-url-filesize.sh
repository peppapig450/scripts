#!/usr/bin/env bash
set -eu

# Check if URL is provided
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <url>"
  exit 1
fi

url="$1"

# Basic URL validation
if [[ ! $url =~ ^https?:// ]]; then
  echo "Error: Invalid URL format. URL must start with http:// or https://"
  exit 1
fi

# Fetch only the final response headers with curl, following redirects
echo "Fetchng headers for $url..."
headers="$(curl -s -I -L --max-time 10 "$url" | awk 'BEGIN {RS="\r\n\r\n"; ORS="\r\n\r\n"} END {print}')"
if [[ $? -ne 0 ]]; then
  echo "Failed to fetch headers for URL: $url"
  exit 1
fi

# Check HTTP status code
status_code=$(echo "$headers" | head -n 1 | cut -d' ' -f2)
if [[ "$status_code" != "200" ]]; then
  echo "HTTP status code: $status_code for URL: $url"
  exit 1
fi

# Extract Content-Length header
file_size_bytes=$(echo "$headers" | grep -i "^content-length:" | awk '{print $2}' | tr -d '\r')

# Check if Content-Length was found
if [[ -z "$file_size_bytes" ]]; then
  echo "Content-Length header not found. Trying to determine size by downloading..."

  # As fallback, use curl with --head and --write-out to get the size
  file_size_bytes=$(curl -sL --max-time 30 --output /dev/null --write-out "%{size_download}" "$url")

  if [[ -z "$file_size_bytes" || "$file_size_bytes" -eq 0 ]]; then
    echo "Could not determine file size for URL: $url"
    exit 1
  fi
fi

# Check if file_size_bytes is a number
if ! [[ "$file_size_bytes" =~ ^[0-9]+$ ]]; then
  echo "Invalid Content-Length value: $file_size_bytes"
  exit 1
fi

# Use bash arithmetic for better performance
file_size_kb=$(awk "BEGIN {printf \"%.2f\", $file_size_bytes/1024}")
file_size_mb=$(awk "BEGIN {printf \"%.2f\", $file_size_bytes/1024/1024}")
file_size_gb=$(awk "BEGIN {printf \"%.2f\", $file_size_bytes/1024/1024/1024}")

# Determine the appropriate unit and print
if (($(echo "$file_size_gb >= 1" | bc -l))); then
  echo "File size: $file_size_gb GB"
elif (($(echo "$file_size_mb >= 1" | bc -l))); then
  echo "File size: $file_size_mb MB"
elif (($(echo "$file_size_kb >= 1" | bc -l))); then
  echo "File size: $file_size_kb KB"
else
  echo "File size: $file_size_bytes bytes"
fi
