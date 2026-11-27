% Hand-maintained documentation topic; not an R function.
\name{lavaangui-advanced}
\alias{lavaangui-advanced}
\title{Advanced Analysis Workflows in lavaangui}
\description{Guide to the proposed development extension for nested-model comparisons, multiple-group analysis, diagnostics, diagrams and reproducible exports.}
\details{
Start \code{lavaangui()}, load a dataset and a diagram, and click Estimates. Once the estimation has completed, open More Results. The two new modules are separate from the main editor. They use the last completed specification and the current data, refit in lavaan, and do not overwrite the main fit. They introduce no public R functions.

\describe{
\item{\code{\link{lavaangui-model-comparison}}}{Compare simple nested models with ML, MLR or WLSMV.}
\item{\code{\link{lavaangui-multiple-groups}}}{Continuous full/partial CFA invariance, ordinal full CFA invariance and structural equality tests.}
\item{\code{\link{lavaangui-diagrams}}}{Group estimates, synchronized diagrams and descriptive signed differences.}
\item{\code{\link{lavaangui-constraint-diagnostics}}}{Ordinary ML score tests and expected parameter changes.}
\item{\code{\link{lavaangui-group-effects}}}{Direct, indirect and total regression-path effects and between-group contrasts.}
\item{\code{\link{lavaangui-analysis-export}}}{CSV, R scripts, SVG, companion JSON and offline HTML reports.}
\item{\code{\link{lavaangui-advanced-validation}}}{Validation scope, reproduction and troubleshooting.}
}
The optional package semTools (>= 0.5-6) is required only for ordinal multiple-group invariance. Install it separately if needed. The installed user guide is an offline HTML document, not a dynamically built vignette. The examples directory contains a synthetic CSV and eight model files. These examples have no real participant records. This is a contribution for review, not an upstream release. Existing lavaangui functions and file formats are retained.
}
\section{Installed guide and example files}{
After installing the documented package, use:
\preformatted{guide <- system.file("doc", "advanced-analysis.html",
                     package = "lavaangui")
stopifnot(nzchar(guide))
utils::browseURL(guide)
kit <- system.file("advanced-examples", package = "lavaangui")
list.files(kit, recursive = TRUE)}
When working from an extracted source checkout, the corresponding paths are \code{inst/doc/advanced-analysis.html} and \code{inst/advanced-examples/}. Copy the example files to a writable directory before editing them. The standalone native-lavaan reference script can be run via \code{source(file.path(kit, "reference-examples.R"))}; it prints results and skips ordinal invariance if semTools is not installed.
}
\examples{
# Locate documentation without launching an application.
system.file("doc", "advanced-analysis.html", package = "lavaangui")
system.file("advanced-examples", package = "lavaangui")
}
\seealso{\code{\link{lavaangui}}, \code{\link{lavaangui-package}}}
