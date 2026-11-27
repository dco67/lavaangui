#' @keywords internal
#'
#' @description
#' The lavaangui package provides a free, open-source graphical user interface
#' for the \pkg{lavaan} package. Models can be specified by drawing path diagrams
#' and fitted models can be visualized via interactive path diagrams.
#'
#' The package offers two core functions:
#' \describe{
#'   \item{\code{\link{lavaangui}}}{Launches a web application that allows users
#'     to specify models by drawing path diagrams, fit them, and assess model fit.}
#'   \item{\code{\link{plot_lavaan}}}{Creates interactive path diagrams from
#'     fitted \pkg{lavaan} models. Nodes can be repositioned by dragging them
#'     with the mouse.}
#' }
#'
#' The original web application is also available at
#' \url{https://lavaangui.org/}. The advanced workflows described here refer
#' to this local development contribution, not necessarily the hosted version.
#'
#' @details
#' See \code{\link{lavaangui-advanced}} for the advanced analysis workflows,
#' scope, installed guide and examples. No new public R functions are introduced.
#'
#' @references
#' Karch, J. D. (2025). lavaangui: A Web-Based Graphical Interface for
#' Specifying Lavaan Models by Drawing Path Diagrams. \emph{Structural Equation
#' Modeling: A Multidisciplinary Journal}, 1--12.
#' \doi{10.1080/10705511.2024.2420678}
"_PACKAGE"
