# Code to generate the example_meta dataset for cbamm
set.seed(123)

n_studies <- 30
true_effect <- 0.25 # Log odds ratio or similar
tau <- 0.15 # Heterogeneity

study_ids <- paste0("Study_", 1:n_studies)
years <- sort(sample(2010:2024, n_studies, replace = TRUE))

# Sample sizes
n <- round(runif(n_studies, 50, 500))

# Study-specific true effects (random effects model)
theta_i <- rnorm(n_studies, true_effect, tau)

# Standard errors (larger studies have smaller SE)
se <- 1 / sqrt(n / 20)

# Observed effects
yi <- rnorm(n_studies, theta_i, se)
vi <- se^2

# Covariates for transportability
age_mean <- rnorm(n_studies, 65, 8)
female_pct <- rbeta(n_studies, 5, 5) # Around 0.5
bmi_mean <- rnorm(n_studies, 27, 4)
charlson <- rpois(n_studies, 2.5)

example_meta <- data.frame(
  study_id = study_ids,
  yi = yi,
  vi = vi,
  se = se,
  year = years,
  n = n,
  age_mean = age_mean,
  female_pct = female_pct,
  bmi_mean = bmi_mean,
  charlson = charlson,
  precision = 1/vi
)

# Save to data/
# In a real dev environment, we'd use usethis::use_data(example_meta, overwrite = TRUE)
# Here we will just save it as RDA for the package to find
save(example_meta, file = "C:/Users/user/OneDrive - NHS/Documents/LFA/data/example_meta.rda")

message("Generated 30-study clinical dataset in data/example_meta.rda")
