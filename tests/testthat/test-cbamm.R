test_that("cbamm_fast performs basic meta-analysis", {
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
})
