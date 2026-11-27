\name{lavaangui-diagrams}
\alias{lavaangui-diagrams}
\title{Group-Specific Estimates and Synchronized Diagrams}
\description{Inspect parameters from converged, admissible multiple-group fits without changing or refitting the original model.}
\details{
In Multiple Groups, Selected estimates lets you choose a fitted model and Unstandardized or Fully standardized estimates. The estimates and matching confidence intervals are produced by lavaan's \code{parameterEstimates} or \code{standardizedSolution} (std.all). Inspect group labels, thresholds (\code{|}), intercepts and means (\code{~1}) in these tables; CSV exports contain the selected full table including unrounded values.

In Path diagram, choose Fitted model, then Display: One group, Compare two groups, or Two groups + difference (second minus first). Select Group and, when relevant, Second group. The difference is computed on the selected coefficient scale before rounding. Use Coefficients, Layout (Compact CFA when applicable, Left to right or Top to bottom), Zoom, Decimals, Covariances, Variances and Reset layout. Expand viewer widens the area in the Shiny results window. Drag nodes to rearrange them; the same positions are used in each panel. Download SVG on each panel saves that vector diagram.

Rectangles denote observed variables, ellipses latent variables, single-headed arrows loadings or regressions and double-headed arrows covariances. Variance loops are optional. Thresholds, means, intercepts and defined effects are not drawn. NA means an estimate is unavailable. Differences are descriptive, not p-values or equality tests. Equal unstandardized parameters can have different standardized values. Compare raw coefficients only when scales are commensurate, especially with latent and ordinal variables. In ordinal CFA the response scale may change across stages.

To save the last view, first open and adjust Path diagram, then go to Export & restore, Save / restore. Download analysis (.json) stores the view if the status indicates it is ready. The companion JSON stores only the last view, not separate layouts for every fitted stage. The original plot_lavaan layout mechanism and native .lvm format are unchanged.}
\seealso{\code{\link{lavaangui-multiple-groups}}, \code{\link{lavaangui-analysis-export}}, \code{\link{plot_lavaan}}}
