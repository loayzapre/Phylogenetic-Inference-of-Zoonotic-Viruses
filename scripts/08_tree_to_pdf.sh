#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="results/tree_figures"
PY_SCRIPT="scripts/utils/render_trees.py"
SHOW_TIP_LABELS=0
SHOW_INTERNAL_LABELS=0

timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log() {
  echo "[$(timestamp)] [INFO] $*"
}

die() {
  echo "[$(timestamp)] [ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

usage() {
  cat <<EOF
Usage:
  bash scripts/08_tree_to_pdf.sh [options] tree1 tree2 ...

Options:
  --outdir DIR
  --show-tip-labels
  --show-internal-labels
  -h, --help

Example:
  bash scripts/08_tree_to_pdf.sh \
    --outdir results/tree_figures \
    --show-tip-labels \
    results/mr_bayes/sarscov2.con.tre \
    results/mr_bayes/lassa.con.tre
EOF
}

main() {
  require_cmd python3
  [[ -f "$PY_SCRIPT" ]] || die "Missing Python script: $PY_SCRIPT"

  local tree_files=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --outdir)
        [[ $# -ge 2 ]] || die "--outdir requires a value"
        OUT_DIR="$2"
        shift 2
        ;;
      --show-tip-labels)
        SHOW_TIP_LABELS=1
        shift
        ;;
      --show-internal-labels)
        SHOW_INTERNAL_LABELS=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        tree_files+=("$1")
        shift
        ;;
    esac
  done

  [[ ${#tree_files[@]} -gt 0 ]] || {
    usage
    die "No tree files provided"
  }

  mkdir -p "$OUT_DIR"

  for f in "${tree_files[@]}"; do
    [[ -f "$f" ]] || die "Tree file not found: $f"
  done

  local cmd=(python3 "$PY_SCRIPT" --outdir "$OUT_DIR")

  if [[ "$SHOW_TIP_LABELS" -eq 1 ]]; then
    cmd+=(--show-tip-labels)
  fi

  if [[ "$SHOW_INTERNAL_LABELS" -eq 1 ]]; then
    cmd+=(--show-internal-labels)
  fi

  cmd+=("${tree_files[@]}")

  log "Rendering ${#tree_files[@]} tree(s)"
  log "[CMD] ${cmd[*]}"
  "${cmd[@]}"

  log "Done. Figures in: $OUT_DIR"
}

main "$@"