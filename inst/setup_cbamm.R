# =============================================================================
# CBAMM PACKAGE SETUP SCRIPT
# Run this script to create all necessary files for your R package
# =============================================================================

# Load required packages
if (!require("usethis")) install.packages("usethis")
if (!require("devtools")) install.packages("devtools")
if (!require("roxygen2")) install.packages("roxygen2")

library(usethis)
library(devtools)

# =============================================================================
# 1. UPDATE DESCRIPTION FILE
# =============================================================================

desc_content <- 'Package: cbamm
Type: Package
Title: Collaborative Bayesian Adaptive Meta-Analysis Methods
Version: 0.1.0
Authors@R:
    person("First", "Last",
           email = "your.email@example.com",
           role = c("aut", "cre"))
Description: A comprehensive meta-analysis package specializing in cumulative
    analysis and transportability methods. Provides tools for Bayesian adaptive
    meta-analysis, transport weights computation for generalizability assessment,
    and comprehensive heterogeneity evaluation with visualization capabilities.
License: GPL (>= 3)
Encoding: UTF-8
LazyData: true
Depends:
    R (>= 3.5.0)
Imports:
    stats,
    graphics,
    utils,
    methods
Suggests:
    metafor (>= 3.0.0),
    ggplot2 (>= 3.3.0),
    dplyr (>= 1.0.0),
    gridExtra,
    testthat (>= 3.0.0),
    knitr,
    rmarkdown
RoxygenNote: 7.3.1
VignetteBuilder: knitr
URL: https://github.com/yourusername/cbamm
BugReports: https://github.com/yourusername/cbamm/issues'

writeLines(desc_content, "DESCRIPTION")
cat("✓ DESCRIPTION file updated\n")

# =============================================================================
# 2. CREATE PACKAGE DOCUMENTATION FILE
# =============================================================================

pkg_doc <- '#\' CBAMM: Collaborative Bayesian Adaptive Meta-Analysis Methods
#\'
#\' The CBAMM package provides comprehensive tools for conducting meta-analyses
#\' with a focus on cumulative analysis and transportability assessment.
#\'
#\' @section Main Functions:
#\' The package provides three main categories of functions:
#\'
#\' \\strong{Core Meta-Analysis:}
#\' \\itemize{
#\'   \\item \\code{\\link{cbamm_fast}}: Fast random/fixed effects meta-analysis
#\'   \\item \\code{\\link{robust_rma}}: Robust meta-analysis wrapper
#\'   \\item \\code{\\link{meta_regression}}: Meta-regression analysis
#\'   \\item \\code{\\link{subgroup_analysis}}: Subgroup meta-analysis
#\' }
#\'
#\' \\strong{Cumulative Analysis:}
#\' \\itemize{
#\'   \\item \\code{\\link{cumulative_meta_analysis}}: Sequential meta-analysis
#\' }
#\'
#\' \\strong{Transportability:}
#\' \\itemize{
#\'   \\item \\code{\\link{compute_transport_weights}}: Calculate transport weights
#\'   \\item \\code{\\link{compute_analysis_weights}}: Compute final analysis weights
#\' }
#\'
#\' @section Package Options:
#\' The package uses the following options:
#\' \\itemize{
#\'   \\item \\code{cbamm.digits}: Number of digits for display (default: 4)
#\'   \\item \\code{cbamm.verbose}: Verbose output (default: FALSE)
#\' }
#\'
#\' @docType package
#\' @name cbamm-package
#\' @aliases cbamm
#\' @author First Last \\email{your.email@example.com}
#\' @keywords package
#\' @import stats graphics utils methods
NULL'

writeLines(pkg_doc, "R/cbamm-package.R")
cat("✓ Package documentation file created\n")

# =============================================================================
# 3. CREATE EXAMPLE DATA AND DOCUMENTATION
# =============================================================================

# Create data directory if it doesn't exist
if (!dir.exists("data")) dir.create("data")

# Create example dataset
example_meta <- data.frame(
  study_id = paste0("Study_", 1:15),
  yi = c(0.15, 0.22, 0.18, 0.31, 0.09, 0.25, 0.20, 0.17,
         0.28, 0.14, 0.23, 0.19, 0.26, 0.21, 0.16),
  vi = c(0.042, 0.038, 0.051, 0.027, 0.065, 0.033, 0.045, 0.040,
         0.029, 0.055, 0.036, 0.048, 0.031, 0.041, 0.053),
  year = 2010:2024,
  n = c(120, 95, 150, 200, 80, 175, 110, 135,
        220, 100, 160, 125, 190, 145, 105),
  age_mean = runif(15, 45, 65),
  female_pct = runif(15, 0.4, 0.6),
  bmi_mean = runif(15, 24, 30),
  charlson = runif(15, 1, 4)
)

# Calculate standard errors and precision
example_meta$se <- sqrt(example_meta$vi)
example_meta$precision <- 1/sqrt(example_meta$vi)

# Save the data
save(example_meta, file = "data/example_meta.rda")
cat("✓ Example dataset created and saved\n")

# Create data documentation
data_doc <- '#\' Example Meta-Analysis Dataset
#\'
#\' A simulated dataset containing effect sizes and study characteristics
#\' from 15 hypothetical studies for demonstration purposes.
#\'
#\' @format A data frame with 15 rows and 11 variables:
#\' \\describe{
#\'   \\item{study_id}{Character: Unique study identifier}
#\'   \\item{yi}{Numeric: Effect size estimate (e.g., log odds ratio)}
#\'   \\item{vi}{Numeric: Variance of the effect size}
#\'   \\item{year}{Integer: Year of publication (2010-2024)}
#\'   \\item{n}{Integer: Total sample size}
#\'   \\item{age_mean}{Numeric: Mean age of participants}
#\'   \\item{female_pct}{Numeric: Proportion of female participants}
#\'   \\item{bmi_mean}{Numeric: Mean BMI of participants}
#\'   \\item{charlson}{Numeric: Mean Charlson comorbidity index}
#\'   \\item{se}{Numeric: Standard error (calculated from vi)}
#\'   \\item{precision}{Numeric: Precision (1/se)}
#\' }
#\'
#\' @source Simulated data for package demonstration
#\'
#\' @examples
#\' data(example_meta)
#\' head(example_meta)
#\'
#\' # Run basic meta-analysis
#\' result <- cbamm_fast(example_meta)
#\' print(result)
#\'
#\' # Run cumulative analysis
#\' cum_result <- cumulative_meta_analysis(example_meta, order_by = "year")
#\' print(cum_result)
"example_meta"'

writeLines(data_doc, "R/data.R")
cat("✓ Data documentation file created\n")

# =============================================================================
# 4. CREATE BASIC TESTS
# =============================================================================

# Set up test infrastructure
usethis::use_testthat()

# Create test file for main functions
test_content <- 'test_that("cbamm_fast performs basic meta-analysis", {
  # Use example data
  data(example_meta)

  # Run analysis
  result <- cbamm_fast(example_meta[1:5,])

  # Check structure
  expect_s3_class(result, "cbamm")
  expect_equal(result$k, 5)
  expect_true(is.numeric(result$b))
  expect_true(is.numeric(result$tau2))
  expect_true(result$tau2 >= 0)
  expect_true(result$I2 >= 0 && result$I2 <= 100)
})

test_that("validate_cbamm_data handles various input formats", {
  # Test with proper data
  good_data <- data.frame(yi = c(0.1, 0.2), vi = c(0.01, 0.02))
  validated <- validate_cbamm_data(good_data)
  expect_equal(nrow(validated), 2)

  # Test with se instead of vi
  se_data <- data.frame(yi = c(0.1, 0.2), se = c(0.1, 0.14))
  validated_se <- validate_cbamm_data(se_data)
  expect_true("vi" %in% names(validated_se))

  # Test removal of missing values
  bad_data <- data.frame(yi = c(0.1, NA, 0.2), vi = c(0.01, 0.02, 0.03))
  expect_warning(validated_bad <- validate_cbamm_data(bad_data))
  expect_equal(nrow(validated_bad), 2)
})

test_that("cumulative_meta_analysis works correctly", {
  data(example_meta)

  # Run cumulative analysis
  cum_result <- cumulative_meta_analysis(
    example_meta[1:6,],
    order_by = "year",
    minimum_studies = 2
  )

  expect_s3_class(cum_result, "cbamm_cumulative")
  expect_true(nrow(cum_result$results) > 0)
  expect_true(all(cum_result$results$n_studies >= 2))
  expect_equal(max(cum_result$results$n_studies), 6)
})

test_that("compute_transport_weights returns valid weights", {
  data(example_meta)

  target_pop <- list(
    age_mean = 55,
    female_pct = 0.5,
    bmi_mean = 27,
    charlson = 2.5
  )

  weights <- compute_transport_weights(example_meta, target_pop)

  expect_equal(length(weights), nrow(example_meta))
  expect_true(all(weights >= 0))
  expect_true(abs(sum(weights) - 1) < 0.001)  # Should sum to 1
})

test_that("meta_regression handles formula input", {
  data(example_meta)

  # Add yi if not present
  if (!"yi" %in% names(example_meta)) {
    example_meta$yi <- example_meta$effect
  }

  # Run meta-regression
  result <- meta_regression(
    example_meta[1:10,],
    formula = yi ~ year
  )

  expect_s3_class(result, "cbamm_metareg")
  expect_equal(length(result$coefficients), 2)  # Intercept + year
  expect_true(all(is.finite(result$se)))
})'

writeLines(test_content, "tests/testthat/test-cbamm.R")
cat("✓ Test file created\n")

# =============================================================================
# 5. CREATE README
# =============================================================================

readme_content <- '# CBAMM: Collaborative Bayesian Adaptive Meta-Analysis Methods

<!-- badges: start -->
[![R-CMD-check](https://github.com/yourusername/cbamm/workflows/R-CMD-check/badge.svg)](https://github.com/yourusername/cbamm/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/cbamm)](https://CRAN.R-project.org/package=cbamm)
<!-- badges: end -->

## Overview

CBAMM provides comprehensive tools for conducting meta-analyses with a focus on:

- **Cumulative meta-analysis**: Track how evidence accumulates over time
- **Transport weights**: Assess generalizability to target populations
- **Robust methods**: Handle various data formats and edge cases
- **Visualization**: Create publication-ready forest plots and dashboards

## Installation

You can install the development version of CBAMM from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("yourusername/cbamm")
```

## Quick Start

``` r
library(cbamm)

# Load example data
data(example_meta)

# Run basic meta-analysis
result <- cbamm_fast(example_meta)
print(result)

# Cumulative analysis
cum_result <- cumulative_meta_analysis(
  example_meta,
  order_by = "year"
)
print(cum_result)

# Compute transport weights for generalizability
target_population <- list(
  age_mean = 60,
  female_pct = 0.52,
  bmi_mean = 28,
  charlson = 3
)

weights <- compute_transport_weights(
  example_meta,
  target_population
)
```

## Main Functions

### Core Meta-Analysis
- `cbamm_fast()`: Fast random/fixed effects meta-analysis
- `meta_regression()`: Meta-regression with covariates
- `subgroup_analysis()`: Subgroup meta-analysis

### Cumulative Analysis
- `cumulative_meta_analysis()`: Sequential evidence accumulation
- Automatic stability detection
- Evidence sufficiency assessment

### Transportability
- `compute_transport_weights()`: Calculate weights for target population
- `compute_analysis_weights()`: Combine with precision weights

### Visualization
- `forest_plot_enhanced()`: Publication-ready forest plots
- `create_cumulative_dashboard()`: Multi-panel diagnostic plots

## Getting Help

- Report bugs: [GitHub Issues](https://github.com/yourusername/cbamm/issues)
- Documentation: Type `?cbamm` after loading the package

## License

GPL (>= 3)'

writeLines(readme_content, "README.md")
cat("✓ README.md created\n")

# =============================================================================
# 6. CREATE .RBUILDIGNORE
# =============================================================================

buildignore_content <- '^.*\\.Rproj$
^\\.Rproj\\.user$
^README\\.Rmd$
^LICENSE\\.md$
^data-raw$
^\\.github$
^_pkgdown\\.yml$
^docs$
^pkgdown$
^\\.travis\\.yml$
^appveyor\\.yml$
^\\.DS_Store$
^cran-comments\\.md$
^CRAN-RELEASE$
^revdep$'

writeLines(buildignore_content, ".Rbuildignore")
cat("✓ .Rbuildignore created\n")

# =============================================================================
# 7. BUILD AND CHECK
# =============================================================================

cat("\n" , strrep("=", 60), "\n")
cat("SETUP COMPLETE! Now run these commands:\n")
cat(strrep("=", 60), "\n\n")

cat("1. Generate documentation:\n")
cat("   devtools::document()\n\n")

cat("2. Load and test the package:\n")
cat("   devtools::load_all()\n")
cat("   test_cbamm()\n\n")

cat("3. Run tests:\n")
cat("   devtools::test()\n\n")

cat("4. Check the package:\n")
cat("   devtools::check()\n\n")

cat("5. Build the package:\n")
cat("   devtools::build()\n\n")

cat("Optional: Update your name and email in DESCRIPTION file\n")
cat("Optional: Update GitHub URLs in DESCRIPTION and README\n")
