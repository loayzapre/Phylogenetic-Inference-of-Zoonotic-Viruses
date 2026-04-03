#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ape)
})

# --- Argument Parsing ---
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage: sars_clock.R <tree_file> <outdir> <reference_date>")
}

tree_file      <- args[1]
out_dir        <- args[2]
ref_date_param <- as.Date(args[3]) # Jan 1, 2010

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 1. Load and Root ---
# Rooting on SARS-1 (2003) as the designated ancestor
tree <- read.nexus(tree_file)
outgroup_label <- "NC_004718.3_2003-04-13"

tree <- root(tree, outgroup = outgroup_label, resolve.root = TRUE)

if (!is.rooted(tree)) {
  stop("Failed to root the tree. Check if the outgroup label is correct.")
}

# --- 2. Calculate Distances ---
# This gives the distance from the SARS-1 root to every node/tip
all_distances <- node.depth.edgelength(tree)

# --- 3. Filter for Human Sequences ---
tip_labels <- tree$tip.label
date_pattern <- ".*_(\\d{4}-\\d{2}-\\d{2})$"

# Identify dated tips that are NOT the outgroup
is_dated <- grepl(date_pattern, tip_labels)
is_human <- is_dated & (tip_labels != outgroup_label)

human_labels <- tip_labels[is_human]
human_indices <- match(human_labels, tip_labels)

# Extract dates and calculate days since Jan 1, 2010
dates <- as.Date(sub(date_pattern, "\\1", human_labels))
days_since_ref <- as.numeric(dates - ref_date_param)
dist_from_root <- all_distances[human_indices]

df <- data.frame(
  tip = human_labels,
  date = dates,
  x_days = days_since_ref,
  y_dist = dist_from_root,
  stringsAsFactors = FALSE
)

# --- 4. Regression Analysis ---
fit <- lm(y_dist ~ x_days, data = df)
slope_year <- coef(fit)[["x_days"]] * 365.25
r_sq <- summary(fit)$r.squared

# --- 5. Generate Scatter Plot ---
plot_path <- file.path(out_dir, "sars2_root_to_tip_scatter.pdf")
pdf(plot_path, width = 8, height = 6)

plot(
  df$x_days, df$y_dist,
  pch = 19, col = "steelblue",
  xlab = paste("Days since", ref_date_param),
  ylab = "Genetic Distance from SARS-1 Root",
  main = "SARS-CoV-2 Root-to-Tip Regression",
  las = 1
)
abline(fit, col = "firebrick", lwd = 2)

legend("topleft", bty = "n", legend = c(
  paste("Slope (subs/year):", signif(slope_year, 4)),
  paste("R-squared:", signif(r_sq, 4))
))

dev.off()

# --- 6. Save Data and Summary ---
write.csv(df, file.path(out_dir, "clock_data.csv"), row.names = FALSE)

summary_path <- file.path(out_dir, "clock_summary.txt")
sink(summary_path)
cat("Molecular Clock Analysis Summary\n")
cat("===============================\n")
cat("Reference Date:", as.character(ref_date_param), "\n")
cat("Outgroup Root:", outgroup_label, "\n")
cat("Number of Human Sequences:", nrow(df), "\n\n")
print(summary(fit))
sink()

cat("Analysis complete. Results saved in:", out_dir, "\n")