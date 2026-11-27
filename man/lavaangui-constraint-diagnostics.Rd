\name{lavaangui-constraint-diagnostics}
\alias{lavaangui-constraint-diagnostics}
\title{Explore Measurement Equality Constraints with Score Tests and EPC}
\description{Exploratory diagnostics for constrained continuous CFA models estimated with ordinary ML in two groups.}
\details{
Run Measurement invariance (CFA). In Advanced diagnostics, choose Constraint diagnostics. Select a fitted model with equality constraints and click Compute score tests and EPC. Choose a tested constraint to inspect the two group-specific EPC rows. Download score table (CSV) and Download selected EPC (CSV) are available after computation.

The module calls \code{lavaan::lavTestScore} with a single equality release at a time, \code{univariate = TRUE}, \code{epc = TRUE} and \code{standardized = FALSE}. Each result is conditional on retaining the other equalities. It reports the score chi-square, degrees of freedom, raw p-value, Holm-adjusted p-value and availability status. The Holm family includes all listed constraints, including unavailable tests. EPC is the expected change under a hypothetical release; Expected is the current estimate plus EPC. It is a local approximation, not a new fitted coefficient. No constraint is automatically freed, no fit is changed, and no refit is performed.

Ordinary ML with standard SEs and listwise deletion, two groups, continuous CFA and an admissible fit without captured warnings are required. The extra Browne normal-theory residual test in lavaan 0.7-3 is compatible with the ordinary ML workflow. Robust MLR/WLSMV scores, more than two groups and structural equality diagnostics are not supported here. Releases that would violate the two-common-anchor safeguard are not evaluated. Residual-variance equalities can be diagnosed but cannot be released in the current partial-invariance controls.

Use the results to investigate substantively justified measurement differences, not to search mechanically for a non-significant fit. Refit a proposed partial model explicitly and validate on independent data. Very small printed p-values can round to zero; report them as very small, not exactly zero.
}
\section{Example}{In 01_AFC_continue.lvm run full invariance, then inspect Metric for f1 =~ x3. Release this loading, rerun, then inspect Partial scalar for y3 ~ 1. Release both and inspect Partial strict for y4 ~~ y4. The synthetic dataset was designed to make these differences visible. The exact numeric output depends on the data and fitted model.}
\seealso{\code{\link{lavaangui-multiple-groups}}, \code{\link[lavaan]{lavTestScore}}}
