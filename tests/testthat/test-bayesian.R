library(testthat)
library(cbamm)

context("CBAMM Bayesian Meta-Analysis")

test_that("cbamm_bayesian runs without errors", {
  data_test <- data.frame(
    yi = c(0.1, 0.2, 0.3, 0.4, 0.5),
    se = c(0.05, 0.06, 0.04, 0.08, 0.07)
  )
  
  # Check if coda is installed, otherwise skip
  if (!requireNamespace("coda", quietly = TRUE)) {
    skip("coda package not available for Bayesian tests")
  }
  
  # Run with small iterations for speed
  bayesian_result <- cbamm_bayesian(data_test, n_iter = 500, n_burnin = 100)
  
  expect_s3_class(bayesian_result, "cbamm_bayesian")
  expect_true(!is.null(bayesian_result$mu_summary))
  expect_true(!is.null(bayesian_result$tau_summary))
  expect_true(is.numeric(bayesian_result$bf10_mu))
  expect_true(is.numeric(bayesian_result$bf_het))
})

test_that("Bayesian print method displays correct information", {
  data_test <- data.frame(
    yi = c(0.1, 0.2, 0.3),
    se = c(0.05, 0.06, 0.04)
  )
  
  if (!requireNamespace("coda", quietly = TRUE)) {
    skip("coda package not available for Bayesian tests")
  }
  
  bayesian_result <- cbamm_bayesian(data_test, n_iter = 500, n_burnin = 100)
  
  expect_output(print(bayesian_result), "Bayesian Random-Effects Model")
  expect_output(print(bayesian_result), "Posterior Summary for Overall Effect")
  expect_output(print(bayesian_result), "Posterior Summary for Heterogeneity")
  expect_output(print(bayesian_result), "Bayes Factor Analysis")
  expect_output(print(bayesian_result), "BF10 \\(Effect\\):")
  expect_output(print(bayesian_result), "BF \\(Heterog\\.\\):")
})

test_that("Bayes factors respond to data", {
  # Strong effect data
  data_strong <- data.frame(
    yi = c(0.8, 0.9, 1.0),
    se = c(0.1, 0.1, 0.1)
  )
  
  # No effect data
  data_null <- data.frame(
    yi = c(-0.01, 0.02, 0.0),
    se = c(0.1, 0.1, 0.1)
  )
  
  if (!requireNamespace("coda", quietly = TRUE)) {
    skip("coda package not available for Bayesian tests")
  }
  
  fit_strong <- cbamm_bayesian(data_strong, n_iter = 1000, n_burnin = 200)
  fit_null <- cbamm_bayesian(data_null, n_iter = 1000, n_burnin = 200)
  
  # Expect BF for effect to be > 1 for strong effect, < 1 for null effect
  expect_gt(fit_strong$bf10_mu, 1)
  expect_lt(fit_null$bf10_mu, 1)
})
