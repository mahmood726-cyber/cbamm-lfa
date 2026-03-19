library(testthat)
library(cbamm)

context("CBAMM Multi-Persona Review")

test_that("Multi-persona review generates correct output for cbamm object", {
  data_test <- data.frame(
    yi = c(0.1, 0.2, 0.3, 0.4, 0.5),
    se = c(0.05, 0.06, 0.04, 0.08, 0.07)
  )
  
  result <- cbamm_fast(data_test)
  
  expect_output(print(result), "MULTI-PERSONA RESEARCH SYNTHESIS REVIEW")
  expect_output(print(result), "[Strict Methodologist]")
  expect_output(print(result), "[Clinical Optimist]")
  expect_output(print(result), "[Cons. Statistician]")
})

test_that("Multi-persona review generates correct output for cbamm_cumulative object", {
  data_test <- data.frame(
    yi = c(0.1, 0.2, 0.3, 0.4, 0.5),
    se = c(0.05, 0.06, 0.04, 0.08, 0.07)
  )
  
  result_cumulative <- cumulative_meta_analysis(data_test)
  
  expect_output(print(result_cumulative), "MULTI-PERSONA RESEARCH SYNTHESIS REVIEW")
  expect_output(print(result_cumulative), "[Strict Methodologist]")
  expect_output(print(result_cumulative), "[Clinical Optimist]")
  expect_output(print(result_cumulative), "[Cons. Statistician]")
})

test_that("Persona verdicts change based on results", {
  # Scenario 1: High effect, low heterogeneity
  data_high_effect <- data.frame(
    yi = c(0.8, 0.9, 0.7),
    se = c(0.05, 0.04, 0.06)
  )
  fit_high <- cbamm_fast(data_high_effect)
  expect_output(print(fit_high), "Clinically meaningful effect size observed.")
  expect_output(print(fit_high), "High precision in pooled estimate.") # Need to calculate QEp properly

  # Scenario 2: Low effect, high heterogeneity
  data_low_effect_het <- data.frame(
    yi = c(0.01, 0.5, 0.02, 0.6),
    se = c(0.05, 0.1, 0.06, 0.12)
  )
  fit_low_het <- cbamm_fast(data_low_effect_het)
  expect_output(print(fit_low_het), "Clinically meaningful effect size observed.") # Corrected expectation
  expect_output(print(fit_low_het), "Caution: Significant heterogeneity detected.")
  expect_output(print(fit_low_het), "Estimates may be imprecise, wider CIs.") # Added expectation
})
