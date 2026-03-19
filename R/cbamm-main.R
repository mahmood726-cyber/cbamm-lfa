# CBAMM: Collaborative Bayesian Adaptive Meta-Analysis Methods
# Consolidated Development File
# All working functions in a single file to prevent architectural drift

# =============================================================================
# PACKAGE DOCUMENTATION AND IMPORTS
# =============================================================================

#' CBAMM: Collaborative Bayesian Adaptive Meta-Analysis Methods
#'
#' Provides tools for cumulative meta-analysis with stability assessment,
#' transport weights for generalizability, fast random-effects models, and
#' visualization functions for meta-analytic results.
#'
#' @keywords internal
"_PACKAGE"

#' @import stats
#' @importFrom stats qnorm pnorm binomial glm density approxfun
#' @import graphics
#' @import utils
#' @import methods
NULL

# Suppress R CMD check notes
utils::globalVariables(c(
    "yi", "vi", "se", "study_id", "effect", "variance",
    "estimate", "ci_lower", "ci_upper", "precision",
    "n_studies", "cumulative_z", "boundaries", "study",
    "lower", "upper", "p_value", "significant",
    "tsa_z", "tsa_boundary_lower", "tsa_boundary_upper", "tsa_info_fraction",
    "tsa_monitoring_stop", "cumulative_info_sum_inv_var", "coda"
))

# =============================================================================
# CORE DATA HANDLING FUNCTIONS
# =============================================================================

#' Validate CBAMM Data
#' @param data Data frame to validate
#' @return Validated data frame with yi and vi columns
#' @export
validate_cbamm_data <- function(data) {
  if (!is.data.frame(data)) data <- as.data.frame(data)

  # Map alternative column names to standard ones
  if ("effect_size" %in% names(data) && !"yi" %in% names(data)) {
    data$yi <- data$effect_size
  }
  if ("variance" %in% names(data) && !"vi" %in% names(data)) {
    data$vi <- data$variance
  } else if ("se" %in% names(data) && !"vi" %in% names(data)) {
    data$vi <- data$se^2
  } else if ("standard_error" %in% names(data) && !"vi" %in% names(data)) {
    data$vi <- data$standard_error^2
  }

  if (!all(c("yi", "vi") %in% names(data))) {
    stop("Missing required columns. Data must contain yi/vi or equivalent columns")
  }

  data$yi <- as.numeric(data$yi)
  data$vi <- as.numeric(data$vi)

  # Remove missing values
  complete_rows <- complete.cases(data$yi, data$vi)
  if (sum(!complete_rows) > 0) {
    warning(paste("Removed", sum(!complete_rows), "rows with missing values"))
    data <- data[complete_rows, ]
  }

  # Remove non-positive variances
  if (any(data$vi <= 0)) {
    warning("Some variances are non-positive. Removing these studies.")
    data <- data[data$vi > 0, ]
  }

  return(data)
}

#' Standardize CBAMM Data
#' @param data Data frame to standardize
#' @param verbose Logical for verbose output
#' @return Standardized data frame
#' @export
standardize_cbamm_data <- function(data, verbose = FALSE) {
  if (!"study_id" %in% names(data)) {
    data$study_id <- paste0("Study_", seq_len(nrow(data)))
    if (verbose) message("Created study_id column")
  }

  if ("se" %in% names(data) && !"vi" %in% names(data)) {
    data$vi <- data$se^2
    if (verbose) message("Converted se to vi")
  }

  if ("sei" %in% names(data) && !"vi" %in% names(data)) {
    data$vi <- data$sei^2
    if (verbose) message("Converted sei to vi")
  }

  return(data)
}

# =============================================================================
# CORE META-ANALYSIS FUNCTIONS
# =============================================================================

#' Fast Meta-Analysis
#' @param data Data frame with effect sizes
#' @param method Estimation method ("REML", "DL", "ML")
#' @param confidence_level Confidence level for CIs (default: 0.95)
#' @return CBAMM meta-analysis object
#' @export
cbamm_fast <- function(data, method = "REML", confidence_level = 0.95) {
  if (!inherits(data, "cbamm_data")) {
    data <- standardize_cbamm_data(data)
  }

  data <- validate_cbamm_data(data)

  n <- nrow(data)
  yi <- data$yi
  vi <- data$vi
  sei <- sqrt(vi) # Recalculate sei for metafor

  # Leverage metafor if available for more robust tau2 estimation
  if (requireNamespace("metafor", quietly = TRUE)) {
    tryCatch({
      # Use metafor's rma.uni for more sophisticated tau2 estimation
      mf_res <- metafor::rma.uni(yi = yi, vi = vi, method = method)
      
      result <- list(
        b = as.numeric(mf_res$b),
        se = as.numeric(mf_res$se),
        tau2 = as.numeric(mf_res$tau2),
        tau = as.numeric(mf_res$tau),
        I2 = as.numeric(mf_res$I2),
        H2 = as.numeric(mf_res$H2),
        k = as.numeric(mf_res$k),
        QE = as.numeric(mf_res$QE),
        QEp = as.numeric(mf_res$QEp),
        ci.lb = as.numeric(mf_res$ci.lb),
        ci.ub = as.numeric(mf_res$ci.ub),
        pi.lb = as.numeric(mf_res$yi.pred.lb), # Use metafor's prediction interval
        pi.ub = as.numeric(mf_res$yi.pred.ub),
        data = data,
        method = method
      )
      
      class(result) <- "cbamm"
      return(result)
      
    }, error = function(e) {
      warning("metafor::rma.uni failed, falling back to internal approximation: ", e$message)
      # Fallback to internal approximation
    })
  }

  # Fallback internal approximation (original cbamm_fast logic)
  wi <- 1/vi
  theta_fe <- sum(wi * yi) / sum(wi)
  Q <- sum(wi * (yi - theta_fe)^2)
  df <- n - 1

  # Tau-squared estimation
  tau2 <- max(0, (Q - df) / (sum(wi) - sum(wi^2)/sum(wi)))
  if (method == "REML" && n > 1) { # Refine REML approximation
    for (iter in 1:100) { # Increased iterations for better convergence
      wi_new <- 1/(vi + tau2)
      theta_new <- sum(wi_new * yi) / sum(wi_new)
      Q_new <- sum(wi_new * (yi - theta_new)^2)
      
      # DerSimonian-Laird for tau2 calc with new weights
      new_C <- sum(wi_new) - sum(wi_new^2)/sum(wi_new)
      tau2_new <- max(0, (Q_new - df) / new_C)
      if (abs(tau2_new - tau2) < 1e-4) break
      tau2 <- tau2_new
    }
  }

  # Random effects estimate
  wi_re <- 1/(vi + tau2)
  theta_re <- sum(wi_re * yi) / sum(wi_re)
  se_re <- sqrt(1/sum(wi_re))

  # I-squared
  I2 <- if (Q > df) 100 * (Q - df) / Q else 0

  result <- list(
    b = theta_re,
    se = se_re,
    tau2 = tau2,
    tau = sqrt(tau2),
    I2 = I2,
    H2 = if (df > 0) Q/df else 1,
    k = n,
    QE = Q,
    QEp = if (df > 0) pchisq(Q, df, lower.tail = FALSE) else NA,
    ci.lb = theta_re - qnorm(1 - (1 - confidence_level) / 2) * se_re, # Use qnorm for CI
    ci.ub = theta_re + qnorm(1 - (1 - confidence_level) / 2) * se_re,
    pi.lb = theta_re - qnorm(1 - (1 - confidence_level) / 2) * sqrt(se_re^2 + tau2), # Use qnorm for PI
    pi.ub = theta_re + qnorm(1 - (1 - confidence_level) / 2) * sqrt(se_re^2 + tau2),
    data = data,
    method = method
  )

  class(result) <- "cbamm"
  return(result)
}

#' Robust Meta-Analysis Wrapper
#' @param yi Effect sizes
#' @param sei Standard errors
#' @param method Estimation method
#' @param ... Additional arguments
#' @return Meta-analysis result
#' @export
robust_rma <- function(yi, sei, method = "REML", ...) {
  if (length(yi) < 3) stop("Need at least 3 studies for meta-analysis")

  args <- list(yi = yi, sei = sei, method = method, ...)

  if (requireNamespace("metafor", quietly = TRUE)) {
    tryCatch({
      metafor::rma(yi = yi, sei = sei, method = method, ...)
    }, error = function(e) {
      warning("metafor failed, using basic implementation")
      # Basic fallback
      weights <- 1/sei^2
      estimate <- sum(yi * weights) / sum(weights)
      list(beta = estimate, se = sqrt(1/sum(weights)))
    })
  } else {
    weights <- 1/sei^2
    estimate <- sum(yi * weights) / sum(weights)
    list(beta = estimate, se = sqrt(1/sum(weights)))
  }
}

# =============================================================================
# CUMULATIVE META-ANALYSIS (Core Innovation)
# =============================================================================

#' Cumulative Meta-Analysis
#' @param data Data frame with study data
#' @param order_by Variable to order studies by (e.g., "year", "precision")
#' @param order_direction Direction of ordering ("ascending" or "descending")
#' @param method Analysis method (e.g., "REML", "DL")
#' @param confidence_level Confidence level (e.g., 0.95)
#' @param minimum_studies Minimum studies required to start analysis (default: 2)
#' @param tsa_alpha Total alpha level for TSA
#' @param tsa_beta Total beta level for TSA
#' @param tsa_effect_null Effect size under null hypothesis
#' @param tsa_effect_alt Effect size under alternative hypothesis
#' @param tsa_target_var Target variance for overall effect (optional)
#' @return A `cbamm_cumulative` object.
#' @export
cumulative_meta_analysis <- function(data,
                                     order_by = "year",
                                     order_direction = "ascending",
                                     method = "random",
                                     confidence_level = 0.95,
                                     minimum_studies = 2,
                                     tsa_alpha = 0.05,
                                     tsa_beta = 0.10,
                                     tsa_effect_null = 0,
                                     tsa_effect_alt = NA, # Must be provided for meaningful TSA
                                     tsa_target_var = NA) {

  # Validate inputs
  if (!is.data.frame(data) || nrow(data) < 2) {
    stop("Cumulative meta-analysis requires at least 2 studies")
  }

  # Prepare data
  data <- validate_cbamm_data(data)

  # Order data
  if (order_by == "precision" && !"precision" %in% names(data)) {
    data$precision <- 1 / sqrt(data$vi)
  }

  if (order_by %in% names(data)) {
    if (order_direction == "ascending") {
      data <- data[order(data[[order_by]]), ]
    } else {
      data <- data[order(data[[order_by]], decreasing = TRUE), ]
    }
  }

  # Reset row names
  rownames(data) <- NULL
  data$cumulative_n <- 1:nrow(data)

  # Run cumulative analysis
  n_studies <- nrow(data)
  z_value <- qnorm(1 - (1 - confidence_level) / 2)

  results <- data.frame(
    step = integer(),
    n_studies = integer(),
    estimate = numeric(),
    se = numeric(),
    ci_lower = numeric(),
    ci_upper = numeric(),
    z_value = numeric(),
    p_value = numeric(),
    tau2 = numeric(),
    i2 = numeric(),
    tsa_z = numeric(),
    tsa_boundary_lower = numeric(),
    tsa_boundary_upper = numeric(),
    tsa_info_fraction = numeric(),
    tsa_monitoring_stop = logical()
  )
  
  # --- TSA Initialization ---
  tsa_enabled <- !is.na(tsa_effect_alt)
  tsa_info_size <- NA
  if (tsa_enabled) {
      if (is.na(tsa_target_var)) {
          # Estimate target variance from final meta-analysis if not provided
          final_meta <- cbamm_fast(data, method = "REML", confidence_level = confidence_level)
          tsa_target_var <- final_meta$se^2 # This is the variance of the pooled estimate
      }
      # Information size for the effect (inverse variance)
      # Assuming alternative effect is on the same scale as 'estimate'
      tsa_info_size <- calculate_information_size(tsa_target_var, tsa_alpha, tsa_beta, tsa_effect_null, tsa_effect_alt)
      
      if (is.na(tsa_info_size) || tsa_info_size <= 0) {
          warning("TSA: Information size cannot be calculated. Disabling TSA.")
          tsa_enabled <- FALSE
      } else {
          message(sprintf("TSA: Calculated Information Size: %.2f (inverse variance units)", tsa_info_size))
      }
  }
  
  cumulative_info_sum_inv_var <- 0 # Sum of 1/variance for current studies
  
  for (i in minimum_studies:n_studies) {
    current_data <- data[1:i, ]
    meta_result <- cbamm_fast(current_data, method = "REML", confidence_level = confidence_level)
    
    current_z <- meta_result$b / meta_result$se
    current_info <- 1/meta_result$se^2 # Information (inverse variance)
    
    # --- TSA Calculations for current step ---
    tsa_z_val <- NA
    tsa_bound_lower <- NA
    tsa_bound_upper <- NA
    tsa_frac <- NA
    tsa_stop <- FALSE
    
    if (tsa_enabled) {
      tsa_frac <- current_info / tsa_info_size
      tsa_frac <- min(tsa_frac, 1.0) # Cap at 1
      
      alpha_spend <- alpha_spending_obf(tsa_frac * nrow(data), nrow(data), tsa_alpha) # approximate k
      
      # Use an explicit Z-score for boundaries
      tsa_z_bound <- qnorm(1 - alpha_spend/2) 
      tsa_bound_lower <- -tsa_z_bound
      tsa_bound_upper <- tsa_z_bound
      
      tsa_z_val <- current_z # The Z-score of the current cumulative meta-analysis
      
      if (abs(tsa_z_val) > tsa_z_bound && tsa_frac >= 0.25) { # Only allow stopping after certain info fraction
          tsa_stop <- TRUE
          message(sprintf("TSA: Monitoring boundary crossed at %d studies. Z=%.2f, Boundary=%.2f", i, tsa_z_val, tsa_z_bound))
      }
    }
    
    results <- rbind(results, data.frame(
      step = i - minimum_studies + 1,
      n_studies = i,
      estimate = meta_result$b,
      se = meta_result$se,
      ci_lower = meta_result$ci.lb,
      ci_upper = meta_result$ci.ub,
      z_value = current_z,
      p_value = 2 * pnorm(abs(current_z), lower.tail = FALSE),
      tau2 = meta_result$tau2,
      i2 = meta_result$I2,
      tsa_z = tsa_z_val,
      tsa_boundary_lower = tsa_bound_lower,
      tsa_boundary_upper = tsa_bound_upper,
      tsa_info_fraction = tsa_frac,
      tsa_monitoring_stop = tsa_stop
    ))
    
    if (tsa_stop) {
      message("TSA: Monitoring boundary crossed. Stopping cumulative analysis prematurely.")
      break
    }
  }

  # Calculate stability metrics
  if (nrow(results) >= 3) {
    estimates <- results$estimate
    changes <- abs(diff(estimates))
    relative_changes <- changes / abs(estimates[-1])

    stability_achieved <- FALSE
    stability_point <- NA

    if (length(relative_changes) >= 3) {
      last_changes <- tail(relative_changes, 3)
      stability_achieved <- all(last_changes < 0.05, na.rm = TRUE)

      if (stability_achieved) {
        for (j in 3:(length(relative_changes))) {
          if (all(relative_changes[j:(j+2)] < 0.05, na.rm = TRUE)) {
            stability_point <- results$n_studies[j+2]
            break
          }
        }
      }
    }

    stability <- list(
      stability_achieved = stability_achieved,
      stability_point = stability_point,
      relative_changes = relative_changes
    )
  } else {
    stability <- list(
      stability_achieved = FALSE,
      stability_point = NA,
      relative_changes = numeric(0)
    )
  }

  # Evidence sufficiency assessment
  final_result <- tail(results, 1)
  sufficiency <- list(
    sufficient = final_result$p_value < 0.05 && final_result$n_studies >= 10,
    is_significant = final_result$p_value < 0.05,
    adequate_sample = final_result$n_studies >= 10,
    final_estimate = final_result$estimate
  )

  result <- list(
    data = data,
    results = results,
    stability = stability,
    sufficiency = sufficiency,
    order_by = order_by,
    method = method,
    confidence_level = confidence_level,
    tsa_info_size = tsa_info_size,
    tsa_enabled = tsa_enabled
  )

  class(result) <- "cbamm_cumulative"
  return(result)
}

# =============================================================================
# HETEROGENEITY AND DIAGNOSTICS
# =============================================================================

#' Calculate I-squared Statistic
#' @param Q Cochran's Q statistic
#' @param df Degrees of freedom
#' @return I-squared value and confidence intervals
#' @export
calculate_i2 <- function(Q, df) {
  I2 <- max(0, (Q - df) / Q * 100)

  if (Q > df) {
    chi_lower <- qchisq(0.025, df)
    chi_upper <- qchisq(0.975, df)
    I2_lower <- max(0, (Q - chi_upper) / Q * 100)
    I2_upper <- min(100, (Q - chi_lower) / Q * 100)
  } else {
    I2_lower <- 0
    I2_upper <- 0
  }

  list(
    I2 = I2,
    ci_lower = I2_lower,
    ci_upper = I2_upper,
    interpretation = ifelse(I2 < 25, "Low",
                            ifelse(I2 < 50, "Moderate",
                                   ifelse(I2 < 75, "Substantial", "Considerable")))
  )
}

#' Calculate Tau-squared
#' @param Q Cochran's Q statistic
#' @param df Degrees of freedom
#' @param weights Study weights
#' @return Tau-squared estimate
#' @export
calculate_tau2 <- function(Q, df, weights) {
  if (Q > df) {
    C <- sum(weights) - sum(weights^2) / sum(weights)
    tau2 <- (Q - df) / C
  } else {
    tau2 <- 0
  }

  list(
    tau2 = tau2,
    tau = sqrt(tau2),
    method = "DerSimonian-Laird"
  )
}

#' Prediction Interval
#' @param estimate Overall effect estimate
#' @param se Standard error
#' @param tau2 Between-study variance
#' @param df Degrees of freedom
#' @return Prediction interval
#' @export
prediction_interval <- function(estimate, se, tau2, df) {
  t_crit <- qt(0.975, df)
  pred_se <- sqrt(se^2 + tau2)
  pi_lower <- estimate - t_crit * pred_se
  pi_upper <- estimate + t_crit * pred_se

  list(
    pi_lower = pi_lower,
    pi_upper = pi_upper,
    pred_se = pred_se
  )
}

# --- Trial Sequential Analysis (TSA) Helpers ---

#' Calculate Alpha-Spending Function (O'Brien-Fleming type)
#' @param k Current number of studies
#' @param K Total expected number of studies (or maximum k)
#' @param alpha_total Total alpha level (e.g., 0.05)
#' @return Alpha-spending value
#' @keywords internal
#' @noRd
alpha_spending_obf <- function(k, K, alpha_total) {
  if (k <= 0 || K <= 0 || k > K) return(0)
  alpha_total * log(1 + (exp(1) - 1) * (k/K)^2) # A simple O'Brien-Fleming like approximation
}

#' Calculate Variance-Adjusted Information Size (DeMets & Lan)
#'
#' This function calculates the Required Information Size (IS) based on the
#' pre-specified alpha, beta, and expected effect size (Delta).
#' Formula: IS = ((Z_alpha + Z_beta)^2 * sigma^2) / Delta^2
#'
#' @param target_var The target variance for the overall effect
#' @param alpha Type I error rate
#' @param beta Type II error rate
#' @param effect_null Null hypothesis effect size
#' @param effect_alt Alternative hypothesis effect size (clinically meaningful effect)
#' @return Required information size (inverse variance scale)
#' @keywords internal
#' @noRd
calculate_information_size <- function(target_var, alpha, beta, effect_null, effect_alt) {
  z_alpha <- qnorm(1 - alpha/2)
  z_beta <- qnorm(1 - beta)
  
  # Information = 1/variance.
  # IS = (z_alpha + z_beta)^2 / (effect_alt - effect_null)^2
  # To make it variance-adjusted information, we need to scale it.
  # A more practical way is to find the variance that gives desired power.
  # Let's target the number of "effective" studies.
  
  # Simplistic approach: directly target the variance of the overall effect.
  # This implies the power calculation is for the final meta-analysis.
  # A robust target_var might come from a large well-powered individual study or a previous meta-analysis.
  
  # More accurately: Information is (1/variance)
  # So, total information = 1/Target_variance_of_pooled_effect
  # IS = (z_alpha + z_beta)^2 / (target_effect_size)^2
  # For variance-adjusted, it's sum(1/vi_i) or sum(1/(se_i^2 + tau2))
  # Let's return the "inverse variance" equivalent
  
  if (is.na(effect_alt) || is.na(effect_null) || (effect_alt - effect_null) == 0) {
    warning("Cannot calculate information size without a meaningful alternative hypothesis effect size.")
    return(NA)
  }
  
  IS_value <- (z_alpha + z_beta)^2 / (effect_alt - effect_null)^2
  
  # Return the target inverse variance (total information)
  return(IS_value) 
}

# =============================================================================
# TRANSPORT WEIGHTS (Innovation)
# =============================================================================

#' Compute Transport Weights for Generalizability
#' @param data Study data with covariate information
#' @param target_population Target population characteristics
#' @param truncation Weight truncation level
#' @return Vector of transport weights
#' @export
compute_transport_weights <- function(data, target_population, truncation = 0.02) {
  # Check for required variables
  req <- c("age_mean", "female_pct", "bmi_mean", "charlson")
  available <- intersect(req, names(data))

  if (length(available) == 0) {
    warning("No transportability variables found. Using uniform weights.")
    return(rep(1 / nrow(data), nrow(data)))
  }

  # Use available variables
  X <- data[, available, drop = FALSE]
  X$intercept <- 1
  X <- X[, c("intercept", setdiff(names(X), "intercept"))]

  # Target moments (simplified)
  if (is.list(target_population)) {
    target_values <- sapply(available, function(var) {
      target_population[[var]] %||% mean(data[[var]], na.rm = TRUE)
    })
  } else {
    target_values <- colMeans(X[, -1], na.rm = TRUE)
  }

  target_moments <- c(1, target_values)

  # Entropy balancing
  init_weights <- rep(1 / nrow(X), nrow(X))

  obj_function <- function(lambda) {
    eta <- as.numeric(as.matrix(X) %*% lambda)
    eta <- pmin(eta, 700)  # Prevent overflow
    w <- init_weights * exp(eta)
    w <- w / sum(w)
    sum((colSums(as.matrix(X) * w) - target_moments)^2)
  }

  opt_result <- tryCatch({
    optim(par = rep(0, ncol(X)), fn = obj_function,
          control = list(maxit = 1000))
  }, error = function(e) NULL)

  if (!is.null(opt_result) && opt_result$convergence == 0) {
    weights <- init_weights * exp(as.matrix(X) %*% opt_result$par)
    weights <- as.numeric(weights / sum(weights))

    # Apply truncation
    if (truncation > 0) {
      lo <- quantile(weights, truncation)
      hi <- quantile(weights, 1 - truncation)
      weights <- pmax(pmin(weights, hi), lo)
      weights <- weights / sum(weights)
    }

    return(weights)
  } else {
    warning("Transport optimization failed; using uniform weights.")
    return(rep(1 / nrow(data), nrow(data)))
  }
}

#' Compute Analysis Weights
#' @param data Study data
#' @param transport_weights Transport weights
#' @return Analysis weights
#' @export
compute_analysis_weights <- function(data, transport_weights = NULL) {
  if (is.null(transport_weights)) {
    weights <- rep(1, nrow(data))
  } else {
    weights <- as.numeric(transport_weights)
    weights <- ifelse(is.finite(weights) & weights > 0, weights, 0)
  }
  weights / mean(weights)
}

# =============================================================================
# META-REGRESSION AND SUBGROUP ANALYSIS
# =============================================================================

#' Meta-Regression Analysis
#' @param data Data frame with meta-analysis data
#' @param formula Formula for regression
#' @param se Standard error column name
#' @return Meta-regression results
#' @export
meta_regression <- function(data, formula, se = "se") {
  if (!inherits(data, "cbamm_data")) {
    data <- standardize_cbamm_data(data)
  }

  # Extract variables
  mf <- model.frame(formula, data = data)
  y <- model.response(mf)
  X <- model.matrix(formula, data = mf)

  # Get standard errors
  if (se %in% names(data)) {
    sei <- data[[se]]
  } else if ("vi" %in% names(data)) {
    sei <- sqrt(data$vi)
  } else {
    stop("Standard error not found")
  }

  # Weighted least squares
  wi <- 1 / sei^2
  XtW <- t(X * wi)
  beta <- solve(XtW %*% X) %*% (XtW %*% y)

  # Calculate tau-squared and update
  residuals <- y - X %*% beta
  Q <- sum(wi * residuals^2)
  df_resid <- nrow(X) - ncol(X)
  tau2 <- max(0, (Q - df_resid) / sum(wi))

  # Final estimates with tau2
  wi_star <- 1 / (sei^2 + tau2)
  XtW_star <- t(X * wi_star)
  beta_final <- solve(XtW_star %*% X) %*% (XtW_star %*% y)
  se_beta <- sqrt(diag(solve(XtW_star %*% X)))

  result <- list(
    coefficients = as.vector(beta_final),
    se = se_beta,
    pval = 2 * pnorm(-abs(beta_final / se_beta)),
    tau2 = tau2,
    k = nrow(data),
    formula = formula
  )

  names(result$coefficients) <- rownames(beta_final)
  class(result) <- c("cbamm_metareg", "cbamm")
  return(result)
}

#' Subgroup Meta-Analysis
#' @param data Data frame with effect sizes
#' @param subgroup Subgroup variable name
#' @param yi Effect size column name
#' @param se Standard error column name
#' @return Subgroup analysis results
#' @export
subgroup_analysis <- function(data, subgroup, yi = "yi", se = "se") {
  if (!inherits(data, "cbamm_data")) {
    data <- standardize_cbamm_data(data)
  }

  if (!subgroup %in% names(data)) {
    stop("Subgroup variable not found")
  }

  subgroups <- unique(data[[subgroup]])
  subgroups <- subgroups[!is.na(subgroups)]

  results <- list()
  overall_result <- cbamm_fast(data)

  for (sg in subgroups) {
    sg_data <- data[data[[subgroup]] == sg & !is.na(data[[subgroup]]), ]
    if (nrow(sg_data) > 0) {
      sg_result <- cbamm_fast(sg_data)
      sg_result$subgroup <- sg
      sg_result$n_studies <- nrow(sg_data)
      results[[as.character(sg)]] <- sg_result
    }
  }

  output <- list(
    overall = overall_result,
    subgroups = results,
    subgroup.var = subgroup,
    k.total = nrow(data)
  )

  class(output) <- c("cbamm_subgroup", "cbamm")
  return(output)
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

#' Generate Multi-Persona Review for Meta-Analysis Results
#' @param x cbamm object (or cbamm_cumulative final result)
#' @param digits Number of digits to display
#' @return A character vector of review comments
#' @keywords internal
#' @noRd
multi_persona_review <- function(x, digits = 3) {
  reviews <- c()

  # Persona 1: The Strict Methodologist (Internal Validity & Bias Focus)
  p_val_Q <- if (!is.null(x$QEp)) x$QEp else NA
  is_heterogeneous <- !is.na(p_val_Q) && p_val_Q < 0.1
  
  methodologist_verdict <- if (is_heterogeneous) {
    "Caution: Significant heterogeneity detected."
  } else {
    "Evidence appears consistent. Low heterogeneity risk."
  }
  reviews <- c(reviews, paste0("[Strict Methodologist]: ", methodologist_verdict))

  # Persona 2: The Clinical Optimist (Clinical Relevance & Magnitude Focus)
  # Assuming effect size > 0.1 is 'clinically meaningful' - adjust as needed
  clinically_meaningful <- abs(x$b) > 0.1 
  optimist_verdict <- if (clinically_meaningful) {
    "Clinically meaningful effect size observed."
  } else {
    "Effect size may lack clinical importance."
  }
  reviews <- c(reviews, paste0("[Clinical Optimist]   : ", optimist_verdict))

  # Persona 3: The Conservative Statistician (Precision & Robustness Focus)
  ci_width <- abs(x$ci.ub - x$ci.lb)
  precise_estimate <- ci_width < 0.5 * abs(x$b) # CI width less than half the effect size
  statistician_verdict <- if (precise_estimate) {
    "High precision in pooled estimate."
  } else {
    "Estimates may be imprecise, wider CIs."
  }
  reviews <- c(reviews, paste0("[Cons. Statistician] : ", statistician_verdict))

  return(reviews)
}

#' Convert Standard Error to Variance
#' @param se Standard error
#' @return Variance
#' @export
se_to_var <- function(se) se^2

#' Convert Variance to Standard Error
#' @param var Variance
#' @return Standard error
#' @export
var_to_se <- function(var) sqrt(var)

#' Format P-value
#' @param p P-value
#' @return Formatted p-value string
#' @export
format_p <- function(p) {
  ifelse(p < 0.001, "< 0.001", sprintf("%.3f", p))
}

#' Format Confidence Interval
#' @param estimate Point estimate
#' @param lower Lower bound
#' @param upper Upper bound
#' @param digits Number of decimal places
#' @return Formatted CI string
#' @export
format_ci <- function(estimate, lower, upper, digits = 2) {
  sprintf("%.*f [%.*f, %.*f]", digits, estimate, digits, lower, digits, upper)
}

#' Calculate I-squared from Q statistic
#' @param Q Q statistic
#' @param df Degrees of freedom
#' @return I-squared value
#' @export
calculate_i_squared <- function(Q, df) {
  max(0, (Q - df) / Q * 100)
}

#' Detect Outliers using IQR Method
#' @param x Numeric vector
#' @return Logical vector indicating outliers
#' @export
detect_outliers_iqr <- function(x) {
  Q1 <- quantile(x, 0.25, na.rm = TRUE)
  Q3 <- quantile(x, 0.75, na.rm = TRUE)
  IQR <- Q3 - Q1
  x < (Q1 - 1.5 * IQR) | x > (Q3 + 1.5 * IQR)
}

#' Safe Division
#' @param x Numerator
#' @param y Denominator
#' @param na_value Value to return when dividing by zero
#' @return Result of division
#' @export
safe_divide <- function(x, y, na_value = NA) {
  ifelse(y == 0, na_value, x / y)
}

# Null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

# =============================================================================
# VISUALIZATION FUNCTIONS
# =============================================================================

#' Enhanced Forest Plot
#' @param data Data frame with study data
#' @param ... Additional arguments
#' @return ggplot object
#' @export
forest_plot_enhanced <- function(data, ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required for enhanced forest plots")
  }

  required_cols <- c("study", "effect", "lower", "upper")
  if (!all(required_cols %in% names(data))) {
    # Try alternative column names
    if ("study_id" %in% names(data)) data$study <- data$study_id
    if ("yi" %in% names(data)) data$effect <- data$yi
    if ("ci.lb" %in% names(data)) data$lower <- data$ci.lb
    if ("ci.ub" %in% names(data)) data$upper <- data$ci.ub
  }

  ggplot2::ggplot(data, ggplot2::aes(x = effect, y = study)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_errorbarh(ggplot2::aes(xmin = lower, xmax = upper), height = 0.2) +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", alpha = 0.5) +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = "Effect Size", y = "Study", title = "Forest Plot")
}

#' Create Cumulative Analysis Dashboard
#' @param x cbamm_cumulative object
#' @param save_plot Whether to save plot
#' @param filename Filename for saving
#' @return Dashboard plots
#' @export
create_cumulative_dashboard <- function(x, save_plot = FALSE, filename = "dashboard.png") {
  if (!inherits(x, "cbamm_cumulative")) {
    stop("Input must be a cbamm_cumulative object")
  }

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 package required for dashboard plotting")
  }

  data <- x$results

  # Effect size evolution
  p1 <- ggplot2::ggplot(data, ggplot2::aes(x = n_studies, y = estimate)) +
    ggplot2::geom_line(linewidth = 1.2, color = "blue") +
    ggplot2::geom_point(size = 2.5, color = "blue") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = ci_lower, ymax = ci_upper),
                         alpha = 0.3, fill = "blue") +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
    ggplot2::labs(title = "Effect Size Evolution", x = "Number of Studies",
                  y = "Cumulative Effect Size") +
    ggplot2::theme_minimal()

  # Statistical significance
  data$significant <- data$p_value < 0.05
  p2 <- ggplot2::ggplot(data, ggplot2::aes(x = n_studies, y = -log10(p_value))) +
    ggplot2::geom_line(linewidth = 1.2, color = "orange") +
    ggplot2::geom_point(ggplot2::aes(color = significant), size = 2.5) +
    ggplot2::geom_hline(yintercept = -log10(0.05), linetype = "dashed", color = "red") +
    ggplot2::scale_color_manual(values = c("FALSE" = "gray", "TRUE" = "orange")) +
    ggplot2::labs(title = "Statistical Significance", x = "Number of Studies",
                  y = "-log10(p-value)") +
    ggplot2::theme_minimal()

  if (requireNamespace("gridExtra", quietly = TRUE)) {
    combined_plot <- gridExtra::grid.arrange(p1, p2, ncol = 2)
    if (save_plot) {
      ggplot2::ggsave(filename, combined_plot, width = 12, height = 6, dpi = 300)
      cat("Dashboard saved as:", filename, "\n")
    }
    return(combined_plot)
  } else {
    print(p1)
    print(p2)
    return(list(p1 = p1, p2 = p2))
  }
}

#' Plot Bayesian Diagnostics
#' @param x cbamm_bayesian object
#' @return A grid of diagnostic plots
#' @export
plot_bayesian_diagnostics <- function(x) {
  if (!inherits(x, "cbamm_bayesian")) {
    stop("Input must be a cbamm_bayesian object")
  }

  if (!requireNamespace("ggplot2", quietly = TRUE) || !requireNamespace("gridExtra", quietly = TRUE)) {
    stop("ggplot2 and gridExtra packages required for diagnostic plotting")
  }

  # Prepare data for mu
  mu_data <- data.frame(
    iteration = 1:length(x$mu_posterior),
    value = as.numeric(x$mu_posterior)
  )

  p1 <- ggplot2::ggplot(mu_data, ggplot2::aes(x = iteration, y = value)) +
    ggplot2::geom_line(color = "steelblue") +
    ggplot2::labs(title = "Trace Plot: Overall Effect (mu)", x = "Iteration", y = "Value") +
    ggplot2::theme_minimal()

  p2 <- ggplot2::ggplot(mu_data, ggplot2::aes(x = value)) +
    ggplot2::geom_density(fill = "steelblue", alpha = 0.5) +
    ggplot2::labs(title = "Posterior Density: mu", x = "Value", y = "Density") +
    ggplot2::theme_minimal()

  # Prepare data for tau
  tau_data <- data.frame(
    iteration = 1:length(x$tau_posterior),
    value = as.numeric(x$tau_posterior)
  )

  p3 <- ggplot2::ggplot(tau_data, ggplot2::aes(x = iteration, y = value)) +
    ggplot2::geom_line(color = "darkorange") +
    ggplot2::labs(title = "Trace Plot: Heterogeneity (tau)", x = "Iteration", y = "Value") +
    ggplot2::theme_minimal()

  p4 <- ggplot2::ggplot(tau_data, ggplot2::aes(x = value)) +
    ggplot2::geom_density(fill = "darkorange", alpha = 0.5) +
    ggplot2::labs(title = "Posterior Density: tau", x = "Value", y = "Density") +
    ggplot2::theme_minimal()

  gridExtra::grid.arrange(p1, p2, p3, p4, ncol = 2)
}

# =============================================================================
# S3 METHODS
# =============================================================================

#' Print CBAMM Results
#' @param x CBAMM object
#' @param digits Number of digits to display
#' @param ... Additional arguments
#' @export
print.cbamm <- function(x, digits = 4, ...) {
  cat("\nRandom-Effects Model (k =", x$k, ")\n\n")
  cat("tau^2 =", formatC(x$tau2, digits = digits), "; ")
  cat("tau =", formatC(x$tau, digits = digits), "; ")
  cat("I^2 =", formatC(x$I2, digits = 1), "%\n")
  cat("H^2 =", formatC(x$H2, digits = 2), "\n\n")

  cat("Test for Heterogeneity:\n")
  cat("Q(df =", x$k - 1, ") =", formatC(x$QE, digits = 2),
      ", p-val =", formatC(x$QEp, digits = 4), "\n\n")

  cat("Model Results:\n\n")
  cat("estimate      se     ci.lb     ci.ub\n")
  cat(sprintf("%8.4f %7.4f %8.4f %8.4f\n",
              x$b, x$se, x$ci.lb, x$ci.ub))
  
  # Multi-Persona Review
  cat("\nMULTI-PERSONA RESEARCH SYNTHESIS REVIEW:\n")
  for (review_line in multi_persona_review(x)) {
    cat(review_line, "\n")
  }

  invisible(x)
}

#' Summary CBAMM Results
#' @param object CBAMM object
#' @param ... Additional arguments
#' @export
summary.cbamm <- function(object, ...) {
  print(object, ...)
}

#' Print Cumulative Results
#' @param x cbamm_cumulative object
#' @param ... Additional arguments
#' @export
print.cbamm_cumulative <- function(x, ...) {
  cat("Cumulative Meta-Analysis Results\n")
  cat("================================\n\n")

  cat("Ordering:", x$order_by, "\n")
  cat("Method:", x$method, "\n")
  cat("Total studies:", max(x$results$n_studies), "\n")
  cat("Analysis steps:", nrow(x$results), "\n\n")

  final_result <- tail(x$results, 1)
  cat("Final Results:\n")
  cat("Estimate:", round(final_result$estimate, 4), "\n")
  cat("95% CI: [", round(final_result$ci_lower, 4), ", ",
      round(final_result$ci_upper, 4), "]\n")
  cat("P-value:", format_p(final_result$p_value), "\n")
  cat("I-squared:", round(final_result$i2, 1), "%\n\n")

  if (x$stability$stability_achieved) {
    cat("Evidence stability: Achieved")
    if (!is.na(x$stability$stability_point)) {
      cat(" (at", x$stability$stability_point, "studies)")
    }
    cat("\n")
  } else {
    cat("Evidence stability: Not yet achieved\n")
  }

  cat("Evidence sufficiency:", if(x$sufficiency$sufficient) "Sufficient" else "Insufficient", "\n")

  # Multi-Persona Review for the final estimate
  cat("\nMULTI-PERSONA RESEARCH SYNTHESIS REVIEW (Final Estimate):\n")
  final_meta_result <- cbamm_fast(tail(x$data,1)) # Re-run cbamm_fast on the final data point for persona review
  for (review_line in multi_persona_review(final_meta_result)) {
    cat(review_line, "\n")
  }

  invisible(x)
}

#' Print Meta-regression Results
#' @param x cbamm_metareg object
#' @param digits Number of digits
#' @param ... Additional arguments
#' @export
print.cbamm_metareg <- function(x, digits = 3, ...) {
  cat("\nMeta-Regression Results\n")
  cat("Studies:", x$k, "\n\n")

  coef_table <- data.frame(
    Estimate = x$coefficients,
    SE = x$se,
    p_value = x$pval
  )
  print(round(coef_table, digits))

  cat("\nResidual tau-squared:", round(x$tau2, 4), "\n")
  invisible(x)
}

#' Print Subgroup Results
#' @param x cbamm_subgroup object
#' @param ... Additional arguments
#' @export
print.cbamm_subgroup <- function(x, ...) {
  cat("\nSubgroup Meta-Analysis\n")
  cat("Overall Effect:", round(x$overall$b, 3), "\n")
  cat("\nSubgroup Results:\n")
  for (name in names(x$subgroups)) {
    sg <- x$subgroups[[name]]
    cat("  ", name, " (k=", sg$n_studies, "): ", round(sg$b, 3), "\n", sep="")
  }
  invisible(x)
}

# =============================================================================
# TESTING FUNCTION
# =============================================================================

#' Test CBAMM Installation
#' @return Test results (invisible)
#' @export
test_cbamm <- function() {
  cat("Testing CBAMM package...\n")

  # Create test data
  test_data <- data.frame(
    yi = c(0.1, 0.2, 0.3, 0.4, 0.5),
    se = c(0.05, 0.06, 0.04, 0.08, 0.07)
  )

  # Run analysis
  result <- cbamm_fast(test_data)

  cat("Test successful!\n")
  cat("Effect estimate:", round(result$b, 3), "\n")
  cat("Tau-squared:", round(result$tau2, 4), "\n")
  cat("I-squared:", round(result$I2, 1), "%\n")

  return(invisible(result))
}

# =============================================================================
# END OF CONSOLIDATED CBAMM PACKAGE
# =============================================================================

# =============================================================================
# BAYESIAN META-ANALYSIS (Novel Method)
# =============================================================================

#' Bayesian Random-Effects Meta-Analysis with Bayes Factors
#'
#' @param data Data frame with effect sizes (yi) and variances (vi).
#' @param n_iter Number of MCMC iterations.
#' @param n_burnin Number of burn-in iterations.
#' @param mu_prior_mean Mean of the normal prior for the overall effect size (mu).
#' @param mu_prior_sd Standard deviation of the normal prior for mu.
#' @param tau_prior_dist Distribution of the prior for heterogeneity (tau). Currently supports "half-cauchy".
#' @param tau_prior_scale Scale parameter for the tau prior.
#' @return A `cbamm_bayesian` object with posterior summaries and Bayes Factors.
#' @export
cbamm_bayesian <- function(data,
                           n_iter = 10000,
                           n_burnin = 2000,
                           mu_prior_mean = 0,
                           mu_prior_sd = 1,
                           tau_prior_dist = "half-cauchy",
                           tau_prior_scale = 0.5) {

  data <- validate_cbamm_data(data)
  k <- nrow(data)
  yi <- data$yi
  vi <- data$vi

  # --- MCMC Gibbs Sampler ---
  # Priors
  mu_0 <- mu_prior_mean
  V_mu <- mu_prior_sd^2

  # Starting values
  mu <- mean(yi)
  tau2 <- var(yi)
  theta <- yi

  # MCMC storage
  mu_chain <- numeric(n_iter)
  tau2_chain <- numeric(n_iter)
  theta_chains <- matrix(0, nrow = n_iter, ncol = k)

  for (i in 1:(n_iter + n_burnin)) {
    # 1. Sample mu
    V_mu_post <- 1 / (1/V_mu + sum(1/(vi + tau2)))
    mu_post <- V_mu_post * (mu_0/V_mu + sum(theta / (vi + tau2)))
    mu <- rnorm(1, mu_post, sqrt(V_mu_post))

    # 2. Sample theta_i (study-specific effects)
    V_theta_post <- 1 / (1/vi + 1/tau2)
    theta_post <- V_theta_post * (yi/vi + mu/tau2)
    theta <- rnorm(k, theta_post, sqrt(V_theta_post))

    # 3. Sample tau2 (using Metropolis-Hastings for Half-Cauchy)
    tau2_current <- tau2
    tau2_prop <- abs(tau2_current + rnorm(1, 0, 0.1)) # Proposal

    # Log-likelihood of data given theta
    log_lik_prop <- sum(dnorm(theta, mu, sqrt(tau2_prop), log = TRUE))
    log_lik_current <- sum(dnorm(theta, mu, sqrt(tau2_current), log = TRUE))

    # Log-prior (Half-Cauchy for tau)
    log_prior_prop <- log(2 * dcauchy(sqrt(tau2_prop), 0, tau_prior_scale))
    log_prior_current <- log(2 * dcauchy(sqrt(tau2_current), 0, tau_prior_scale))
    
    # Acceptance probability
    log_r <- (log_lik_prop + log_prior_prop) - (log_lik_current + log_prior_current)
    if (log(runif(1)) < log_r) {
      tau2 <- tau2_prop
    }

    # Store samples after burn-in
    if (i > n_burnin) {
      idx <- i - n_burnin
      mu_chain[idx] <- mu
      tau2_chain[idx] <- tau2
      theta_chains[idx, ] <- theta
    }
  }

  # --- Posterior Summaries ---
  mu_posterior <- coda::mcmc(mu_chain)
  tau_posterior <- coda::mcmc(sqrt(tau2_chain))

  summary_mu <- summary(mu_posterior)
  summary_tau <- summary(tau_posterior)

  # --- Bayes Factor Calculation (Savage-Dickey Density Ratio) ---
  # BF10 for mu (H1: mu != 0 vs H0: mu = 0)
  prior_mu_at_0 <- dnorm(0, mu_prior_mean, mu_prior_sd)
  dens_mu <- stats::density(mu_posterior)
  posterior_mu_at_0 <- approxfun(dens_mu$x, dens_mu$y, rule = 2)(0)
  bf10_mu <- prior_mu_at_0 / posterior_mu_at_0

  # BF_het for tau (H1: tau > 0 vs H0: tau = 0)
  prior_tau_at_0 <- 2 * dcauchy(0, 0, tau_prior_scale)
  dens_tau <- stats::density(tau_posterior, from = 0)
  posterior_tau_at_0 <- approxfun(dens_tau$x, dens_tau$y, rule = 2)(0)
  bf_het <- prior_tau_at_0 / posterior_tau_at_0

  result <- list(
    mu_summary = summary_mu,
    tau_summary = summary_tau,
    bf10_mu = bf10_mu,
    bf_het = bf_het,
    mu_posterior = mu_posterior,
    tau_posterior = tau_posterior,
    data = data
  )

  class(result) <- "cbamm_bayesian"
  return(result)
}


#' Print Bayesian CBAMM Results
#' @param x cbamm_bayesian object
#' @param digits Number of digits to display
#' @param ... Additional arguments
#' @export
print.cbamm_bayesian <- function(x, digits = 3, ...) {
  cat("\nBayesian Random-Effects Model (", nrow(x$mu_posterior), " MCMC iterations)\n\n", sep = "")
  
  cat("Posterior Summary for Overall Effect (mu):\n")
  mu_stats <- x$mu_summary$statistics
  mu_quantiles <- x$mu_summary$quantiles
  cat(sprintf("  Mean: %.*f, SD: %.*f, Median: %.*f\n", digits, mu_stats["Mean"], digits, mu_stats["SD"], digits, mu_quantiles["50%"]))
  cat(sprintf("  95%% CrI: [%.*f, %.*f]\n", digits, mu_quantiles["2.5%"], digits, mu_quantiles["97.5%"]))

  cat("\nPosterior Summary for Heterogeneity (tau):\n")
  tau_stats <- x$tau_summary$statistics
  tau_quantiles <- x$tau_summary$quantiles
  cat(sprintf("  Mean: %.*f, SD: %.*f, Median: %.*f\n", digits, tau_stats["Mean"], digits, tau_stats["SD"], digits, tau_quantiles["50%"]))
  cat(sprintf("  95%% CrI: [%.*f, %.*f]\n", digits, tau_quantiles["2.5%"], digits, tau_quantiles["97.5%"]))

  cat("\nBayes Factor Analysis:\n")
  bf_mu_interp <- ifelse(x$bf10_mu > 3, "Moderate evidence FOR an effect", 
                         ifelse(x$bf10_mu < 1/3, "Moderate evidence FOR NO effect", "Anecdotal evidence"))
  cat(sprintf("  BF10 (Effect):   %.2f (%s)\n", x$bf10_mu, bf_mu_interp))
  
  bf_het_interp <- ifelse(x$bf_het > 3, "Moderate evidence FOR heterogeneity", 
                          ifelse(x$bf_het < 1/3, "Moderate evidence FOR NO heterogeneity", "Anecdotal evidence"))
  cat(sprintf("  BF (Heterog.): %.2f (%s)\n", x$bf_het, bf_het_interp))

  invisible(x)
}


