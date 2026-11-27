# Read-only, group-specific diagrams for the advanced results module.
# No estimation and no modification of the main editor or the fitted model.
advancedDiagramRows <- function(p) {
  required <- c("lhs", "op", "rhs", "group")
  if (!all(required %in% names(p))) stop("Cannot identify the group-specific parameter rows.", call. = FALSE)
  p <- p[!is.na(p$group) & p$group > 0L & p$op %in% c("=~", "~", "~~"), , drop = FALSE]
  # Covariance keys must be independent of lhs/rhs order.
  flip <- p$op == "~~" & p$lhs > p$rhs
  lhs <- p$lhs; rhs <- p$rhs
  p$lhs[flip] <- rhs[flip]; p$rhs[flip] <- lhs[flip]
  p$key <- paste(p$group, p$lhs, p$op, p$rhs, sep = "\r")
  if (anyDuplicated(p$key)) stop("Repeated parameter rows prevent an unambiguous diagram.", call. = FALSE)
  p
}

advancedGroupDiagramData <- function(out, model, grouping) {
  if (!advancedUsable(out)) stop("Select a converged, admissible model.", call. = FALSE)
  f <- out$value
  groups <- as.character(lavaan::lavInspect(f, "group.label"))
  counts <- as.numeric(unlist(lavaan::lavInspect(f, "nobs"), use.names = FALSE))
  if (length(groups) < 2L || length(groups) != length(counts)) stop("Cannot identify the fitted groups.", call. = FALSE)
  lv <- lavaan::lavNames(f, "lv")
  ov <- lavaan::lavNames(f, "ov")
  vars <- unique(c(lv, ov))
  nodes <- data.frame(id = seq_along(vars), label = vars, latent = vars %in% lv, stringsAsFactors = FALSE)
  raw <- advancedDiagramRows(advancedParameters(out, FALSE))
  std <- advancedDiagramRows(advancedParameters(out, TRUE))
  pt <- advancedDiagramRows(lavaan::parTable(f))
  if (!all(raw$group %in% seq_along(groups)) || !all(std$group %in% seq_along(groups)))
    stop("Parameter group numbers do not match the fitted groups.", call. = FALSE)
  # Do not turn implicit zero paths/covariances into visible arrows. Explicit
  # zero restrictions, free estimates of zero, marker loadings and variances remain.
  ix <- match(raw$key, pt$key)
  implicit_zero <- !is.na(ix) & !is.na(pt$user[ix]) & pt$user[ix] == 0L &
    !is.na(pt$free[ix]) & pt$free[ix] == 0L & !is.na(raw$est) & raw$est == 0 & raw$lhs != raw$rhs
  raw <- raw[!implicit_zero, , drop = FALSE]
  from <- match(ifelse(raw$op == "~", raw$rhs, raw$lhs), vars)
  to <- match(ifelse(raw$op == "~", raw$lhs, raw$rhs), vars)
  if (anyNA(from) || anyNA(to)) stop("A diagram parameter refers to an unknown variable.", call. = FALSE)
  raw_est <- as.numeric(raw$est)
  std_est <- as.numeric(std$est.std[match(raw$key, std$key)])
  raw_est[!is.finite(raw_est)] <- NA_real_; std_est[!is.finite(std_est)] <- NA_real_
  rows <- data.frame(from = from, to = to, op = raw$op, group = as.integer(raw$group),
                     raw = raw_est, std = std_est, stringsAsFactors = FALSE)
  list(model = as.character(model), grouping = as.character(grouping), ordinal = length(lavaan::lavInspect(f, "ordered")) > 0L,
       warnings = length(out$warnings), nodes = nodes,
       groups = data.frame(id = seq_along(groups), label = groups, n = counts, stringsAsFactors = FALSE),
       rows = rows)
}

advancedDiagramScript <- function() {
  # Works with pkgload, installed packages and the standalone demonstration.
  path <- system.file("www", "advanced-group-diagram.js", package = "lavaangui")
  if (!nzchar(path)) path <- file.path("inst", "www", "advanced-group-diagram.js")
  if (!file.exists(path)) return(shiny::helpText("Diagram viewer script not found. Install inst/www/advanced-group-diagram.js."))
  shiny::singleton(shiny::includeScript(path))
}

advancedDiagramTab <- function(ns) {
  shiny::tabPanel("Path diagram", value = "diagram",
    shiny::div(class = "lvg-advanced-tab",
      advancedDiagramScript(),
      shiny::h4("Group-specific path diagrams"),
      shiny::selectInput(ns("diagramStage"), "Fitted model", choices = character()),
      shiny::helpText("Choose a fitted model, then view one group, compare two groups, or show the descriptive difference (second minus first). Coefficients are extracted from the existing fit, not re-estimated. Layout changes are local to this viewer. The companion analysis JSON can save the last viewed diagram layout and display preferences."),
      shiny::uiOutput(ns("groupDiagram"))
    )
  )
}

advancedDiagramUI <- function(payload, state_input = NULL, token = NULL, restored_view = NULL) {
  payload$stateInput <- state_input
  payload$viewToken <- token
  payload$restoredView <- restored_view
  shiny::tags$div(class = "lvg-group-diagram", role = "region",
    `aria-label` = "Group-specific path diagrams",
    `data-payload` = as.character(jsonlite::toJSON(payload, auto_unbox = TRUE, dataframe = "rows", na = "null", digits = NA)),
    shiny::tags$p("Loading diagram viewer..."))
}
