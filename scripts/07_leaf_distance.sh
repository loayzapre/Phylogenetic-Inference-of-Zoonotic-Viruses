#!/usr/bin/env bash
set -euo pipefail

# Configuration
INPUT_TREE="results/mr_bayes/sarscov2.con.tre"
OUTPUT_FILE="results/leaf_distances.csv"
R_SCRIPT="scripts/utils/get_leaf_distances.R"

# Create results directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Ensure script is executable
chmod +x "$R_SCRIPT"

echo "Calculating root-to-leaf distances..."

# Execute
Rscript "$R_SCRIPT" "$INPUT_TREE" "$OUTPUT_FILE"

echo "Process complete."