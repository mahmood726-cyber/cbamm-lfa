library(testthat)
library(cbamm)

context("CBAMM Trial Sequential Analysis (TSA)")

test_that("TSA parameters are processed correctly", {
  data_tsa <- data.frame(
    yi = c(0.1, 0.2, 0.05, 0.3, 0.15, 0.25, 0.1, 0.2, 0.3, 0.1),
    se = c(0.05, 0.06, 0.04, 0.08, 0.07, 0.05, 0.06, 0.04, 0.08, 0.07)
  )
  
  # TSA enabled, with specified alternative effect
  tsa_result_enabled <- cumulative_meta_analysis(
    data_tsa,
    order_by = "year",
    tsa_alpha = 0.05,
    tsa_beta = 0.10,
    tsa_effect_null = 0,
    tsa_effect_alt = 0.2 # Clinically meaningful effect
  )
  
  expect_true(tsa_result_enabled$tsa_enabled)
  expect_true(is.numeric(tsa_result_enabled$tsa_info_size))
  expect_true(all(!is.na(tsa_result_enabled$results$tsa_z)))
  
  # TSA disabled by default if alt effect not specified
  tsa_result_disabled <- cumulative_meta_analysis(data_tsa)
  expect_false(tsa_result_disabled$tsa_enabled)
})

test_that("TSA boundaries are calculated and monitored", {
  data_tsa_strong <- data.frame(
    yi = c(0.8, 0.9, 0.7, 1.0, 0.95, 0.85, 0.9, 0.75, 1.05, 0.8), # Strong effect
    se = c(0.1, 0.12, 0.08, 0.15, 0.11, 0.1, 0.12, 0.08, 0.15, 0.11)
  )
  
  tsa_strong_effect <- cumulative_meta_analysis(
    data_tsa_strong,
    order_by = "year",
    tsa_alpha = 0.05,
    tsa_beta = 0.10,
    tsa_effect_null = 0,
    tsa_effect_alt = 0.5 # Clinically meaningful effect
  )
  
  # Expect that boundaries are present and some monitoring might occur
  expect_true(tsa_strong_effect$tsa_enabled)
  expect_true(any(tsa_strong_effect$results$tsa_monitoring_stop))
  
  # Test with an effect that does not cross boundary
  data_tsa_weak <- data.frame(
    yi = c(0.01, 0.02, 0.03, 0.01, 0.02, 0.03, 0.01, 0.02, 0.03, 0.01),
    se = c(0.1, 0.12, 0.08, 0.15, 0.11, 0.1, 0.12, 0.08, 0.15, 0.11)
  )
  tsa_weak_effect <- cumulative_meta_analysis(
    data_tsa_weak,
    order_by = "year",
    tsa_alpha = 0.05,
    tsa_beta = 0.10,
    tsa_effect_null = 0,
    tsa_effect_alt = 0.5 # Clinically meaningful effect
  )
  expect_false(any(tsa_weak_effect$results$tsa_monitoring_stop))
})

test_that("TSA information size calculation handles NA and zero meaningfully", {
  expect_warning(calculate_information_size(target_var = 1, alpha = 0.05, beta = 0.1, effect_null = 0, effect_alt = NA), "Cannot calculate information size")
  expect_warning(calculate_information_size(target_var = 1, alpha = 0.05, beta = 0.1, effect_null = 0, effect_alt = 0), "Cannot calculate information size")
  
  # A positive non-NA value should not warn and produce a number
  res_info <- calculate_information_size(target_var = 1, alpha = 0.05, beta = 0.1, effect_null = 0, effect_alt = 0.1)
  expect_true(is.numeric(res_info))
  expect_true(res_info > 0)
})

