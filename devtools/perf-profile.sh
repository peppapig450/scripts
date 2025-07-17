#!/usr/bin/env bash
# Wrapper script for running `perf record` profiling across multiple datasets.
# Uses `fastp` with fixed arguments and outputs compressed perf.data files.

# TODO: This can be easily extended to run other things or made into a sourcable script
# that can be sourced and have the sourcing script define the args that perf record
# is recording.
set -Eeuo pipefail

build_fastp_args() {
  local -n _args="$1"
  local file_one="$2"
  local file_two="$3"

  local in1_file="$(realpath ../${file_one})"
  local in2_file="$(realpath ../${file_two})"

  _args=(
    --in1 "$in1_file"
    --in2 "$in2_file"
    -c
    -p
    -D
    -x
    -y
    --complexity_threshold 20
    --cut_front
    --cut_tail
    --cut_right
    --cut_window_size 10
    --unqualified_percent_limit 30
    --average_qual 25
    --length_required 50
    -w 3
    --overlap_len_require 30
    --overlap_diff_limit 3
    --allow_gap_overlap_trimming
    -g
    -m
    --merged_out /dev/null
    -2
    -V
  )
}

build_perf_args() {
  local -n _args="$1"
  local run_base="$2"
  local output_dir="$3"
  local timestamp

  timestamp="$(date '+%Y%m%d%H%M%S%3N')"

  output_file="${output_dir}/${run_base}.data.${timestamp}"

  _args=(
    -o
    "$output_file"
    -g
    -s
    --compression-level=13
    -m 1024
    -d
    --call-graph fp
    -e cycles,instructions,cache-references,cache-misses,L1-icache-loads,L1-icache-misses,branch-instructions,branch-misses,L1-dcache-loads,L1-dcache-load-misses,dTLB-load-misses,dTLB-loads,stalled-cycles-frontend
  )
}

main() {
  local run_name="$1"

  if [[ -z ${run_name:-} ]]; then
    printf "Run name for this batch needed."
    exit 1
  fi

  local output_dir="perf_runs/${run_name}"
  mkdir -p -- "$output_dir"

  local -A to_run=(
    ["nova"]="nova.R1.fq.gz:nova.R2.fq.gz"
    ["DRR144929"]="DRR144929_1.fastq.gz:DRR144929_2.fastq.gz"
    ["ERR204044"]="ERR204044_1.fastq.gz:ERR204044_2.fastq.gz"
  )

  for run in "${!to_run[@]}"; do
    printf "\n\n\nRunning profiling for %s\n\n\n" "$run"
    local -a perf_args fastp_args
    build_perf_args perf_args "$run" "$output_dir"

    IFS=":" read -r file_one file_two <<< "${to_run[${run}]}"
    build_fastp_args fastp_args "$file_one" "$file_two"

    doas perf record "${perf_args[@]}" -- ./fastp "${fastp_args[@]}"
  done
}

main "$@"
