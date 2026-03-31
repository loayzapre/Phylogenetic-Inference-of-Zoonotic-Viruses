#!/usr/bin/env bash

INPUT_DIR="data/prepared2tree"
YAML_DIR="config"
OUTPUT_DIR="results/mr_bayes"
PYTHON_LOADER="scripts/utils/load_config.py"

mkdir -p "$OUTPUT_DIR"

# Loop through all Nexus files
for nex_file in "$INPUT_DIR"/*.nexus; do
    [ -e "$nex_file" ] || continue

    base_name=$(basename "$nex_file" .nexus)
    yaml_file="$YAML_DIR/${base_name}.yaml"

    if [[ ! -f "$yaml_file" ]]; then
        echo "Skipping $base_name: YAML config missing."
        continue
    fi

    echo "Processing $base_name using Python loader..."

   # Extract parameters using the "mrbayes." prefix
    NST=$($PYTHON_LOADER "$yaml_file" "mrbayes.nst")
    RATES=$($PYTHON_LOADER "$yaml_file" "mrbayes.rates")
    NGEN=$($PYTHON_LOADER "$yaml_file" "mrbayes.ngen")
    SFREQ=$($PYTHON_LOADER "$yaml_file" "mrbayes.samplefreq")
    NRUNS=$($PYTHON_LOADER "$yaml_file" "mrbayes.nruns")
    NCHAINS=$($PYTHON_LOADER "$yaml_file" "mrbayes.nchains")
    BURNIN=$($PYTHON_LOADER "$yaml_file" "mrbayes.burninfrac")

    # Also, let's extract the outgroup
    OUTGROUP=$($PYTHON_LOADER "$yaml_file" "outgroup")

    # Generate the MrBayes block
    tmp_run="${base_name}_exec.nexus"

    cat <<EOF > "$tmp_run"
begin mrbayes;
    set autoclose=yes nowarn=yes;
    execute $nex_file;
    mcmcp filename=$OUTPUT_DIR/$base_name;
    outgroup $OUTGROUP;
    lset nst=$NST rates=$RATES;
    mcmc ngen=$NGEN samplefreq=$SFREQ nruns=$NRUNS nchains=$NCHAINS;
    sumt burninfrac=$BURNIN;
    sump burninfrac=$BURNIN;
end;
EOF

    # Execute MrBayes
    mb "$tmp_run" > "$OUTPUT_DIR/${base_name}.log"

    # Cleanup
    rm "$tmp_run"
    
    echo "Done with $base_name."
done