# Experimental comparison tools, 2026-11-26.
# All model fitting remains in lavaan; no evaluation of an uploaded R script.
# See DEVELOPMENT-ADVANCED.md for scope and validation instructions.

advancedDataHash <- function(data) {
  if (is.null(data)) return(NULL)
  digest::digest(as.data.frame(data))
}

advancedSnapshot <- function(model, data) {
  if (is.null(data) || !is.character(model$syntax) ||
      length(model$syntax) != 1L || !is.list(model$optionsList)) return(NULL)
  list(syntax = model$syntax, options = model$optionsList,
       hash = advancedDataHash(data))
}

advancedCheckSnapshot <- function(spec, data) {
  if (is.null(spec)) stop("Estimate a diagram with the current data first.", call. = FALSE)
  if (is.null(data) || !identical(spec$hash, advancedDataHash(data))) {
    stop("The data have changed. Re-estimate and save the model again.", call. = FALSE)
  }
  opts <- spec$options
  allowed <- c("meanstructure", "int.ov.free", "int.lv.free", "estimator",
               "se", "missing", "auto.fix.first", "auto.fix.single", "auto.var",
               "auto.cov.lv.x", "auto.cov.y", "fixed.x", "auto.th", "auto.delta",
               "bootstrap", "ordered", "optim.gradient")
  if (length(setdiff(names(opts), allowed))) {
    stop("Unsupported estimation options in this experimental module.", call. = FALSE)
  }
  est <- toupper(if (is.null(opts$estimator)) "DEFAULT" else opts$estimator)
  ordinal <- length(opts$ordered) > 0L
  if (ordinal) {
    if (!is.character(opts$ordered) || anyNA(opts$ordered) || anyDuplicated(opts$ordered) ||
        !all(nzchar(opts$ordered)) || !est %in% c("DEFAULT", "WLSMV"))
      stop("Declare ordered variables and use WLSMV (or its automatic default).", call. = FALSE)
    if (!is.null(opts$missing) && !opts$missing %in% c("default", "listwise"))
      stop("Ordinal comparisons currently require listwise deletion, not FIML or pairwise deletion.", call. = FALSE)
    if (!isTRUE(opts$auto.th) || !isTRUE(opts$auto.delta))
      stop("Keep automatic thresholds and scale parameters enabled for ordinal comparisons.", call. = FALSE)
  } else if (!est %in% c("DEFAULT", "ML", "MLR")) {
    stop("Use ML/MLR for continuous models, or WLSMV with explicitly ordered variables.", call. = FALSE)
  }
  if (!is.null(opts$se) && tolower(opts$se) %in% c("boot", "bootstrap")) {
    stop("Bootstrap is not supported in these comparison modules. Use default or robust standard errors.", call. = FALSE)
  }
  if (!is.null(opts$missing) && !opts$missing %in% c("listwise", "ml", "fiml", "default")) {
    stop("Unsupported missing-data option in this version.", call. = FALSE)
  }
  pt <- lavaan::lavaanify(spec$syntax, auto = FALSE)
  if (any(pt$op %in% c("<~", "|", "~*~"))) {
    stop("Composites and explicit threshold/scale syntax are outside this comparison workflow; declare ordinal nodes with the GUI instead.", call. = FALSE)
  }
  ov <- lavaan::lavNames(pt, type = "ov")
  if (!length(ov) || !all(ov %in% names(data))) {
    stop("Some variables in the diagram are missing from the data.", call. = FALSE)
  }
  if (anyDuplicated(names(data))) stop("Duplicate column names are not supported.", call. = FALSE)
  if (ordinal && !all(opts$ordered %in% ov))
    stop("Some declared ordered variables are absent from the model.", call. = FALSE)
  # Ordered endogenous variables may have numeric category codes or ordered
  # factor levels. An unordered factor or ordinal exogenous predictor is not
  # silently converted. The GUI supplies ordered names explicitly.
  if (ordinal && length(intersect(opts$ordered, lavaan::lavNames(pt, "ov.x"))))
    stop("Ordered exogenous predictors are outside this ordinal comparison workflow.", call. = FALSE)
  valid <- vapply(ov, function(nm) {
    x <- data[[nm]]
    if (ordinal && nm %in% opts$ordered) {
      return((is.ordered(x) || (is.numeric(x) && all(is.finite(x) | is.na(x)))) &&
        length(unique(x[!is.na(x)])) >= 2L && length(unique(x[!is.na(x)])) <= 12L)
    }
    is.numeric(x) && !is.factor(x) && all(is.finite(x) | is.na(x))
  }, logical(1))
  if (!all(valid)) stop("Continuous model variables must be finite numeric values; ordered variables need 2 to 12 observed categories (numeric codes or ordered factors).", call. = FALSE)
  invisible(pt)
}

advancedArgs <- function(spec, data, extra = list()) {
  opts <- utils::modifyList(spec$options, extra, keep.null = TRUE)
  c(list(model = spec$syntax, data = as.data.frame(data)), opts)
}

advancedCapture <- function(expr) {
  warnings <- character()
  error <- NULL
  value <- tryCatch(withCallingHandlers(force(expr), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  }), error = function(e) {
    error <<- conditionMessage(e)
    NULL
  })
  list(value = value, warnings = unique(warnings), error = error)
}

advancedFit <- function(args, fit_fun = lavaan::lavaan) {
  out <- advancedCapture(do.call(fit_fun, args))
  f <- out$value
  out$converged <- FALSE
  out$admissible <- FALSE
  if (!is.null(f)) {
    chk <- advancedCapture(c(converged = isTRUE(lavaan::lavInspect(f, "converged")),
                             admissible = isTRUE(lavaan::lavInspect(f, "post.check"))))
    out$warnings <- unique(c(out$warnings, chk$warnings))
    if (!is.null(chk$error)) out$error <- chk$error
    if (!is.null(chk$value)) {
      out$converged <- isTRUE(chk$value[["converged"]])
      out$admissible <- isTRUE(chk$value[["admissible"]])
    }
  }
  out
}

advancedUsable <- function(out) {
  is.null(out$error) && !is.null(out$value) && out$converged && out$admissible
}

advancedMeasures <- function(f) {
  keys <- c("npar", "chisq", "df", "pvalue", "cfi", "tli", "rmsea", "srmr", "aic", "bic",
            "chisq.scaled", "pvalue.scaled", "cfi.robust", "tli.robust", "rmsea.robust")
  ans <- stats::setNames(rep(NA_real_, length(keys)), keys)
  # Not all estimators return all measures. Keep unavailable measures as NA.
  m <- lavaan::fitMeasures(f, fit.measures = keys)
  ans[intersect(names(m), keys)] <- m[intersect(names(m), keys)]
  ans
}

advancedSummary <- function(fits) {
  do.call(rbind, lapply(names(fits), function(nm) {
    x <- fits[[nm]]
    m <- stats::setNames(rep(NA_real_, 15L), c("npar", "chisq", "df", "pvalue", "cfi", "tli", "rmsea", "srmr", "aic", "bic",
                                          "chisq.scaled", "pvalue.scaled", "cfi.robust", "tli.robust", "rmsea.robust"))
    N <- NA_real_
    if (advancedUsable(x)) {
      z <- advancedCapture(advancedMeasures(x$value))
      if (!is.null(z$value)) m <- z$value
      N <- sum(unlist(lavaan::lavInspect(x$value, "nobs")))
    }
    data.frame(Model = nm, N = N, Converged = x$converged,
               Admissible = x$admissible, Warnings = length(x$warnings),
               as.list(m), check.names = FALSE, stringsAsFactors = FALSE)
  }))
}

advancedFitMessages <- function(fits) {
  unlist(lapply(names(fits), function(nm) {
    x <- fits[[nm]]
    c(if (!is.null(x$error)) paste(nm, "ERROR:", x$error),
      if (!is.null(x$value) && !advancedUsable(x)) paste(nm, "not converged or not admissible"),
      if (length(x$warnings)) paste(nm, "WARNING:", x$warnings))
  }), use.names = FALSE)
}

advancedCompatibility <- function(a, b) {
  # Both objects must represent the same observed moments on the same cases.
  if (!setequal(lavaan::lavNames(a, "ov"), lavaan::lavNames(b, "ov")))
    return("Different observed variables.")
  if (!setequal(lavaan::lavNames(a, "ov.x"), lavaan::lavNames(b, "ov.x")))
    return("Different observed exogenous variables (check fixed.x and model syntax).")
  if (!identical(lavaan::lavInspect(a, "case.idx"), lavaan::lavInspect(b, "case.idx")))
    return("Different cases used for estimation.")
  if (!identical(lavaan::lavInspect(a, "group.label"), lavaan::lavInspect(b, "group.label")))
    return("Different groups or group order.")
  ordered_a <- sort(as.character(lavaan::lavInspect(a, "ordered")))
  ordered_b <- sort(as.character(lavaan::lavInspect(b, "ordered")))
  if (!identical(ordered_a, ordered_b)) return("Different ordered variables.")
  fields <- c("estimator", "likelihood", "test", "se", "missing", "fixed.x",
              "conditional.x", "meanstructure", "parameterization")
  oa <- lavaan::lavInspect(a, "options")
  ob <- lavaan::lavInspect(b, "options")
  for (field in fields) {
    if (!identical(oa[[field]], ob[[field]])) return(paste("Different effective option:", field))
  }
  if (length(ordered_a)) {
    if (!identical(toupper(oa$estimator), "DWLS") || !"scaled.shifted" %in% oa$test ||
        !oa$parameterization %in% c("delta", "theta") || !identical(oa$missing, "listwise"))
      return("Ordinal comparisons require effective WLSMV (DWLS with scaled-shifted test), a common delta/theta parameterization and listwise deletion.")
    # A conservative check of the observed threshold/correlation vectors and
    # diagonal weight matrices. If lavaan orders the moments differently, do
    # not attempt a comparison in this version.
    for (what in c("wls.obs", "wls.v")) {
      if (!isTRUE(all.equal(lavaan::lavInspect(a, what), lavaan::lavInspect(b, what), tolerance = 1e-8)))
        return(paste("Different ordered-model sample statistics or weights:", what))
    }
  }
  NULL
}

# fitMeasures() returns a named lavaan.vector, even for one measure.
# Strip presentation classes before comparing numerical degrees of freedom.
advancedRestrictionDfMatches <- function(da, db, n) {
  scalar_number <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  if (!all(vapply(list(da, db, n), scalar_number, logical(1)))) return(FALSE)
  da <- as.numeric(da); db <- as.numeric(db); n <- as.numeric(n)
  n > 0 && n == floor(n) && da >= 0 && db >= 0 &&
    da == floor(da) && db == floor(db) && db - da == n
}

advancedRestriction <- function(a, b) {
  # Conservative parameter-space check for ordinary path/covariance restrictions.
  # This is not a general algorithm for testing covariance-model nesting.
  if (!setequal(lavaan::lavNames(a, "lv"), lavaan::lavNames(b, "lv")))
    return("Different latent variables; nesting cannot be verified here.")
  ord <- as.character(lavaan::lavInspect(a, "ordered"))
  get_table <- function(f) {
    p <- lavaan::parTable(f)
    labels <- p$label[p$free > 0L & !is.na(p$label) & nzchar(p$label)]
    special <- c("==", "<", ">", "<~", if (!length(ord)) c("|", "~*~"))
    if (any(p$op %in% special) || anyDuplicated(labels) || anyDuplicated(p$free[p$free > 0L]))
      stop("Existing equality/inequality or special constraints require a more general nesting check.", call. = FALSE)
    # In ordinal models retain thresholds and scaling rows in the comparison.
    # They must have identical free/fixed status in both models.
    p <- p[p$op %in% c("~", "=~", "~~", "~1", if (length(ord)) c("|", "~*~")), , drop = FALSE]
    swap <- p$op == "~~" & p$lhs > p$rhs
    left <- ifelse(swap, p$rhs, p$lhs)
    right <- ifelse(swap, p$lhs, p$rhs)
    p$key <- paste(left, p$op, right, sep = " ")
    if (anyDuplicated(p$key)) stop("Repeated parameter rows; nesting cannot be verified.", call. = FALSE)
    rownames(p) <- p$key
    p
  }
  pa <- get_table(a)
  pb <- get_table(b)
  restrictions <- character()
  for (key in union(pa$key, pb$key)) {
    xa <- if (key %in% pa$key) pa[key, , drop = FALSE] else NULL
    xb <- if (key %in% pb$key) pb[key, , drop = FALSE] else NULL
    row <- if (is.null(xa)) xb else xa
    can_restrict <- row$op == "~" || (row$op == "~~" && row$lhs != row$rhs)
    # A missing path or off-diagonal covariance denotes zero, but a missing
    # measurement loading, intercept or variance is not accepted in this check.
    if ((is.null(xa) || is.null(xb)) && !can_restrict)
      return(paste("Different measurement/variance/mean specification:", key))
    free_a <- !is.null(xa) && xa$free > 0L
    free_b <- !is.null(xb) && xb$free > 0L
    if (!free_a && free_b) return(paste("B frees a parameter fixed/absent in A:", key))
    if (free_a && !free_b) {
      if (!can_restrict) return(paste("Restriction is outside this version's scope:", key))
      restrictions <- c(restrictions, key)
    }
    if (!free_a && !free_b) {
      # Delta-parameterized ordinal response residual variances are derived,
      # not independent fixed estimates. Compare their specification instead
      # of the fitted residual variance (which can change across models).
      derived <- length(ord) && !is.null(xa) && !is.null(xb) &&
        row$op == "~~" && row$lhs == row$rhs && row$lhs %in% ord &&
        xa$user == 0L && xb$user == 0L
      va <- if (is.null(xa)) 0 else if (derived) xa$ustart else xa$est
      vb <- if (is.null(xb)) 0 else if (derived) xb$ustart else xb$est
      if (!isTRUE(all.equal(va, vb, tolerance = 1e-7)))
        return(paste("Different fixed parameter values:", key))
    }
  }
  da <- as.numeric(lavaan::fitMeasures(a, "df"))
  db <- as.numeric(lavaan::fitMeasures(b, "df"))
  if (!advancedRestrictionDfMatches(da, db, length(restrictions)))
    return(paste0("The df difference does not match the detected independent restrictions. ",
      "df(A) = ", paste(da, collapse = ", "), "; df(B) = ", paste(db, collapse = ", "),
      "; detected restrictions = ", length(restrictions), "."))
  structure(restrictions, class = "advanced_restrictions")
}

advancedLRT <- function(a, b, names = c("Less restricted", "More restricted")) {
  if (!advancedUsable(a) || !advancedUsable(b))
    return(list(value = NULL, warnings = character(), error = "Both fits must converge and be admissible."))
  if (length(a$warnings) || length(b$warnings))
    return(list(value = NULL, warnings = character(), error = "A fit issued warnings. Review them before formal comparison."))
  ans <- advancedCapture({
    why <- advancedCompatibility(a$value, b$value)
    if (!is.null(why)) stop(why, call. = FALSE)
    dfs <- vapply(list(a$value, b$value), function(f) unname(lavaan::fitMeasures(f, "df")), numeric(1))
    chis <- vapply(list(a$value, b$value), function(f) unname(lavaan::fitMeasures(f, "chisq")), numeric(1))
    if (!all(is.finite(c(dfs, chis))) || dfs[2] <= dfs[1])
      stop("The restricted model must have strictly more degrees of freedom.", call. = FALSE)
    if (chis[2] + 1e-5 < chis[1])
      stop("The ordinary chi-square decreases after restriction; check nesting/optimization.", call. = FALSE)
    # The default method dispatches according to lavaan's actual test statistics;
    # robust chi-square values must never be naively subtracted.
    tab <- if (length(lavaan::lavInspect(a$value, "ordered")))
      lavaan::lavTestLRT(a$value, b$value, method = "satorra.2000",
        a.method = "delta", scaled.shifted = TRUE, test = "scaled.shifted", model.names = names) else
      lavaan::lavTestLRT(a$value, b$value, model.names = names)
    d <- tab[2L, "Chisq diff"]
    p <- tab[2L, "Pr(>Chisq)"]
    if (length(d) != 1L || !is.finite(d) || d < 0 || length(p) != 1L || !is.finite(p))
      stop("The difference test is unavailable or invalid; inspect the model and test method.", call. = FALSE)
    tab
  })
  if (length(ans$warnings)) {
    ans$value <- NULL
    ans$error <- "The difference test issued warnings; no formal inference is displayed."
  }
  ans
}

advancedCompare <- function(a, b, data, confirmed = FALSE) {
  advancedCheckSnapshot(a, data)
  advancedCheckSnapshot(b, data)
  if (!identical(a$options[sort(names(a$options))], b$options[sort(names(b$options))]))
    stop("The two saved models have different estimation settings. Use identical settings.", call. = FALSE)
  args <- list(A = advancedArgs(a, data), B = advancedArgs(b, data))
  fits <- lapply(args, advancedFit)
  test <- list(value = NULL, warnings = character(), error = "Confirm nesting to request a difference test.")
  restrictions <- character()
  compatibility <- advancedCapture({
    if (!all(vapply(fits, advancedUsable, logical(1)))) stop("Both models must converge and be admissible.", call. = FALSE)
    why <- advancedCompatibility(fits$A$value, fits$B$value)
    if (!is.null(why)) stop(why, call. = FALSE)
    TRUE
  })
  if (!is.null(compatibility$error) || length(compatibility$warnings)) {
    test <- list(value = NULL, warnings = compatibility$warnings,
      error = paste("The fit summaries are separate results, not a valid model comparison. Do not compare AIC/BIC or chi-squares:",
        if (is.null(compatibility$error)) "compatibility check issued warnings" else compatibility$error))
  } else if (isTRUE(confirmed)) {
    check <- advancedCapture({
      r <- advancedRestriction(fits$A$value, fits$B$value)
      if (!inherits(r, "advanced_restrictions")) stop(r, call. = FALSE)
      as.character(r)
    })
    if (is.null(check$error) && !length(check$warnings)) {
      restrictions <- check$value
      test <- advancedLRT(fits$A, fits$B, c("A", "B"))
    } else {
      test <- list(value = NULL, warnings = check$warnings, error = if (is.null(check$error)) "Nesting check issued warnings." else check$error)
    }
  }
  list(fits = fits, summary = advancedSummary(fits), tests = list("A vs B" = test),
       restrictions = restrictions, args = args, hash = a$hash,
       note = paste("A is the less restricted model; B is the more restricted model.",
         if (length(a$options$ordered)) "Ordinal WLSMV: the test uses the scaled-shifted Satorra (2000) correction; do not subtract the displayed scaled statistics. AIC/BIC are not applicable." else "",
         "A successful test is conditional on the specified nesting and regularity assumptions."))
}

advancedGroupCandidates <- function(data, spec = NULL) {
  if (is.null(data)) return(character())
  cols <- names(data)[vapply(data, function(x) {
    if (!(is.character(x) || is.factor(x) || is.numeric(x) || is.logical(x))) return(FALSE)
    if (is.numeric(x) && any(!is.finite(x) & !is.na(x))) return(FALSE)
    z <- as.character(x[!is.na(x)])
    k <- length(unique(z[nzchar(trimws(z))]))
    k >= 2L && k <= 10L
  }, logical(1))]
  if (!is.null(spec)) {
    pt <- tryCatch(lavaan::lavaanify(spec$syntax, auto = FALSE), error = function(e) NULL)
    if (!is.null(pt)) cols <- setdiff(cols, lavaan::lavNames(pt, "ov"))
  }
  cols
}

# Keys use lavaan's documented group.partial syntax (no spaces).
# Do not offer marker loadings or fixed regressions as selectable parameters.
advancedGroupChoices <- function(spec) {
  empty <- list(loadings = character(), intercepts = character(), regressions = character())
  if (is.null(spec)) return(empty)
  pt <- lavaan::lavaanify(spec$syntax, auto = TRUE)
  lv <- lavaan::lavNames(pt, "lv")
  loads <- pt[pt$user == 1L & pt$op == "=~" & !pt$rhs %in% lv, , drop = FALSE]
  # Exclude the first loading per factor even when a malformed model has freed it.
  free_loads <- loads[duplicated(loads$lhs) & loads$free > 0L, , drop = FALSE]
  slopes <- pt[pt$user == 1L & pt$op == "~" & pt$free > 0L, , drop = FALSE]
  list(loadings = if (nrow(free_loads)) unique(paste0(free_loads$lhs, "=~", free_loads$rhs)) else character(),
       intercepts = if (nrow(loads)) paste0(unique(loads$rhs), "~1") else character(),
       regressions = if (nrow(slopes)) unique(paste0(slopes$lhs, "~", slopes$rhs)) else character())
}

advancedCheckSelection <- function(x, choices, what) {
  if (is.null(x)) return(character())
  if (!is.character(x) || anyNA(x) || any(!x %in% choices))
    stop(paste("Invalid or outdated selection:", what, "Select parameters from the current model."), call. = FALSE)
  unique(x)
}

# Ordinal multigroup CFA: the identification constraints change across stages.
# Do not recycle the continuous group.equal workflow or the GUI marker scale.
# semTools implements Wu & Estabrook (2016); its generated syntax is the
# specification fitted and exported. Scope deliberately restricted to simple CFA
# with >=4 categories, equal observed category sets, no residual correlations.
advancedOrdinalGroupPlan <- function(spec, data, group, strict = FALSE, base = "metric",
                                      release_loadings = character(), release_intercepts = character(),
                                      selected_regressions = NULL, validate_only = FALSE) {
  pt <- advancedCheckSnapshot(spec, data)
  if (!length(spec$options$ordered)) stop("Declare every CFA indicator ordered and choose WLSMV in the editor first.", call. = FALSE)
  if (!requireNamespace("semTools", quietly = TRUE))
    stop("Ordinal invariance requires the optional semTools package. Install it in R with install.packages('semTools'), then restart lavaangui.", call. = FALSE)
  if (length(release_loadings) || length(release_intercepts) || !is.null(selected_regressions))
    stop("This ordinal sequence tests full invariance only. Partial ordinal invariance and structural regressions need a separate identification workflow.", call. = FALSE)
  if (!is.null(spec$options$se) && !tolower(spec$options$se) %in% c("default", "robust.sem"))
    stop("Use default WLSMV standard errors for ordinal invariance.", call. = FALSE)
  if (!isTRUE(spec$options$auto.var) || !isTRUE(spec$options$auto.cov.lv.x))
    stop("Enable automatic variances and latent covariances for this correlated-factor ordinal CFA.", call. = FALSE)
  lv <- lavaan::lavNames(pt, "lv"); ov <- lavaan::lavNames(pt, "ov")
  if (length(group) != 1L || is.na(group) || !group %in% advancedGroupCandidates(data, spec) || group %in% ov)
    stop("Choose a separate grouping column with 2 to 10 nonempty groups.", call. = FALSE)
  user <- pt[pt$user == 1L, , drop = FALSE]
  loads <- user[user$op == "=~", , drop = FALSE]
  if (!length(lv) || !nrow(loads) || any(!user$op %in% c("=~", "~~")) ||
      any(!is.na(user$label) & nzchar(user$label)) || any(!loads$rhs %in% ov) ||
      anyDuplicated(loads$rhs) || !setequal(loads$rhs, ov) ||
      !setequal(spec$options$ordered, ov) || any(table(loads$lhs) < 3L))
    stop("Ordinal invariance currently requires a simple correlated-factor CFA: all indicators ordered, at least three indicators per factor, no cross-loadings, regressions, labels or other constraints.", call. = FALSE)
  if (!all(make.names(c(lv, ov)) == c(lv, ov)))
    stop("Use ordinary R-compatible factor and indicator names for ordinal invariance.", call. = FALSE)
  first <- !duplicated(loads$lhs)
  if (any(loads$free == 0L & (!first | is.na(loads$ustart) | loads$ustart != 1)))
    stop("Only an ordinary first-marker loading may be fixed; the ordinal sequence uses its own factor scaling.", call. = FALSE)
  cov <- user[user$op == "~~", , drop = FALSE]
  if (nrow(cov) && (any(cov$free == 0L) || any(cov$lhs != cov$rhs & !(cov$lhs %in% lv & cov$rhs %in% lv))))
    stop("Fixed variances/covariances and correlated indicator residuals are outside this first ordinal invariance workflow.", call. = FALSE)
  z <- as.character(data[[group]])
  keep <- !is.na(z) & nzchar(trimws(z))
  d <- as.data.frame(data[keep, , drop = FALSE]); d[[group]] <- as.character(d[[group]])
  labels <- unique(d[[group]])
  counts <- table(factor(d[[group]], levels = labels))
  if (length(labels) < 2L) stop("At least two groups are required.", call. = FALSE)
  cc <- d[stats::complete.cases(d[, ov, drop = FALSE]), , drop = FALSE]
  ncat <- integer(length(ov)); names(ncat) <- ov
  for (nm in ov) {
    cats <- sort(unique(as.character(cc[[nm]])))
    ncat[nm] <- length(cats)
    if (length(cats) < 4L || length(cats) > 12L)
      stop(paste("Indicator", nm, "must have 4 to 12 observed categories after listwise deletion. Binary and three-category identification are not implemented."), call. = FALSE)
    if (is.ordered(d[[nm]]) && !setequal(levels(d[[nm]]), cats))
      stop(paste("Remove unused ordered-factor levels for", nm, "before estimation."), call. = FALSE)
    for (g in labels) {
      freq <- table(factor(as.character(cc[[nm]][cc[[group]] == g]), levels = cats))
      if (any(freq < 5L)) stop(paste("Each category needs at least five complete cases in every group in this prototype. Indicator:", nm, "; group:", g), call. = FALSE)
    }
  }
  # Rebuild only the validated simple structure. All latent covariances are
  # free; explicit marker loadings and free variances do not carry over.
  syntax <- paste(vapply(lv, function(f) paste(f, "=~", paste(loads$rhs[loads$lhs == f], collapse = " + ")), character(1)), collapse = "\n")
  sets <- list(Configural = character(), Thresholds = "thresholds",
    Metric = c("thresholds", "loadings"), Scalar = c("thresholds", "loadings", "intercepts"))
  if (isTRUE(strict)) sets$Strict <- c(sets$Scalar, "residuals")
  args <- stats::setNames(vector("list", length(sets)), names(sets))
  if (!isTRUE(validate_only)) {
    args <- lapply(names(sets), function(nm) {
      eq <- sets[[nm]]
      generated <- advancedCapture(semTools::measEq.syntax(configural.model = syntax,
        data = d, group = group, group.label = labels, ordered = ov,
        estimator = "WLSMV", missing = "listwise", parameterization = "theta",
        ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016",
        group.equal = if (length(eq)) eq else "", return.fit = FALSE))
      if (!is.null(generated$error) || length(generated$warnings))
        stop(paste(c(paste("Cannot generate", nm, "ordinal syntax:"), generated$error, generated$warnings), collapse = "\n"), call. = FALSE)
      list(model = as.character(generated$value), data = d, group = group,
        group.label = labels, ordered = ov, estimator = "WLSMV",
        parameterization = "theta", missing = "listwise", meanstructure = TRUE)
    })
    names(args) <- names(sets)
  }
  list(args = args, counts = counts, dropped = sum(!keep), group = group,
    labels = labels, sets = sets, partials = stats::setNames(lapply(sets, function(x) character()), names(sets)),
    mode = "ordinal", base = "metric", strict = isTRUE(strict), constrained_regressions = character(),
    # For >=4 categories per simple indicator, threshold equality frees two
    # response location/scale parameters per nonreference group. Equal
    # loadings/intercepts then release one factor scale/location per factor.
    # A disagreement with actual df suppresses the corresponding formal test.
    expected_steps = (length(labels) - 1L) * c(sum(ncat - 3L),
      length(ov) - length(lv), length(ov) - length(lv), if (isTRUE(strict)) length(ov)),
    hash = spec$hash, spec_id = advancedSpecId(spec),
    ordinal_identification = "Wu.Estabrook.2016; theta; std.lv; semTools::measEq.syntax",
    semTools_version = as.character(utils::packageVersion("semTools")),
    request = list(group = group, mode = "ordinal", strict = isTRUE(strict), base = "metric",
      release_loadings = character(), release_intercepts = character(), selected_regressions = NULL))
}

advancedGroupPlan <- function(spec, data, group, mode = "invariance", strict = FALSE, base = "metric",
                              release_loadings = character(), release_intercepts = character(),
                              selected_regressions = NULL, validate_only = FALSE) {
  if (is.null(base)) base <- "metric"
  if (identical(mode, "ordinal")) return(advancedOrdinalGroupPlan(spec, data, group, strict, base,
    release_loadings, release_intercepts, selected_regressions, validate_only))
  pt <- advancedCheckSnapshot(spec, data)
  if (length(spec$options$ordered))
    stop("Choose Ordinal measurement invariance (WLSMV) for an entirely ordinal CFA. Ordinal structural comparisons are not supported here.", call. = FALSE)
  if (any(!pt$op %in% c("=~", "~", "~~")) ||
      any(!is.na(pt$label) & nzchar(pt$label))) {
    stop("Remove explicit intercepts, parameter labels, defined effects or special constraints for this experimental multigroup workflow. Labels can silently impose equality across groups.", call. = FALSE)
  }
  lv <- lavaan::lavNames(pt, "lv")
  ov <- lavaan::lavNames(pt, "ov")
  if (length(group) != 1L || !group %in% advancedGroupCandidates(data, spec) || group %in% ov)
    stop("Choose a separate grouping column with 2 to 10 nonempty groups.", call. = FALSE)
  if (any(pt$op == "=~" & pt$rhs %in% lv))
    stop("Higher-order factor models are not supported in this version.", call. = FALSE)
  if (any(pt$op == "=~")) {
    if (!isTRUE(spec$options$auto.fix.first) || !isTRUE(spec$options$auto.var))
      stop("This workflow requires automatic marker scaling and automatic variances.", call. = FALSE)
    # The syntax-only table uses auto = FALSE. It can contain implicit
    # variances fixed at zero (user == 0), even though the actual fit uses
    # auto.var = TRUE. Check marker scaling with automatic marker defaults,
    # which the options above require, and explicit restrictions separately.
    marker_pt <- lavaan::lavaanify(spec$syntax, auto = TRUE)
    load <- marker_pt[marker_pt$op == "=~" & marker_pt$user == 1L, , drop = FALSE]
    first <- !duplicated(load$lhs)
    if (any(first & (load$free != 0L | is.na(load$ustart) | load$ustart != 1)) ||
        any(!first & load$free == 0L))
      stop("Use the ordinary first-marker scaling without additional fixed loadings.", call. = FALSE)
    if (any(pt$user == 1L & pt$free == 0L & pt$op == "~~" &
            pt$lhs == pt$rhs & pt$lhs %in% lv))
      stop("Do not fix latent variances in this marker-scaled workflow.", call. = FALSE)
  }
  # Only an explicit fixed parameter is a restriction. In particular, ustart
  # may be a starting value for a free parameter, not a fixed coefficient.
  # An explicitly fixed zero covariance or regression remains supported.
  fixed <- pt$user == 1L & pt$free == 0L & pt$op %in% c("~", "~~")
  if (any(fixed & (is.na(pt$ustart) | pt$ustart != 0 | (pt$op == "~~" & pt$lhs == pt$rhs)), na.rm = TRUE)) {
    stop("Additional fixed nonzero coefficients or fixed variances are not supported in this multigroup workflow.", call. = FALSE)
  }
  if (!mode %in% c("invariance", "regressions")) stop("Unknown analysis type.", call. = FALSE)
  choices <- advancedGroupChoices(spec)
  release_loadings <- advancedCheckSelection(release_loadings, choices$loadings, "loadings")
  release_intercepts <- advancedCheckSelection(release_intercepts, choices$intercepts, "intercepts")
  partials <- list()
  expected_steps <- NULL
  constrained_regressions <- character()
  if (identical(mode, "invariance")) {
    if (!length(lv) || any(pt$op == "~"))
      stop("Use the invariance sequence for an AFC/CFA without regressions. Use Equal regressions for structural models.", call. = FALSE)
    if (!is.null(selected_regressions)) stop("Regression selections require the regression analysis mode.", call. = FALSE)
    partial <- length(release_loadings) + length(release_intercepts) > 0L
    if (partial) {
      # Conservative scope: simple structure, at least two common indicators
      # per factor whose loadings AND intercepts remain invariant.
      loads <- pt[pt$user == 1L & pt$op == "=~", , drop = FALSE]
      if (anyDuplicated(loads$rhs))
        stop("Partial invariance currently requires simple structure (no cross-loadings).", call. = FALSE)
      lk <- paste0(loads$lhs, "=~", loads$rhs)
      ik <- paste0(loads$rhs, "~1")
      anchors <- table(factor(loads$lhs[!lk %in% release_loadings & !ik %in% release_intercepts], levels = unique(loads$lhs)))
      if (any(anchors < 2L))
        stop(paste("Keep at least two indicators with invariant loadings and intercepts per factor. Check:",
          paste(names(anchors)[anchors < 2L], collapse = ", ")), call. = FALSE)
      # These counts apply to the supported simple continuous CFA with marker
      # scaling; scalar identification frees one latent mean per factor/group.
      expected_steps <- c(length(choices$loadings) - length(release_loadings),
                          length(choices$intercepts) - length(release_intercepts) - length(lv))
      if (isTRUE(strict)) expected_steps <- c(expected_steps, length(choices$intercepts))
    }
    sets <- list(Configural = character(), Metric = "loadings", Scalar = c("loadings", "intercepts"))
    partials <- list(character(), release_loadings, c(release_loadings, release_intercepts))
    if (isTRUE(strict)) {
      sets$Strict <- c("loadings", "intercepts", "residuals")
      partials[[4L]] <- c(release_loadings, release_intercepts)
    }
    if (length(release_loadings)) names(sets)[2L] <- "Partial metric"
    if (partial) {
      names(sets)[3L] <- "Partial scalar"
      if (isTRUE(strict)) names(sets)[4L] <- "Partial strict"
    }
  } else {
    if (length(release_loadings) || length(release_intercepts))
      stop("Measurement releases are currently supported only in the CFA invariance mode.", call. = FALSE)
    if (!length(choices$regressions)) stop("The diagram must contain free regressions.", call. = FALSE)
    if (length(lv)) {
      if (!base %in% c("metric", "scalar")) stop("Choose and justify a common latent measurement scale.", call. = FALSE)
      eq <- if (base == "metric") "loadings" else c("loadings", "intercepts")
    } else eq <- character()
    constrained_regressions <- if (is.null(selected_regressions)) choices$regressions else
      advancedCheckSelection(selected_regressions, choices$regressions, "regressions")
    if (!length(constrained_regressions)) stop("Select at least one free regression to constrain.", call. = FALSE)
    sets <- list("Free regressions" = eq, "Equal regressions" = c(eq, "regressions"))
    partials <- list(character(), setdiff(choices$regressions, constrained_regressions))
    if (length(partials[[2L]])) names(sets)[2L] <- "Selected equal regressions"
    if (!is.null(selected_regressions)) expected_steps <- length(constrained_regressions)
  }
  names(partials) <- names(sets)
  z <- as.character(data[[group]])
  keep <- !is.na(z) & nzchar(trimws(z))
  d <- as.data.frame(data[keep, , drop = FALSE])
  # Explicit group labels preserve the first-occurrence order, with a visible reference group.
  d[[group]] <- as.character(d[[group]])
  labels <- unique(d[[group]])
  counts <- table(factor(d[[group]], levels = labels))
  if (length(labels) < 2L || any(counts < 2L)) stop("Each group needs at least two observations before estimation.", call. = FALSE)
  args <- lapply(names(sets), function(nm) advancedArgs(spec, d, list(
    group = group, group.label = labels, group.equal = sets[[nm]], group.partial = partials[[nm]],
    meanstructure = TRUE, int.ov.free = TRUE, int.lv.free = FALSE
  )))
  names(args) <- names(sets)
  list(args = args, counts = counts, dropped = sum(!keep), group = group,
       labels = labels, sets = sets, partials = partials, mode = mode, base = base, strict = strict,
       constrained_regressions = constrained_regressions,
       expected_steps = if (is.null(expected_steps)) NULL else expected_steps * (length(labels) - 1L),
       hash = spec$hash,
       spec_id = advancedSpecId(spec),
       request = list(group = group, mode = mode, strict = isTRUE(strict), base = base,
         release_loadings = release_loadings, release_intercepts = release_intercepts,
         selected_regressions = selected_regressions))
}

advancedMultigroup <- function(spec, data, group, mode = "invariance", strict = FALSE, base = "metric",
                               progress = function(...) NULL, release_loadings = character(),
                               release_intercepts = character(), selected_regressions = NULL) {
  plan <- advancedGroupPlan(spec, data, group, mode, strict, base,
                            release_loadings, release_intercepts, selected_regressions)
  fits <- lapply(names(plan$args), function(nm) {
    progress(nm, length(plan$args))
    advancedFit(plan$args[[nm]], if (identical(plan$mode, "ordinal")) lavaan::cfa else lavaan::lavaan)
  })
  names(fits) <- names(plan$args)
  tests <- list()
  for (i in seq_len(length(fits) - 1L)) {
    nm <- names(fits)[c(i, i + 1L)]
    test <- advancedLRT(fits[[i]], fits[[i + 1L]], nm)
    if (!is.null(test$value) && !is.null(plan$expected_steps)) {
      actual <- test$value[2L, "Df diff"]
      expected <- plan$expected_steps[i]
      if (length(actual) != 1L || !is.finite(actual) || abs(actual - expected) > 1e-7) {
        test$value <- NULL
        test$error <- paste("Unexpected degrees-of-freedom difference for the selected constraints. Expected:", expected, "; observed:", actual)
      }
    }
    tests[[paste(nm, collapse = " vs ")]] <- test
  }
  # Report cases actually used by each fit, not just the raw group sizes.
  used <- do.call(rbind, lapply(names(fits), function(nm) {
    f <- fits[[nm]]
    if (is.null(f$value)) return(NULL)
    labs <- lavaan::lavInspect(f$value, "group.label")
    data.frame(Model = nm, Group = labs, N_used = unlist(lavaan::lavInspect(f$value, "nobs")), row.names = NULL)
  }))
  c(plan, list(fits = fits, summary = advancedSummary(fits), tests = tests, used = used,
    note = paste(if (identical(plan$mode, "ordinal"))
      paste("Ordinal CFA: WLSMV, theta, Wu & Estabrook (2016) identification, std.lv via semTools", plan$semTools_version,
        ". Thresholds precede loadings, intercepts of latent responses, and optional residual variances. Scale-identifying constraints change between stages. The displayed raw estimates are on the generated ordinal scales; they are not the original marker-scaled GUI estimates. Inspect thresholds in Selected estimates. Interpret later stages conditional on earlier restrictions; do not interpret a rejected sequence as established invariance.") else "",
      "Equality constraints concern unstandardized parameters. Assess fit, uncertainty and measurement theory; non-rejection alone does not establish invariance. Data-guided releases or selections are exploratory and should be justified and validated on new data.")))
}

advancedParameters <- function(out, standardized = FALSE, level = .95) {
  if (!advancedUsable(out)) stop("Select a converged, admissible model.", call. = FALSE)
  f <- out$value
  p <- if (isTRUE(standardized)) lavaan::standardizedSolution(f, level = level) else
    lavaan::parameterEstimates(f, level = level)
  if ("group" %in% names(p)) {
    labels <- lavaan::lavInspect(f, "group.label")
    p$Group <- rep("All", nrow(p))
    ok <- !is.na(p$group) & p$group %in% seq_along(labels)
    p$Group[ok] <- labels[p$group[ok]]
    p <- p[c("Group", setdiff(names(p), "Group"))]
  }
  p
}

advancedScript <- function(result) {
  # Serialize syntax/options as R literals, not executable text from the client.
  lines <- c("# lavaangui experimental advanced analyses", "library(lavaan)",
             "# Load the identical original dataset as a data.frame named data.",
             "stopifnot(exists('data'), is.data.frame(data))",
             "# Check that the original data and column order have been preserved.",
             sprintf("stopifnot(identical(digest::digest(as.data.frame(data)), '%s'))", result$hash))
  if (!is.null(result$group)) {
    lines <- c(lines, paste0("group <- ", paste(utils::capture.output(dput(result$group)), collapse = "")),
               "z <- as.character(data[[group]])", "data <- data[!is.na(z) & nzchar(trimws(z)), , drop = FALSE]",
               "data[[group]] <- as.character(data[[group]])")
  }
  configs <- lapply(result$args, function(a) { a$data <- NULL; a })
  lines <- c(lines, "configs <-", utils::capture.output(dput(configs)),
    if (identical(result$mode, "ordinal"))
      "# Generated ordinal syntax (semTools::measEq.syntax; Wu & Estabrook 2016, theta, std.lv)." else "# Fitted specifications",
    sprintf("fits <- lapply(configs, function(a) do.call(lavaan::%s, c(a, list(data = as.data.frame(data)))))", if (identical(result$mode, "ordinal")) "cfa" else "lavaan"),
    "print(lapply(fits, function(f) lavaan::lavInspect(f, 'converged')))",
    "print(lapply(fits, function(f) lavaan::lavInspect(f, 'post.check')))",
    "print(lapply(fits, function(f) lavaan::fitMeasures(f)))")
  if (length(result$tests)) {
    for (i in seq_along(result$tests)) {
      if (!is.null(result$tests[[i]]$value)) {
        extra <- if (length(result$args[[i]]$ordered))
          ", method = 'satorra.2000', a.method = 'delta', scaled.shifted = TRUE, test = 'scaled.shifted'" else ""
        lines <- c(lines, sprintf("print(lavaan::lavTestLRT(fits[[%d]], fits[[%d]]%s))", i, i + 1L, extra))
      } else lines <- c(lines, paste("# No formal comparison for", names(result$tests)[i], "(see GUI diagnostics)."))
    }
  }
  c(lines, "sessionInfo()")
}


# A lightweight companion file, not an R serialized object or an executable
# script. Only the existing, freshly estimated GUI specification can be used
# to restore a recipe. The uploaded file never supplies model syntax to fit.
advancedSpecId <- function(spec) {
  if (is.null(spec)) return(NULL)
  digest::digest(list(syntax = spec$syntax, options = spec$options[sort(names(spec$options))]))
}

# Portable view state: plain labels and bounded numeric coordinates only.
# Never use client-provided markup, paths, expressions or canvas dimensions.
advancedValidateDiagramView <- function(view, stages, groups, nodes = NULL) {
  fail <- function() stop("Invalid or incompatible saved diagram view.", call. = FALSE)
  keys <- function(x, expected) is.list(x) && !is.null(names(x)) &&
    !anyDuplicated(names(x)) && setequal(names(x), expected)
  text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  flag <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)
  number <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  expected <- c("stage", "group", "other", "mode", "scale", "kind", "digits", "zoom",
                "covariances", "variances", "wide", "positions")
  if (!keys(view, expected)) fail()
  for (nm in c("stage", "group", "other", "mode", "scale", "kind")) if (!text(view[[nm]])) fail()
  for (nm in c("covariances", "variances", "wide")) if (!flag(view[[nm]])) fail()
  if (!view$stage %in% stages || !view$group %in% groups || !view$other %in% groups || view$group == view$other ||
      !view$mode %in% c("single", "compare", "difference") || !view$scale %in% c("raw", "std") ||
      !view$kind %in% c("measurement", "horizontal", "vertical") ||
      !number(view$digits) || !view$digits %in% c(2, 3, 4) ||
      !number(view$zoom) || !view$zoom %in% c(70, 85, 100, 125, 150)) fail()
  pos <- view$positions
  if (!is.list(pos) || !is.null(names(pos)) || !length(pos) || length(pos) > 1000L) fail()
  for (p in pos) {
    if (!keys(p, c("label", "x", "y")) || !text(p$label) || nchar(p$label) > 1000L ||
        !number(p$x) || !number(p$y) || p$x < 0 || p$y < 0 || p$x > 1e6 || p$y > 1e6) fail()
  }
  labs <- vapply(pos, function(p) p$label, character(1))
  if (anyDuplicated(labs) || (!is.null(nodes) && !setequal(labs, nodes))) fail()
  view[expected]
}

advancedViewForResult <- function(view, result) {
  if (is.null(view)) return(NULL)
  if (is.null(result$fits[[view$stage]]) || !advancedUsable(result$fits[[view$stage]]))
    stop("The saved diagram stage is not available in the current results.", call. = FALSE)
  f <- result$fits[[view$stage]]$value
  advancedValidateDiagramView(view, names(result$fits), result$labels,
    unique(c(lavaan::lavNames(f, "lv"), lavaan::lavNames(f, "ov"))))
}

advancedWriteGroupProject <- function(result, file, diagram_view = NULL) {
  if (is.null(result$request) || is.null(result$spec_id) || is.null(result$group))
    stop("Run a multiple-group analysis first.", call. = FALSE)
  # Saved numeric tables are an audit snapshot only; never reinstated as live
  # estimates. Do not include raw data, lavaan objects or data-containing args.
  tests <- lapply(result$tests, function(x) list(table = if (is.null(x$value)) NULL else
    data.frame(Model = rownames(x$value), as.data.frame(x$value), check.names = FALSE, row.names = NULL),
    error = x$error, warnings = x$warnings))
  parameter_tables <- lapply(result$fits, function(out) {
    if (!advancedUsable(out)) return(NULL)
    raw <- advancedCapture(advancedParameters(out, FALSE))
    std <- advancedCapture(advancedParameters(out, TRUE))
    list(unstandardized = raw$value, standardized = std$value,
         diagnostics = c(raw$error, raw$warnings, std$error, std$warnings))
  })
  if (!is.null(diagram_view)) diagram_view <- advancedViewForResult(diagram_view, result)
  project <- list(format = "lavaangui-multigroup", version = 2L,
    created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    lavaan_version = as.character(utils::packageVersion("lavaan")),
    data_hash = result$hash, spec_id = result$spec_id, request = result$request,
    group_labels = result$labels, fit_summary = result$summary,
    used = result$used, tests = tests, parameter_tables = parameter_tables,
    diagnostics = advancedFitMessages(result$fits), diagram_view = diagram_view,
    semTools_version = result$semTools_version)
  jsonlite::write_json(project, path = file, auto_unbox = TRUE, pretty = TRUE,
                       dataframe = "rows", null = "null", na = "null", digits = NA)
  if (file.info(file)$size > 5 * 1024^2)
    stop("Analysis snapshot exceeds 5 MB. Use separate CSV and script exports for this large model.", call. = FALSE)
  invisible(file)
}

advancedReadGroupProject <- function(file, spec, data) {
  # Enforce an inexpensive size limit before parsing. JSON is treated only as
  # data; never source(), eval(), unserialize() or use embedded paths.
  info <- file.info(file)
  if (is.na(info$size) || info$size < 2 || info$size > 5 * 1024^2)
    stop("Choose a saved analysis JSON file of at most 5 MB.", call. = FALSE)
  obj <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  scalar_text <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  scalar_flag <- function(x) is.logical(x) && length(x) == 1L && !is.na(x)
  keys <- function(x, expected) is.list(x) && !is.null(names(x)) &&
    !anyDuplicated(names(x)) && setequal(names(x), expected)
  vector_text <- function(x) {
    if (is.null(x) || (is.list(x) && length(x) == 0L)) return(character())
    if (scalar_text(x)) return(x)
    if (!is.list(x) || !is.null(names(x)) || length(x) > 10000L ||
        !all(vapply(x, scalar_text, logical(1)))) stop("Invalid parameter selection in saved analysis.", call. = FALSE)
    unlist(x, use.names = FALSE)
  }
  expected <- c("format", "version", "created_utc", "lavaan_version", "data_hash", "spec_id",
    "request", "group_labels", "fit_summary", "used", "tests", "parameter_tables", "diagnostics")
  if (!is.numeric(obj$version) || length(obj$version) != 1L || is.na(obj$version) || !obj$version %in% c(1, 2) ||
      !keys(obj, if (obj$version == 2) c(expected, "diagram_view", "semTools_version") else expected) || !identical(obj$format, "lavaangui-multigroup"))
    stop("Not a supported lavaangui multigroup analysis file (versions 1 and 2).", call. = FALSE)
  advancedCheckSnapshot(spec, data)
  if (!identical(obj$data_hash, advancedDataHash(data)))
    stop("The loaded data differ from the saved analysis. Open the original data first.", call. = FALSE)
  if (!identical(obj$spec_id, advancedSpecId(spec)))
    stop("The current model or estimation settings differ. Open the original .lvm, restore its settings and estimate it first.", call. = FALSE)
  r <- obj$request
  if (!keys(r, c("group", "mode", "strict", "base", "release_loadings", "release_intercepts", "selected_regressions")) ||
      !scalar_text(r$group) || !scalar_text(r$mode) || !r$mode %in% c("invariance", "regressions", "ordinal") ||
      !scalar_flag(r$strict) || !scalar_text(r$base) || !r$base %in% c("metric", "scalar"))
    stop("Invalid saved analysis settings.", call. = FALSE)
  r$release_loadings <- vector_text(r$release_loadings)
  r$release_intercepts <- vector_text(r$release_intercepts)
  # NULL means all regressions; an empty selection is invalid for selected mode.
  if (!is.null(r$selected_regressions)) r$selected_regressions <- vector_text(r$selected_regressions)
  # Reuse the actual group-plan safeguards. No model is fitted here.
  plan <- do.call(advancedGroupPlan, c(list(spec = spec, data = data, validate_only = TRUE), r))
  if (!identical(vector_text(obj$group_labels), as.character(plan$labels)))
    stop("Group labels or reference group differ from the saved analysis.", call. = FALSE)
  view <- NULL
  if (!is.null(obj$diagram_view)) {
    pt <- lavaan::lavaanify(spec$syntax, auto = FALSE)
    view <- advancedValidateDiagramView(obj$diagram_view, names(plan$sets), plan$labels,
      unique(c(lavaan::lavNames(pt, "lv"), lavaan::lavNames(pt, "ov"))))
  }
  list(request = r, labels = plan$labels, counts = plan$counts, diagram_view = view,
       spec_id = advancedSpecId(spec), hash = spec$hash,
       lavaan_version = if (scalar_text(obj$lavaan_version)) obj$lavaan_version else "unknown",
       semTools_version = if (scalar_text(obj$semTools_version)) obj$semTools_version else NULL,
       created_utc = if (scalar_text(obj$created_utc)) obj$created_utc else "unknown")
}

# Exploratory, one-constraint-at-a-time score diagnostics for a continuous
# two-group CFA with ordinary ML. Do not infer a partial model or change a fit.
# Match lavaan's explicit constraint rows to the original parameter labels.
# lavaan 0.7-3 computes Browne's model-based normal-theory residual test
# alongside the standard ML chi-square by default. This extra fit statistic
# does not turn ordinary ML into MLR. Accept only these two documented test
# sets; keep standard SEs and the ordinary (not scaled) score output.
advancedScoreOrdinaryML <- function(opts) {
  tests <- gsub("_", ".", tolower(as.character(opts$test)), fixed = TRUE)
  identical(toupper(opts$estimator), "ML") &&
    (setequal(tests, "standard") ||
       setequal(tests, c("standard", "browne.residual.nt.model"))) &&
    identical(opts$se, "standard") && identical(opts$missing, "listwise")
}

advancedScoreCandidates <- function(out) {
  fail <- function(msg) stop(msg, call. = FALSE)
  if (!advancedUsable(out)) fail("Select a converged, admissible fitted model.")
  if (length(out$warnings)) fail("Resolve estimation warnings before running score diagnostics. See Fit table.")
  f <- out$value
  opts <- lavaan::lavInspect(f, "options")
  labs <- as.character(lavaan::lavInspect(f, "group.label"))
  if (length(labs) != 2L || length(lavaan::lavInspect(f, "ordered")) ||
      !advancedScoreOrdinaryML(opts))
    fail("Score diagnostics currently require two groups, continuous indicators, ordinary ML (standard test/SE), and listwise deletion. Use the existing robust fit comparisons for MLR/WLSMV.")
  pt <- as.data.frame(lavaan::parTable(f))
  lv <- lavaan::lavNames(f, "lv"); ov <- lavaan::lavNames(f, "ov")
  loads <- pt[pt$group == 1L & pt$op == "=~", , drop = FALSE]
  if (!length(lv) || !nrow(loads) || any(pt$op %in% c("~", "<", ">", ":=", "<~")) ||
      any(!loads$rhs %in% ov) || anyDuplicated(loads$rhs) || any(table(loads$lhs) < 3L))
    fail("Score diagnostics currently require simple continuous CFA with at least three indicators per factor.")
  eq <- pt[pt$op == "==", , drop = FALSE]
  if (!nrow(eq)) fail("No explicit equality constraints to diagnose. Select Metric, Scalar, Strict, or a constrained partial model.")
  if (nrow(eq) > 100L) fail("This prototype handles at most 100 explicit equality constraints per model.")
  par <- pt[pt$group %in% 1:2 & pt$free > 0L & !is.na(pt$plabel) & nzchar(pt$plabel), , drop = FALSE]
  if (anyDuplicated(par$plabel)) fail("Parameter labels cannot be matched uniquely.")
  key <- function(a) ifelse(a$op == "~1", paste0(a$lhs, "~1"), paste0(a$lhs, a$op, a$rhs))
  ans <- lapply(seq_len(nrow(eq)), function(i) {
    a <- par[match(eq$lhs[i], par$plabel), , drop = FALSE]
    b <- par[match(eq$rhs[i], par$plabel), , drop = FALSE]
    if (is.na(a$group) || is.na(b$group) || a$group == b$group || !identical(key(a), key(b)))
      fail("The fitted model has an equality constraint that is not a simple between-group parameter equality.")
    if (a$group == 2L) { tmp <- a; a <- b; b <- tmp }
    type <- if (a$op == "=~") "Loading" else if (a$op == "~1" && a$lhs %in% ov) "Intercept" else
      if (a$op == "~~" && a$lhs == a$rhs && a$lhs %in% ov) "Residual variance" else NA_character_
    if (is.na(type)) fail("A constraint is outside the supported loading, intercept and observed residual-variance scope.")
    data.frame(Constraint = i, Parameter = key(a), Type = type, lhs = a$lhs, op = a$op, rhs = a$rhs,
      Group1 = labs[1L], Group2 = labs[2L], label1 = a$plabel, label2 = b$plabel, stringsAsFactors = FALSE)
  })
  candidates <- do.call(rbind, ans)
  if (anyDuplicated(candidates$Parameter)) fail("Repeated equality constraints cannot be diagnosed unambiguously.")
  # Require two common loadings (and, at scalar/strict stages, two common
  # loading/intercept anchors) even after releasing one candidate. The same
  # conservative identification rule is used in the partial-CFA workflow.
  scalar <- "intercepts" %in% opts$group.equal
  fixed <- loads[loads$free == 0L & !is.na(loads$est) & loads$est == 1, , drop = FALSE]
  fixed2 <- pt[pt$group == 2L & pt$op == "=~" & pt$free == 0L & !is.na(pt$est) & pt$est == 1, , drop = FALSE]
  lk <- key(loads); ik <- paste0(loads$rhs, "~1")
  common <- lk %in% c(intersect(key(fixed), key(fixed2)), candidates$Parameter[candidates$Type == "Loading"])
  if (scalar) common <- common & ik %in% candidates$Parameter[candidates$Type == "Intercept"]
  candidates$Eligible <- vapply(seq_len(nrow(candidates)), function(i) {
    keep <- common & lk != candidates$Parameter[i] & (!scalar | ik != candidates$Parameter[i])
    all(table(factor(loads$lhs[keep], levels = unique(loads$lhs))) >= 2L)
  }, logical(1))
  candidates
}

advancedScoreDiagnostics <- function(out, progress = function(...) NULL) {
  candidates <- advancedScoreCandidates(out)
  f <- out$value
  rows <- vector("list", nrow(candidates)); epcs <- list()
  for (j in seq_len(nrow(candidates))) {
    a <- candidates[j, , drop = FALSE]; id <- a$Constraint
    progress(j, nrow(candidates))
    row <- a[c("Constraint", "Parameter", "Type", "Group1", "Group2")]
    row$X2 <- row$df <- row$p <- NA_real_
    row$Status <- "Not evaluated: fewer than two common anchors after release."
    if (isTRUE(a$Eligible)) {
      checked <- advancedCapture({
        # Each call releases exactly ONE equality; EPC is conditional on all
        # remaining equalities. Never use a joint-release EPC as a single EPC.
        z <- lavaan::lavTestScore(f, release = id, univariate = TRUE, epc = TRUE, standardized = FALSE)
        u <- as.data.frame(z$uni)
        if (nrow(u) != 1L || !all(c("lhs", "rhs", "X2", "df", "p.value") %in% names(u)) ||
            !setequal(c(u$lhs, u$rhs), c(a$label1, a$label2)) || !isTRUE(u$df == 1) ||
            !is.finite(u$X2) || u$X2 < -1e-8 || !is.finite(u$p.value) || u$p.value < 0 || u$p.value > 1)
          stop("Native score output did not match the requested equality.")
        e <- as.data.frame(z$epc)
        if (!all(c("lhs", "op", "rhs", "group", "est", "epc", "epv") %in% names(e))) stop("Native EPC columns unavailable.")
        e <- e[e$lhs == a$lhs & e$op == a$op & e$rhs == a$rhs & e$group %in% 1:2, , drop = FALSE]
        e <- e[order(e$group), , drop = FALSE]
        if (!identical(as.integer(e$group), 1:2) || !all(is.finite(c(e$est, e$epc, e$epv)))) stop("Native EPC values unavailable or ambiguous.")
        list(X2 = max(0, u$X2), df = u$df, p = u$p.value,
          epc = data.frame(Group = c(a$Group1, a$Group2), Parameter = a$Parameter,
                           Estimate = e$est, EPC = e$epc, Expected = e$epv, stringsAsFactors = FALSE))
      })
      if (is.null(checked$error) && !length(checked$warnings)) {
        row$X2 <- checked$value$X2; row$df <- checked$value$df; row$p <- checked$value$p
        row$Status <- "OK"
        epcs[[as.character(id)]] <- checked$value$epc
      } else row$Status <- paste(c("Not reported:", checked$error, checked$warnings), collapse = " ")
    }
    rows[[j]] <- row
  }
  tab <- do.call(rbind, rows)
  tab$p_Holm <- NA_real_
  ok <- is.finite(tab$p)
  tab$p_Holm[ok] <- stats::p.adjust(tab$p[ok], method = "holm", n = nrow(tab))
  tab <- tab[order(is.na(tab$p), tab$p, tab$Constraint), , drop = FALSE]
  list(table = tab, epcs = epcs)
}
