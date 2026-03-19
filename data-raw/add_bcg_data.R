# BCG Vaccine Meta-Analysis Data
# A classic dataset for meta-analysis (13 studies)
bcg_data <- data.frame(
  study_id = paste0("Study_", 1:13),
  yi = c(-0.8893, -1.5854, -1.3481, -1.4416, -0.2175, -0.7861, -0.6212, -0.012, -0.0469, -0.7127, -0.2575, 0.012, -0.4694),
  vi = c(0.3256, 0.4463, 0.4158, 0.3705, 0.0412, 0.0633, 0.0786, 0.0475, 0.0274, 0.0573, 0.0339, 0.0333, 0.0227),
  year = c(1933, 1935, 1935, 1937, 1941, 1947, 1948, 1949, 1953, 1958, 1960, 1963, 1980),
  latitude = c(44, 19, 13, 18, 54, 33, 33, 18, 52, 13, 44, 19, 42)
)
bcg_data$se <- sqrt(bcg_data$vi)
bcg_data$precision <- 1/bcg_data$se

# Save to data directory
save(bcg_data, file = "data/bcg_data.rda")
cat("✓ bcg_data.rda created successfully.
")
