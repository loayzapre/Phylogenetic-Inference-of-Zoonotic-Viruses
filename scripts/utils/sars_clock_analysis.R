#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ape)
})

# --- Arguments ---
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag) {
  idx <- which(args == flag)
  if (length(idx) == 0 || idx == length(args)) stop(paste("Missing:", flag))
  args[idx + 1]
}

tree_file          <- get_arg("--tree")
outdir             <- get_arg("--outdir")
reference_date_str <- get_arg("--reference-date")

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)
ref_date <- as.Date(reference_date_str)
outgroup_label <- "NC_004718.3_2003-04-13"

# --- 1. Load and Root ---
cat("Reading tree:", tree_file, "\n")
tree <- read.nexus(tree_file)

# Root on the 2003 sequence as requested
tree <- root(tree, outgroup = outgroup_label, resolve.root = TRUE)

if (!is.rooted(tree)) {
  stop("ERROR: Tree is not rooted. Check outgroup label.")
}

# --- 2. Calculate Distances ---
# This gets distance from the root node (the split between 2003 and the rest)
all_depths <- node.depth.edgelength(tree)

# --- 3. Extract and Filter Data ---
tip_labels <- tree$tip.label
date_pattern <- ".*_(\\d{4}-\\d{2}-\\d{2})$"

# IMPORTANT: We identify all dated tips, but then EXCLUDE the outgroup 
# from the regression to prevent the negative slope artifact.
has_date <- grepl(date_pattern, tip_labels)
is_human <- has_date & (tip_labels != outgroup_label)

human_tips <- tip_labels[is_human]
human_indices <- match(human_tips, tip_labels)

df <- data.frame(
  tip = human_tips,
  collection_date = as.Date(sub(date_pattern, "\\1", human_tips)),
  root_to_tip = all_depths[human_indices],
  stringsAsFactors = FALSE
)
df$days_since_ref <- as.numeric(df$collection_date - ref_date)

# --- 4. Regression (SARS-CoV-2 only) ---
# This will now show a positive slope as evolution proceeded from 2019 onwards
fit <- lm(root_to_tip ~ days_since_ref, data = df)
fit_sum <- summary(fit)

slope_per_day <- coef(fit)[["days_since_ref"]]
slope_per_year <- slope_per_day * 365.25
r_squared <- fit_sum$r.squared

# --- 5. MRCA of Human Clade ---
mrca_node <- getMRCA(tree, human_indices)
root_to_mrca <- all_depths[mrca_node]

# Back-calculate the date when the human clade started
mrca_days <- (root_to_mrca - coef(fit)[["(Intercept)"]]) / slope_per_day
mrca_date <- ref_date + round(mrca_days)

# --- 6. Output ---
write.csv(df, file.path(outdir, "sarscov2_regression_data.csv"), row.names = FALSE)

# Plot Regression
pdf(file.path(outdir, "regression_plot.pdf"), width = 7, height = 5)
plot(df$days_since_ref, df$root_to_tip, pch = 19, col = "blue",
     xlab = "Days since Reference", ylab = "Distance from SARS-1 Root",
     main = "SARS-CoV-2 Molecular Clock (Excl. Outgroup)")
abline(fit, col = "red", lwd = 2)
legend("topleft", bty = "n", legend = c(
  paste("Slope/Year:", signif(slope_per_year, 4)),
  paste("R^2:", signif(r_squared, 4)),
  paste("Est. MRCA:", mrca_date)
))
dev.off()

# Save Summary
sink(file.path(outdir, "summary.txt"))
cat("SARS-CoV-2 Clock Analysis\n")
cat("Rooted on:", outgroup_label, "\n")
cat("Regression based on", nrow(df), "human sequences.\n\n")
print(fit_sum)
cat("\nEstimated Human MRCA Date:", as.character(mrca_date), "\n")
sink()

cat("Done. Check", outdir, "for results.\n")