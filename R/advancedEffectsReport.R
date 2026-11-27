# Derived effects from a fitted, recursive continuous multiple-group SEM.
# No refit and no modification of the source model.
advancedEffectGraph <- function(out) {
  if (!advancedUsable(out) || length(out$warnings))
    stop("Use a converged, admissible Free regressions model without captured warnings.", call. = FALSE)
  f <- out$value
  opt <- lavaan::lavInspect(f, "options")
  if (length(lavaan::lavInspect(f, "ordered")) || !identical(opt$estimator, "ML") ||
      !opt$se %in% c("standard", "robust.huber.white", "robust.sem", "robust"))
    stop("Effects require continuous ML/MLR with model-based or robust standard errors.", call. = FALSE)
  if ("regressions" %in% opt$group.equal) stop("Use Free regressions, not an equality-constrained structural fit.", call. = FALSE)
  labs <- as.character(lavaan::lavInspect(f, "group.label"))
  if (length(labs) < 2L || anyDuplicated(labs)) stop("Cannot identify distinct groups.", call. = FALSE)
  pt <- lavaan::parTable(f)
  reg <- pt[pt$op == "~" & pt$group %in% seq_along(labs), , drop = FALSE]
  if (!nrow(reg) || anyNA(reg$free) || any(!is.finite(reg$est)) || any(reg$free == 0L & reg$est != 0))
    stop("Effects require free regressions or explicitly absent (zero) paths.", call. = FALSE)
  reg <- reg[reg$free > 0L, , drop = FALSE]
  if (!nrow(reg)) stop("No free regression paths.", call. = FALSE)
  if (anyDuplicated(reg$free)) stop("Regression coefficients must have distinct free parameter indices.", call. = FALSE)
  # Use the actual free-parameter numbering and verify the corresponding SEs.
  V <- as.matrix(lavaan::lavInspect(f, "vcov"))
  if (!nrow(V) || nrow(V) != ncol(V) || any(!is.finite(V)) || any(reg$free > nrow(V)) ||
      any(!is.finite(reg$se)) || any(reg$se <= 0) ||
      max(abs(diag(V)[reg$free] - reg$se^2) / pmax(1e-12, reg$se^2)) > 1e-5 ||
      max(abs(V - t(V))) > 1e-8 * max(1, max(abs(V))))
    stop("The free-parameter covariance matrix cannot be aligned with the regression estimates.", call. = FALSE)
  reg$key <- paste(reg$rhs, reg$lhs, sep = "\r")
  by_group <- lapply(seq_along(labs), function(g) reg[reg$group == g, , drop = FALSE])
  ref <- by_group[[1L]]
  if (!nrow(ref) || !all(vapply(by_group, function(p) !anyDuplicated(p$key) && setequal(ref$key, p$key), logical(1))))
    stop("The groups do not have the same free regression graph.", call. = FALSE)
  nodes <- unique(c(ref$rhs, ref$lhs))
  if (length(nodes) > 30L || anyDuplicated(ref$key) || any(ref$rhs == ref$lhs))
    stop("Use an acyclic structural graph of at most 30 variables.", call. = FALSE)
  # Topological check, including disconnected components. Never enumerate a cycle.
  remaining <- nodes
  while (length(remaining)) {
    roots <- setdiff(remaining, ref$lhs[ref$rhs %in% remaining & ref$lhs %in% remaining])
    if (!length(roots)) stop("Feedback/cyclic structural models are outside this workflow.", call. = FALSE)
    remaining <- setdiff(remaining, roots)
  }
  list(groups = labs, nodes = nodes, ref = ref, by_group = by_group, V = V,
       se = opt$se, latent = length(lavaan::lavNames(f, "lv")) > 0L)
}

advancedEffectPaths <- function(graph, exposure, outcome) {
  if (length(exposure) != 1L || length(outcome) != 1L || !all(c(exposure, outcome) %in% graph$nodes) || exposure == outcome)
    stop("Select two distinct structural variables.", call. = FALSE)
  ref <- graph$ref
  # Prune nodes that cannot reach the target, then enumerate directed paths.
  ancestors <- outcome
  repeat {
    next_nodes <- union(ancestors, ref$rhs[ref$lhs %in% ancestors])
    if (length(next_nodes) == length(ancestors)) break
    ancestors <- next_nodes
  }
  paths <- list()
  visit <- function(at, path) {
    if (at == outcome) {
      if (length(paths) >= 100L) stop("More than 100 directed paths; simplify the model.", call. = FALSE)
      paths[[length(paths) + 1L]] <<- path
      return(invisible(NULL))
    }
    for (j in which(ref$rhs == at & ref$lhs %in% ancestors)) visit(ref$lhs[j], c(path, j))
    invisible(NULL)
  }
  if (exposure %in% ancestors) visit(exposure, integer())
  if (!length(paths)) stop("No directed regression path connects these variables.", call. = FALSE)
  paths
}

advancedEffects <- function(out, exposure, outcome, first, second, level = .95) {
  graph <- advancedEffectGraph(out)
  if (length(first) != 1L || length(second) != 1L || !all(c(first, second) %in% graph$groups) || first == second)
    stop("Choose two different groups.", call. = FALSE)
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1)
    stop("Invalid confidence level.", call. = FALSE)
  paths <- advancedEffectPaths(graph, exposure, outcome)
  direct <- which(lengths(paths) == 1L)
  indirect <- which(lengths(paths) > 1L)
  sets <- c(list(direct), lapply(indirect, function(i) i), list(indirect, seq_along(paths)))
  path_name <- function(i) paste(c(exposure, graph$ref$lhs[paths[[i]]]), collapse = " -> ")
  names(sets) <- c("Direct", vapply(indirect, path_name, character(1)), "Total indirect", "Total")
  V <- graph$V
  calculate <- function(group, selected) {
    p <- graph$by_group[[match(group, graph$groups)]]
    grad <- numeric(nrow(V)); est <- 0
    for (i in selected) {
      q <- p[match(graph$ref$key[paths[[i]]], p$key), , drop = FALSE]
      b <- q$est; est <- est + prod(b)
      # Product of all OTHER factors: remains valid when an estimate is zero.
      for (j in seq_along(b)) grad[q$free[j]] <- grad[q$free[j]] + prod(b[-j])
    }
    list(est = est, grad = grad)
  }
  infer <- function(est, grad) {
    v <- as.numeric(crossprod(grad, V %*% grad))
    if (!is.finite(v) || v < -1e-10) stop("Invalid delta-method variance.", call. = FALSE)
    se <- sqrt(max(0, v)); z <- stats::qnorm((1 + level)/2)
    if (se <= 1e-12) return(c(Estimate = est, SE = NA_real_, CI.lower = NA_real_, CI.upper = NA_real_, p = NA_real_))
    c(Estimate = est, SE = se, CI.lower = est-z*se, CI.upper = est+z*se, p = 2*stats::pnorm(-abs(est/se)))
  }
  tab <- do.call(rbind, lapply(seq_along(sets), function(i) {
    a <- calculate(first, sets[[i]]); b <- calculate(second, sets[[i]])
    values <- rbind(infer(a$est, a$grad), infer(b$est, b$grad), infer(b$est-a$est, b$grad-a$grad))
    data.frame(Effect = names(sets)[i], Contrast = c("First group", "Second group", "Second - first"),
      Group = c(first, second, paste(second, "-", first)), values,
      Status = if (!length(sets[[i]])) "Structural zero (no path)" else ifelse(is.na(values[, "SE"]), "No estimable SE", "OK"),
      check.names = FALSE, stringsAsFactors = FALSE)
  }))
  rownames(tab) <- NULL
  list(table = tab, exposure = exposure, outcome = outcome, first = first, second = second,
       level = level, se = graph$se, latent = graph$latent,
       note = paste("Unstandardized regression-path effects in Free regressions; total indirect sums all directed paths of length >= 2; total adds the direct path.",
         "Delta-method normal intervals and two-sided Wald p-values use the full fitted parameter covariance, including any cross-group covariance.",
         "P-values are unadjusted; a missing SE/p-value is not evidence of equality. Indirect effects can have non-normal sampling distributions.",
         "Associational model-based effects, not proof of causal mediation; justify temporal ordering, confounding assumptions and common measurement scales."))
}

# Offline HTML report. Only trusted package JS is executable. All user/model
# strings, even in data attributes, are escaped by Shiny tags. No raw cases.
advancedReportTable <- function(d) {
  if (is.null(d) || !nrow(d)) return(shiny::tags$p("Not available."))
  fmt <- function(x) if (length(x) != 1L || is.na(x)) "NA" else if (is.numeric(x)) format(x, digits = 7, trim = TRUE) else as.character(x)
  shiny::tags$div(class = "table-scroll", shiny::tags$table(
    shiny::tags$thead(do.call(shiny::tags$tr, lapply(names(d), shiny::tags$th))),
    shiny::tags$tbody(lapply(seq_len(nrow(d)), function(i) do.call(shiny::tags$tr,
      lapply(d, function(col) shiny::tags$td(fmt(col[i]))))))))
}

advancedWriteReport <- function(result, file, diagram_view = NULL, score = NULL, effects = NULL) {
  tags <- shiny::tags
  group <- !is.null(result$group)
  script <- advancedScript(result)
  # The optional diagnostic recipes deliberately require the same extension.
  # Refit with the helper to capture convergence and warnings in that replay.
  literal <- function(x) paste(utils::capture.output(dput(x)), collapse = " ")
  if (!is.null(score)) script <- c(script, "", "# Optional constraint diagnostics (requires the same lavaangui extension loaded).",
    sprintf("score_fit <- lavaangui:::advancedFit(c(configs[[%s]], list(data = as.data.frame(data))))", literal(score$stage)),
    "score_result <- lavaangui:::advancedScoreDiagnostics(score_fit)", "print(score_result$table)", "print(score_result$epcs)")
  if (!is.null(effects)) script <- c(script, "", "# Optional effect comparison (requires the same lavaangui extension loaded).",
    "effect_fit <- lavaangui:::advancedFit(c(configs[['Free regressions']], list(data = as.data.frame(data))))",
    sprintf("effect_result <- lavaangui:::advancedEffects(effect_fit, %s, %s, %s, %s, level = %s)",
      literal(effects$exposure), literal(effects$outcome), literal(effects$first), literal(effects$second), literal(effects$level)),
    "print(effect_result$table)")
  fit_sections <- lapply(names(result$fits), function(nm) {
    fit <- result$fits[[nm]]
    if (!advancedUsable(fit)) return(tags$section(tags$h3(nm), tags$p("No usable estimates. See diagnostics.")))
    p <- advancedCapture(advancedParameters(fit, FALSE))
    s <- advancedCapture(advancedParameters(fit, TRUE))
    tags$section(tags$h3(nm), tags$details(tags$summary("Unstandardized estimates"), advancedReportTable(p$value), tags$pre(paste(c(p$error, p$warnings), collapse = "\n"))),
      tags$details(tags$summary("Fully standardized estimates"), advancedReportTable(s$value), tags$pre(paste(c(s$error, s$warnings), collapse = "\n"))))
  })
  diagram <- NULL
  if (group) {
    usable <- names(result$fits)[vapply(result$fits, advancedUsable, logical(1))]
    if (length(usable)) {
      stage <- if (!is.null(diagram_view) && diagram_view$stage %in% usable) diagram_view$stage else usable[1L]
      diagram <- tryCatch({
        p <- advancedGroupDiagramData(result$fits[[stage]], stage, result$group)
        # Reuse the offline renderer; never load user-supplied HTML or JS.
        path <- system.file("www", "advanced-group-diagram.js", package = "lavaangui")
        if (!nzchar(path)) path <- file.path("inst", "www", "advanced-group-diagram.js")
        if (!file.exists(path)) stop("Diagram renderer not found.")
        code <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
        if (grepl("</script", tolower(code), fixed = TRUE)) stop("Unexpected script terminator.")
        tags$section(tags$h2("Path diagram"), tags$p(if (is.null(diagram_view)) "Default view of the first usable model." else "Last recorded view at export. Display is interactive; changes are local to this HTML file."),
          advancedDiagramUI(p, restored_view = diagram_view), tags$script(shiny::HTML(code)))
      }, error = function(e) tags$section(tags$h2("Path diagram"), tags$p(conditionMessage(e))))
    }
  }
  tests <- lapply(names(result$tests), function(nm) {
    t <- result$tests[[nm]]
    tab <- if (is.null(t$value)) NULL else data.frame(Model = rownames(t$value), as.data.frame(t$value), check.names = FALSE)
    tags$section(tags$h3(nm), if (is.null(tab)) tags$p(paste("No formal test:", t$error)) else advancedReportTable(tab), tags$pre(paste(t$warnings, collapse = "\n")))
  })
  page <- tags$html(lang = "en", tags$head(tags$meta(charset = "UTF-8"), tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
    tags$title("lavaangui | Analysis report"), tags$style(shiny::HTML("body{font-family:Arial,sans-serif;color:#20364b;background:#fff;max-width:1280px;margin:24px auto;padding:0 24px;line-height:1.5}h1,h2{color:#205c8b}h2{border-top:1px solid #cedae4;padding-top:18px;margin-top:28px}table{border-collapse:collapse;font-size:14px;width:100%}td,th{padding:7px 9px;border-bottom:1px solid #dce4eb;text-align:left;white-space:nowrap}th{background:#eef4f8}tr:nth-child(even){background:#f7fafc}.table-scroll{overflow-x:auto}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f4f7fa;padding:12px}details{margin:12px 0}summary{cursor:pointer;font-weight:bold}button,select{font:inherit;padding:6px}nav a{display:inline-block;margin-right:12px} @media print{body{max-width:none;margin:0;padding:0}nav,button{display:none}h2,h3{break-after:avoid}.table-scroll{overflow:visible}table{font-size:9px}td,th{white-space:normal;padding:3px}}"))),
    tags$body(tags$h1("lavaangui | Analysis report"), tags$p("Experimental advanced extension. Snapshot of completed analysis, not a new fit."),
      tags$p(paste("Exported (UTC):", format(Sys.time(), tz = "UTC", usetz = TRUE), "| lavaan:", as.character(utils::packageVersion("lavaan")), "| R:", getRversion())),
      tags$nav(lapply(c("Specification", "Fit", "Tests", "Parameters", "Additional diagnostics", "R script"), function(x) tags$a(href = paste0("#", gsub(" ", "-", x)), x))),
      tags$h2(id = "Specification", "Specification and assumptions"), tags$p(result$note),
      tags$p(paste("Data fingerprint:", result$hash)),
      if (group) tags$div(tags$p(paste("Grouping column:", result$group, "| reference:", result$labels[1L], "| rows omitted for missing group:", result$dropped)),
        tags$pre(paste(utils::capture.output(dput(result$request)), collapse = "\n")),
        tags$h3("Group counts before model-specific missing-data handling"), advancedReportTable(data.frame(Group = names(result$counts), N = as.integer(result$counts)))),
      if (length(result$restrictions)) tags$pre(paste(result$restrictions, collapse = "\n")),
      lapply(names(result$args), function(nm) { a <- result$args[[nm]]; a$data <- NULL; tags$details(tags$summary(paste("Specification:", nm)), tags$pre(paste(utils::capture.output(dput(a)), collapse = "\n"))) }),
      tags$h2(id = "Fit", "Fit indices"), advancedReportTable(result$summary),
      if (group) tags$div(tags$h3("Observations used"), advancedReportTable(result$used)),
      tags$h2(id = "Tests", "Comparisons and warnings"), tests,
      tags$pre(paste(c("Estimation / post-check messages:", advancedFitMessages(result$fits)), collapse = "\n")),
      tags$h2(id = "Parameters", "Parameter estimates"), fit_sections, diagram,
      tags$h2(id = "Additional-diagnostics", "Additional diagnostics"),
      if (is.null(score)) tags$p("Constraint diagnostics not computed or not applicable.") else tags$div(tags$h3(paste("Score tests and EPC:", score$stage)), advancedReportTable(score$value$table),
        lapply(names(score$value$epcs), function(nm) tags$details(tags$summary(paste("Constraint", nm)), advancedReportTable(score$value$epcs[[nm]]))),
        tags$p("Exploratory ordinary ML tests. No constraints automatically released.")),
      if (is.null(effects)) tags$p("Indirect/total effects not computed or not applicable.") else tags$div(tags$h3(paste("Effects:", effects$exposure, "to", effects$outcome)), tags$p(effects$note), advancedReportTable(effects$table)),
      tags$h2(id = "R-script", "Reproducible estimation script"), tags$p("Load the identical original data separately. The script reproduces the fitted models and formal comparisons; when included, additional score/effect recipes require the same extension loaded."), tags$pre(paste(script, collapse = "\n")),
      tags$p("No individual data rows or fitted R objects are embedded. Aggregated estimates and labels may nevertheless be confidential.")))
  writeLines(enc2utf8(c("<!DOCTYPE html>", as.character(page))), file, useBytes = TRUE)
  invisible(file)
}
