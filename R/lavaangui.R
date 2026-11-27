#' Start lavaangui Shiny Application
#'
#' The `lavaangui` function launches the lavaangui Shiny application.
#'
#' @param fit A single-group lavaan model, as returned by the `lavaan`, `sem`, or `cfa` functions from the `lavaan` package.
#' If provided, lavaangui imports the model and data. If left empty, lavaangui starts without importing.
#'
#' @return nothing
#'
#' @examplesIf interactive()
#' # Without importing lavaan model
#' lavaangui()
#'
#' # Importing a lavaan model
#' library(lavaan)
#' model <- "
#'   visual  =~ x1 + loadingx2*x2 + x3
#'   textual =~ x4 + x5 + x6
#'   speed   =~ x7 + x8 + x9
#' "
#' fit <- cfa(model, data = HolzingerSwineford1939)
#' lavaangui(fit)
#'
#' @details
#' This development contribution adds separate Model Comparison and Multiple Groups
#' modules under More Results after a completed diagram estimate. They refit
#' supported models using the loaded data; they do not replace the main diagram
#' or turn it into a multiple-group editor. Importing an already fitted
#' multiple-group lavaan object with \code{lavaangui(fit)} remains unsupported.
#' Such objects can still be visualized with \code{\link{plot_lavaan}}.
#' See \code{\link{lavaangui-advanced}} for supported workflows and limits.
#'
#' @seealso \code{\link{lavaangui-advanced}}, \code{\link{plot_lavaan}}
#' @export
lavaangui <- function(fit = NULL) {
  start_app(fit = fit, full = TRUE, where = "browser", layout = NULL, export_filepath = NULL, scale = NULL)
}
