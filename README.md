# CBAMM: Collaborative Bayesian Adaptive Meta-Analysis Methods

[![R-CMD-check](https://github.com/mahmoodahmad2/cbamm/workflows/R-CMD-check/badge.svg)](https://github.com/mahmoodahmad2/cbamm/actions)
[![CRAN status](https://www.r-pkg.org/badges/version/cbamm)](https://CRAN.R-project.org/package=cbamm)

`cbamm` is a comprehensive R package designed for modern, adaptive, and personalized evidence synthesis. It bridges the gap between meta-analytic statistics and clinical decision support through three key innovations:

1.  **Population Transportability**: Uses entropy balancing to weight meta-analytic evidence toward a user-defined target population's characteristics (age, sex, BMI, etc.).
2.  **Sequential Evidence Monitoring**: Implements Trial Sequential Analysis (TSA) boundaries and evidence stability metrics to prevent false-positive conclusions in living systematic reviews.
3.  **Automated Decision Support**: A multi-persona synthesis engine (Strict Methodologist, Clinical Optimist, and Conservative Statistician) that translates complex outputs into qualitative research perspectives.

## Key Comparison

| Feature | `metafor` | `brms` | `TrialSequential` | `cbamm` |
| :--- | :---: | :---: | :---: | :---: |
| Random-Effects MA | ✓ | ✓ | ✓ | ✓ |
| Meta-Regression | ✓ | ✓ | - | ✓ |
| Trial Sequential Analysis (TSA) | - | - | ✓ | ✓ |
| **Population Transport Weights** | - | - | - | **✓** |
| **Bayes Factors (BF10)** | - | ✓ | - | **✓** |
| **Multi-Persona Synthesis** | - | - | - | **✓** |

## Installation

``` r
# install.packages("devtools")
devtools::install_github("mahmoodahmad2/cbamm")
```

## Quick Start: Cumulative Monitoring (BCG Vaccine)

``` r
library(cbamm)
data(bcg_data)

# Run cumulative meta-analysis with TSA monitoring
# Effect size under H1: -0.5 (Log Risk Ratio)
cum_res <- cumulative_meta_analysis(
  bcg_data, 
  order_by = "year", 
  tsa_effect_alt = -0.5
)

# Print with automated multi-persona review
print(cum_res)
```

## Quick Start: Population Transportability

``` r
# Define target population (e.g., older, higher BMI)
target_pop <- list(age_mean = 65, female_pct = 0.52, bmi_mean = 31, charlson = 3.5)

# Calculate transport weights
weights <- compute_transport_weights(example_meta, target_pop)

# The weights adjust the contribution of each study to match the target.
```

## Evidence-to-Decision Logic

`cbamm` is built on the principle that statistical significance (p < 0.05) is only one part of the evidence story. By incorporating **TSA** (is there enough information?), **Stability** (has the estimate stopped moving?), and **Transportability** (does this apply to *my* patients?), `cbamm` provides a more robust foundation for clinical guidelines.

## License

GPL (>= 3)
