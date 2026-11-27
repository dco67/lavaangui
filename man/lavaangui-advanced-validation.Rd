\name{lavaangui-advanced-validation}
\alias{lavaangui-advanced-validation}
\title{Validation, Supported Scope and Troubleshooting}
\description{Reproducibility and acceptance evidence for the proposed advanced analysis contribution.}
\details{
The corrected candidate was tested on 26 November 2026 under Windows 11 x64, R 4.6.0 and lavaan 0.7-3. All six R acceptance scripts returned exit code 0. This includes native ML/MLR and WLSMV comparisons, continuous partial invariance, ordinal stages, replay, 318 fitted-parameter-to-edge matches, JSON validation, score/EPC, derived effects and actual HTML generation. A non-blocking notice reported that lavaan was built under R 4.6.2. Browser tests with simulated Shiny inputs and contributor interactive trials complement these checks. This is not a completed R CMD check, full end-to-end Shiny matrix or multi-platform certification.

From an extracted source project root (not an installed package directory), after installing its dependencies including optional semTools, run:
\preformatted{Rscript tests/manual/run_advanced_validation.R}
The launcher creates a new advanced-validation-YYYYMMDD-HHMMSS directory with summary.csv, individual logs and session information. Keep these records. Tests use simulated or built-in data; their printed numerical values are not necessarily the same as the teaching CSV. For that CSV, use the installed native reference examples or its exported GUI script.
}
\section{Common problems}{
\describe{
\item{No completed estimate}{Return to Estimates, wait for the fit to finish with the current data, and reopen More Results. Do not use a snapshot from a different dataset.}
\item{Cannot find a grouping variable}{Use a separate column with 2--10 nonblank group values; variables already in the model are not offered. Variables used in the diagram are also omitted from the main editor's available-variable toolbar.}
\item{Confirmation required}{Make selections first, then check the confirmation box again.}
\item{No inferential test}{Read the diagnostic, check data, options, nesting, fit warnings, admissibility and degrees of freedom. Do not bypass scope or compatibility checks.}
\item{Ordinal module unavailable}{Install semTools, restart the app, check ordered declarations and estimator, category counts and simple CFA scope.}
\item{Score diagnostics unavailable}{Only ordinary ML two-group continuous CFA with listwise deletion is supported.}
\item{Saved JSON rejected}{Check original data representation, model and estimation settings, file version/size and group order. Do not manually change fingerprints.}
\item{Cannot see save or script tab}{In the final interface these are nested under Export & restore, and score/effects under Advanced diagnostics. Expand the window if necessary.}
}
}
\seealso{\code{\link{lavaangui-advanced}}, \code{\link{lavaangui-multiple-groups}}, \code{\link{lavaangui-analysis-export}}}
