#!/usr/bin/env bash
set -euo pipefail

RAW_DIR="data/raw"
VALIDATED_DIR="data/validated"
OUT_DIR="data/prepared2tree"
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

is_nexus_ext() {
  local f="$1"
  case "${f,,}" in
    *.nexus|*.nex) return 0 ;;
    *) return 1 ;;
  esac
}

is_aligned_fasta_ext() {
  local f="$1"
  case "${f,,}" in
    *.aligned.fasta|*.aligned.fa|*.aligned.fas|*.aligned.fna) return 0 ;;
    *) return 1 ;;
  esac
}

convert_fasta_to_nexus() {
  local infile="$1"
  local base outfile log_file cmd

  base="$(basename "$infile")"
  base="${base%.aligned.fasta}"
  base="${base%.aligned.fa}"
  base="${base%.aligned.fas}"
  base="${base%.aligned.fna}"

  outfile="${OUT_DIR}/${base}.nexus"
  log_file="${LOG_DIR}/${base}.to_nexus.log"

  cmd=(seqconverter -i "$infile" --informat fasta --outformat nexus --width -1)

  log "[CONVERT_FASTA] $infile -> $outfile"
  log "[CMD] ${cmd[*]} > $outfile 2> $log_file"

  "${cmd[@]}" > "$outfile" 2> "$log_file" || {
    rm -f "$outfile"
    die "seqconverter failed for $infile. See: $log_file"
  }

  [[ -s "$outfile" ]] || die "Empty NEXUS output for $infile"

  log "[OK] wrote $outfile"
}

normalize_nexus() {
  local infile="$1"
  local base outfile log_file cmd

  base="$(basename "$infile")"
  base="${base%.nex}"
  base="${base%.nexus}"

  outfile="${OUT_DIR}/${base}.nexus"
  log_file="${LOG_DIR}/${base}.normalize_nexus.log"

  cmd=(seqconverter -i "$infile" --informat nexus --outformat nexus --width -1)

  log "[NORMALIZE_NEXUS] $infile -> $outfile"
  log "[CMD] ${cmd[*]} > $outfile 2> $log_file"

  "${cmd[@]}" > "$outfile" 2> "$log_file" || {
    rm -f "$outfile"
    die "seqconverter failed while normalizing NEXUS: $infile. See: $log_file"
  }

  [[ -s "$outfile" ]] || die "Empty normalized NEXUS output for $infile"

  log "[OK] wrote normalized NEXUS -> $outfile"
}

main() {
  require_cmd seqconverter

  [[ -d "$RAW_DIR" ]] || die "Missing raw dir: $RAW_DIR"
  [[ -d "$VALIDATED_DIR" ]] || log "[WARN] Missing validated dir: $VALIDATED_DIR (continuing)"

  shopt -s nullglob

  local fasta_files=("${VALIDATED_DIR}"/*)
  local nexus_files=("${RAW_DIR}"/*)

  local converted_fasta=0
  local normalized_nexus_count=0
  local skipped_other=0
  local found_any=0

  for f in "${fasta_files[@]}"; do
    [[ -f "$f" ]] || continue
    if is_aligned_fasta_ext "$f"; then
      found_any=1
      convert_fasta_to_nexus "$f"
      ((converted_fasta+=1))
    fi
  done

  for f in "${nexus_files[@]}"; do
    [[ -f "$f" ]] || continue
    if is_nexus_ext "$f"; then
      found_any=1
      normalize_nexus "$f"
      ((normalized_nexus_count+=1))
    else
      log "[SKIP] unsupported raw file: $f"
      ((skipped_other+=1))
    fi
  done

  (( found_any == 1 )) || die "No validated FASTA or raw NEXUS files found for step 03"

  log "Summary:"
  log "  converted validated FASTA : $converted_fasta"
  log "  normalized raw NEXUS      : $normalized_nexus_count"
  log "  skipped other raw files   : $skipped_other"
}

main "$@"