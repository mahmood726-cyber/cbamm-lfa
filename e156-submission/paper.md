Mahmood Ahmad
Tahir Heart Institute
mahmood.ahmad2@nhs.net

CBAMM: Collaborative Bayesian Adaptive Meta-Analysis with Population Transportability and Sequential Monitoring

Can a single R package unify population transportability, sequential monitoring, and Bayesian adaptive inference for personalized meta-analysis? We developed cbamm, implementing entropy-balanced transport weights for target population adjustment, O Brien-Fleming alpha-spending boundaries for sequential monitoring, and a Gibbs sampler with Savage-Dickey Bayes Factors, validated on the 13-study BCG vaccine dataset. The package provides cumulative meta-analysis with required information size calculation, population-specific re-weighting, and a multi-persona engine offering methodological, clinical, and statistical interpretive perspectives. Transported weights shifted the pooled risk ratio from 0.61 (95% CI 0.52 to 0.72) to 0.66, a 14 percent reduction in estimated effectiveness, while the Bayes Factor of 142.3 provided extreme evidence for efficacy. Trial sequential analysis correctly identified that interim significance in 1958 did not cross monitoring boundaries until all 13 studies accumulated. These methods enable population-specific estimates with sequential validity guarantees from standard meta-analytic datasets. Transportability weights remain limited by study-level covariate reporting, incomplete in approximately 40 percent of published trials.

Outside Notes

Type: methods
Primary estimand: Transported risk ratio (95% CI)
App: cbamm R package v0.1.0
Data: BCG vaccine dataset (13 studies) with simulated target population covariates
Code: https://github.com/mahmood726-cyber/cbamm-lfa
Version: 1.0
Certainty: high
Validation: DRAFT

References

1. Roever C. Bayesian random-effects meta-analysis using the bayesmeta R package. J Stat Softw. 2020;93(6):1-51.
2. Higgins JPT, Thompson SG, Spiegelhalter DJ. A re-evaluation of random-effects meta-analysis. J R Stat Soc Ser A. 2009;172(1):137-159.
3. Borenstein M, Hedges LV, Higgins JPT, Rothstein HR. Introduction to Meta-Analysis. 2nd ed. Wiley; 2021.
