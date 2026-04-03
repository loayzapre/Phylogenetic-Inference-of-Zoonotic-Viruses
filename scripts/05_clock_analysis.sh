#!/usr/bin/env bash
set -euo pipefail

TREE_DIR="results/mr_bayes"
CONFIG_DIR="config"
OUT_DIR="results/clock"
UTILS_DIR="scripts/utils"

mkdir -p "$OUT_DIR"

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
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

BASE="sarscov2"
TREE_FILE="${TREE_DIR}/${BASE}.con.tre"
CONFIG_FILE="${CONFIG_DIR}/${BASE}.yaml"

[[ -f "$TREE_FILE" ]] || die "Missing tree file: $TREE_FILE"
[[ -f "$CONFIG_FILE" ]] || die "Missing config file: $CONFIG_FILE"
[[ -f "${UTILS_DIR}/sars_clock_analysis.R" ]] || die "Missing R script: ${UTILS_DIR}/sars_clock_analysis.R"

require_cmd Rscript
require_cmd python3

REF_DATE=$(python3 scripts/utils/load_config.py "$CONFIG_FILE" "clock_analysis.reference_date")

CMD=(
  Rscript "${UTILS_DIR}/sars_clock_analysis.R"
  --tree "$TREE_FILE"
  --outdir "$OUT_DIR"
  --reference-date "$REF_DATE"
)

log "[CLOCK] Running SARS-CoV-2 clock analysis"
log "[CMD] ${CMD[*]}"

"${CMD[@]}"

log "[OK] Clock analysis complete"
log "[OUT] ${OUT_DIR}"