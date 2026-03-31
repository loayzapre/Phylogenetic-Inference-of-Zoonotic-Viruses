# Phylogenetic-Inference-of-Zoonotic-Viruses

Phylogenetic analysis workflow for investigating the origins and evolution of Lassa virus and SARS-CoV-2, using alignment, maximum likelihood, Bayesian inference, and root-to-tip clock analysis.

### Create the Conda environment
It is recommended to use conda or mamba to create an isolated environment.

    conda env create -f environment.yml
    conda activate phylo

Then

    pip install -r requirements.txt

External tools (must be installed separately):

    MAFFT
    ClustalW or Clustal Omega
    MUSCLE
    PAUP*
    FigTree

These tools must be available in the system PATH so they can be called
from the scripts.

## How to run

    nohup bash run_all.sh > pipeline.log 2>&1 &

## Project structure

- `config/`: dataset-specific configuration files
- `data/`: lassa and sars fasta files
- `scripts/`: pipeline scripts for preprocessing, alignment, tree inference, and plotting
- `results/`: outputs organized by dataset
- `report/`: figures and tables for the final write-up

## Main analyses

- Lassa virus phylogeny and spillover interpretation
- SARS-CoV-2 human/non-human phylogeny
- Root-to-tip molecular clock analysis in R

## Reproducibility

The workflow is organized as modular steps with explicit inputs and outputs.