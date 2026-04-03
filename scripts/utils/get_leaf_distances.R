#!/usr/bin/env Rscript
library(ape)

# 1. Capture command line arguments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: get_leaf_distances.R <input_tree> <output_csv>")
}

tree_path <- args[1]
output_csv <- args[2]

# 2. Load the consensus tree
tree <- read.nexus(tree_path)

# 3. Root the tree (Using the 2003 sequence as specified)
outgroup_name <- "NC_004718.3_2003-04-13"
tree <- root(tree, outgroup = outgroup_name, resolve.root = TRUE)

# 4. Calculate root-to-node distances for all points in the tree
# node.depth.edgelength returns a numeric vector of cumulative branch lengths
all_depths <- node.depth.edgelength(tree)

# 5. Extract only the leaves (tips)
# In 'ape', the first N elements of the depth vector correspond to the N tips
n_tips <- length(tree$tip.label)
leaf_distances <- all_depths[1:n_tips]

# 6. Create a simple data frame and save
results <- data.frame(
  Leaf_Name = tree$tip.label,
  Root_to_Leaf_Distance = leaf_distances
)

write.csv(results, output_csv, row.names = FALSE)
cat("Successfully wrote distances for", n_tips, "leaves to:", output_csv, "\n")