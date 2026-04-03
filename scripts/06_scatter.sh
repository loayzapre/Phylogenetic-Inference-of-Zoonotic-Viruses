#!/usr/bin/env bash

# Safety settings
set -euo pipefail

# --- Configuration ---
TREE_INPUT="results/mr_bayes/sarscov2.con.tre"
OUTPUT_DIR="results/final_clock_results"
RSCRIPT_PATH="scripts/utils/scatter.R"
REF_DATE="2010-01-01"

# --- Main Execution ---
echo "[INFO] Checking dependencies..."
if [[ ! -f "$TREE_INPUT" ]]; then
    echo "[ERROR] Input tree not found at $TREE_INPUT"
    exit 1
fi

if [[ ! -f "$RSCRIPT_PATH" ]]; then
    echo "[ERROR] R script not found at $RSCRIPT_PATH"
    exit 1
fi

# Ensure R script is executable
chmod +x "$RSCRIPT_PATH"

echo "[INFO] Starting Molecular Clock analysis..."
echo "[INFO] Reference Date: $REF_DATE"

# Run the R script
# Arguments: 1=tree, 2=outdir, 3=ref_date
Rscript "$RSCRIPT_PATH" "$TREE_INPUT" "$OUTPUT_DIR" "$REF_DATE"

echo "[SUCCESS] Analysis finished."
echo "[INFO] View results in $OUTPUT_DIR"