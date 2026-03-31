#!/usr/bin/env bash
set -euo pipefail

ALIGNED_DIR="data/aligned"
VALIDATED_DIR="data/validated"
LOG_DIR="results/logs"
UTILS_DIR="scripts/utils"

mkdir -p "$VALIDATED_DIR" "$LOG_DIR"

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

is_aligned_fasta_ext() {
  local f="$1"
  case "${f,,}" in
    *.aligned.fasta|*.aligned.fa|*.aligned.fas|*.aligned.fna) return 0 ;;
    *) return 1 ;;
  esac
}

validate_aligned_fasta() {
  local infile="$1"
  local base outfile log_file cmd

  base="$(basename "$infile")"
  outfile="${VALIDATED_DIR}/${base}"
  log_file="${LOG_DIR}/${base}.validate.log"

  cmd=(python3 "${UTILS_DIR}/validate_fasta.py" "$infile")

  log "[VALIDATE_FASTA] $infile"
  log "[CMD] ${cmd[*]} > $log_file 2>&1"

  "${cmd[@]}" > "$log_file" 2>&1 || {
    die "FASTA validation failed for $infile. See: $log_file"
  }

  cp "$infile" "$outfile"
  log "[OK] validated -> $outfile"
}

main() {
  require_cmd python3
  [[ -d "$ALIGNED_DIR" ]] || die "Missing aligned dir: $ALIGNED_DIR"
  [[ -f "${UTILS_DIR}/validate_fasta.py" ]] || die "Missing ${UTILS_DIR}/validate_fasta.py"

  shopt -s nullglob
  local files=("${ALIGNED_DIR}"/*)

  local found_any=0
  local validated_fasta=0
  local skipped_other=0

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue

    if is_aligned_fasta_ext "$f"; then
      found_any=1
      validate_aligned_fasta "$f"
      ((validated_fasta+=1))
    else
      ((skipped_other+=1))
    fi
  done

  (( found_any == 1 )) || die "No aligned FASTA files found in $ALIGNED_DIR"

  log "Summary:"
  log "  validated aligned fasta : $validated_fasta"
  log "  skipped other files     : $skipped_other"
}

main "$@"