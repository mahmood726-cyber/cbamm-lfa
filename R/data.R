#' BCG Vaccine Meta-Analysis Dataset
#'
#' A classic dataset for meta-analysis containing the results of 13 studies
#' on the effectiveness of the BCG vaccine against tuberculosis.
#'
#' @format A data frame with 13 rows and 7 variables:
#' \describe{
#'   \item{study_id}{Character: Unique study identifier}
#'   \item{yi}{Numeric: Log risk ratio (effect size)}
#'   \item{vi}{Numeric: Variance of the log risk ratio}
#'   \item{year}{Integer: Year of publication (1933-1980)}
#'   \item{latitude}{Numeric: Latitude of the study location (covariate)}
#'   \item{se}{Numeric: Standard error (calculated from vi)}
#'   \item{precision}{Numeric: Precision (1/se)}
#' }
#'
#' @source Colditz et al. (1994), JAMA.
#'
#' @examples
#' data(bcg_data)
#' result <- cbamm_fast(bcg_data)
#' print(result)
"bcg_data"

#' Example Meta-Analysis Dataset
#'
#' A simulated dataset containing effect sizes and study characteristics
#' from 15 hypothetical studies for demonstration purposes.
#'
#' @format A data frame with 15 rows and 11 variables:
#' \describe{
#'   \item{study_id}{Character: Unique study identifier}
#'   \item{yi}{Numeric: Effect size estimate (e.g., log odds ratio)}
#'   \item{vi}{Numeric: Variance of the effect size}
#'   \item{year}{Integer: Year of publication (2010-2024)}
#'   \item{n}{Integer: Total sample size}
#'   \item{age_mean}{Numeric: Mean age of participants}
#'   \item{female_pct}{Numeric: Proportion of female participants}
#'   \item{bmi_mean}{Numeric: Mean BMI of participants}
#'   \item{charlson}{Numeric: Mean Charlson comorbidity index}
#'   \item{se}{Numeric: Standard error (calculated from vi)}
#'   \item{precision}{Numeric: Precision (1/se)}
#' }
#'
#' @source Simulated data for package demonstration
#'
#' @examples
#' data(example_meta)
#' head(example_meta)
#'
#' # Run basic meta-analysis
#' result <- cbamm_fast(example_meta)
#' print(result)
#'
#' # Run cumulative analysis
#' cum_result <- cumulative_meta_analysis(example_meta, order_by = "year")
#' print(cum_result)
"example_meta"
