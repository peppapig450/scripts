#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s extglob shift_verbose

usage() {
  cat <<TAKE_NOTES_CLASS
Usage: $0 -s SYMBOL -i IN_DIR [-o OUT_DIR]

  -s SYMBOL    The symbol to annotate (e.g. Stats::statRead)
  -i IN_DIR     Directory containing perf .data.* files
  -o OUT_DIR    Directory to write annotations (default: annotations)

Example:
  $0 -s Stats::statRead -i perf_runs/use_stl_containers_in_stats -o annotations
TAKE_NOTES_CLASS
  exit 1
}

sanitize() {
  local var="$1"
  var=${var//::/_}           # :: → _
  var=${var,,}               # lowercase
  var=${var//[!a-z0-9_]/_}   # non-[a-z0-9_] → _
  var=${var##+(_)}           # trim leading _
  var=${var%%+(_)}           # trim trailing _

  printf "%s" "$var"
}

# --- parse args ---
OUT_DIR="annotations"

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--symbol)
      SYMBOL="$2"; shift 2;;
    -i|--input)
      IN_DIR="$2"; shift 2;;
    -o|--outdir)
      OUT_DIR="$2"; shift 2;;
    -h|--help)
      usage;;
    *)
      echo "Unknown arg: $1"; usage;;
  esac
done

# sanity checks
if [[ -z ${SYMBOL:-} || -z ${IN_DIR:-} ]]; then
  echo "Error: both -s and -i are required."
  usage
fi

if [[ ! -d ${IN_DIR:-} ]]; then
  echo "Error: input directory '$IN_DIR' does not exist."
  exit 2
fi

mkdir -p "$OUT_DIR"

# sanitize symbol and directory names
# turn "Stats::statRead" → "stats_statread"
SYM_SAFE=${ sanitize "$SYMBOL"; }

# basename of IN_DIR, e.g. "use_stl_containers_in_stats"
DIR_BASE=${IN_DIR##*/}
DIR_SAFE=${ sanitize "$DIR_BASE"; }

# loop
for perffile in "$IN_DIR"/*.data.*; do
  [[ -e ${perffile} ]] || { echo "No files in $IN_DIR"; exit 0; }
  # get the ID (strip everything from ".data")
  fname=$(basename "$perffile")
  fileid=${fname%%.data.*}

  outfile="$OUT_DIR/${SYM_SAFE}_${DIR_SAFE}_${fileid}"

  echo "Annotating $perffile → $outfile"
  doas perf annotate \
    -i "$perffile" \
    -l -s \
    -v "$SYMBOL" \
    --stdio \
    > "$outfile"
done

echo "Done! All annotations in '$OUT_DIR'."
