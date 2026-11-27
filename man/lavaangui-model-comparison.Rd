\name{lavaangui-model-comparison}
\alias{lavaangui-model-comparison}
\title{Compare Nested Models with ML, MLR and WLSMV}
\description{The Model Comparison tab under More Results stores two completed GUI specifications and refits them using identical data and settings.}
\details{
\enumerate{
\item Load and estimate the less restricted model. In Model Comparison, clear any previous pair, then choose Save latest estimate as A.
\item Close the results dialog, constrain or remove the proposed path, or load the more restricted model B. Keep the same data and estimation settings. Estimate, then choose Save latest estimate as B.
\item Inspect saved specifications A and B. Confirm I have checked that B is nested in A and click Compare A and B.
\item Read Fit table, Difference test and diagnostics. Export contains Analysis script and HTML report. The fit table can be downloaded as CSV.
}
The automatic check covers simple restrictions on regressions and off-diagonal covariances; it is not a general proof of nesting. The two models must retain the same observed and latent variables, exogenous-variable role, cases, ordered declarations and effective estimation options. Existing special equality/inequality constraints, changes in measurement specification, fixed values, means, threshold or scale specification are not certified. B must impose independent restrictions with a matching positive change in degrees of freedom. Unsupported comparisons may show separate fit summaries without a formal test; do not treat these as a valid comparison.

ML uses the ordinary lavaan likelihood-ratio test. MLR uses the correction selected by lavaan for its fitted test options. WLSMV requires explicitly ordered endogenous indicators, numeric category codes or ordered factors (2--12 observed categories), listwise deletion, automatic threshold/scale parameters and the same moments and weights. The single-group GUI comparison is delta-parameterized. It calls \code{lavTestLRT(..., method = "satorra.2000", a.method = "delta", scaled.shifted = TRUE, test = "scaled.shifted")}. Do not subtract scaled chi-square statistics. AIC and BIC are not applicable to WLSMV. Continuous ML/MLR comparisons allow supported listwise or ML missing-data settings when both models actually use compatible cases and options. Bootstrap and ordinal exogenous predictors are outside the workflow.

Both fits must converge, pass lavaan's post-check and issue no captured warnings before formal inference is shown. Review model fit and assumptions; failure to reject is not proof of equivalence. A missing test is not a non-significant result.
}
\section{Worked example}{Use the installed synthetic CSV and models 02/03 (ML), 04/05 (MLR), or 06/07 (WLSMV). Model A in 02 has \code{M ~ X + Z; Y ~ M + X}; model B in 03 omits \code{Y ~ X}. In 06/07 the restriction is a residual covariance. Use identical estimation settings within each pair. The expected difference in degrees of freedom is one. See the installed guide and \code{reference-examples.R}.}
\seealso{\code{\link{lavaangui-advanced}}, \code{\link{lavaangui-analysis-export}}, \code{\link[lavaan]{lavTestLRT}}}
