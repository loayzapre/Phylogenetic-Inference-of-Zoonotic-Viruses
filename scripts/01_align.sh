#!/usr/bin/env bash
set -euo pipefail

RAW_DIR="data/raw"
OUT_DIR="data/aligned"
LOG_DIR="results/logs"

mkdir -p "$OUT_DIR" "$LOG_DIR"

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  echo "[$(timestamp)] $*"
}

die() {
  echo "[$(timestamp)] [ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

is_fasta_ext() {
  local f="$1"
  case "${f,,}" in
    *.fasta|*.fa|*.fas|*.fna) return 0 ;;
    *) return 1 ;;
  esac
}

is_nexus_ext() {
  local f="$1"
  case "${f,,}" in
    *.nexus|*.nex) return 0 ;;
    *) return 1 ;;
  esac
}

align_fasta() {
  local infile="$1"
  local base out log_file cmd

  base="$(basename "$infile")"
  base="${base%.*}"
  out="${OUT_DIR}/${base}.aligned.fasta"
  log_file="${LOG_DIR}/${base}.mafft.log"

  cmd=(mafft --auto "$infile")

  log "[ALIGN] $infile -> $out"
  log "[CMD] ${cmd[*]} > $out 2> $log_file"

  "${cmd[@]}" > "$out" 2> "$log_file" || {
    rm -f "$out"
    die "MAFFT failed for $infile. See log: $log_file"
  }

  [[ -s "$out" ]] || die "Alignment output is empty for $infile"

  log "[OK] wrote $out"
  log "[OK] log   $log_file"
}

main() {
  require_cmd mafft
  [[ -d "$RAW_DIR" ]] || die "Missing input directory: $RAW_DIR"

  shopt -s nullglob
  local files=("$RAW_DIR"/*)
  (( ${#files[@]} > 0 )) || die "No files found in $RAW_DIR"

  local aligned_count=0
  local skipped_nexus=0
  local skipped_other=0

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue

    if is_fasta_ext "$f"; then
      align_fasta "$f"
      ((aligned_count+=1))
    elif is_nexus_ext "$f"; then
      log "[SKIP] $f detected as NEXUS input; not aligned in step 01"
      ((skipped_nexus+=1))
    else
      log "[SKIP] $f unsupported extension"
      ((skipped_other+=1))
    fi
  done

  log "Summary:"
  log "  aligned fasta files : $aligned_count"
  log "  skipped nexus files : $skipped_nexus"
  log "  skipped other files : $skipped_other"
}

main "$@"