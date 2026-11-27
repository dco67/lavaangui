# Native-lavaan walkthrough for the exact bundled synthetic teaching CSV.
# From the source root: Rscript inst/advanced-examples/reference-examples.R
# Installed package: source(system.file("advanced-examples", "reference-examples.R", package="lavaangui"))
# Optional Rscript argument: path to the original CSV.
# No files are written. No private extension functions are used.
local({
  stopifnot(requireNamespace("lavaan", quietly = TRUE), requireNamespace("readr", quietly = TRUE))
  # Prefer an explicitly supplied path in Rscript; use the local checkout if
  # present, then the installed example. Never change the working directory.
  p <- ""
  argv <- commandArgs(trailingOnly = TRUE)
  if (length(argv) && file.exists(argv[1L]) && grepl("[.]csv$", argv[1L], ignore.case = TRUE)) p <- argv[1L]
  if (!nzchar(p) && file.exists("inst/advanced-examples/banc_lavaangui.csv"))
    p <- "inst/advanced-examples/banc_lavaangui.csv"
  if (!nzchar(p)) p <- system.file("advanced-examples", "banc_lavaangui.csv", package = "lavaangui")
  if (!nzchar(p) || !file.exists(p)) stop("Cannot locate the example CSV; run from the source root or supply its path.")
  d <- as.data.frame(readr::read_csv(p, show_col_types = FALSE))
  stopifnot(nrow(d) == 2400L, identical(as.integer(table(d$groupe)), c(1200L, 1200L)))
  d$groupe <- as.character(d$groupe)
  labs <- c("A", "B")
  # Match the example diagrams' ordinary lavaan GUI settings.
  opts <- list(meanstructure = "default", int.ov.free = FALSE, int.lv.free = FALSE,
    estimator = "ML", se = "default", missing = "listwise", auto.fix.first = TRUE,
    auto.fix.single = TRUE, auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE,
    fixed.x = TRUE, auto.th = TRUE, auto.delta = TRUE)
  fit <- function(model, extra = list()) {
    a <- utils::modifyList(opts, extra)
    f <- do.call(lavaan::lavaan, c(list(model = model, data = d), a))
    if (!isTRUE(lavaan::lavInspect(f, "converged")) || !isTRUE(lavaan::lavInspect(f, "post.check")))
      stop("Reference fit did not converge or is inadmissible; inspect warnings.")
    f
  }
  mg <- function(model, equal = character(), partial = character(), estimator = "ML") {
    fit(model, list(estimator = estimator, group = "groupe", group.label = labs,
      group.equal = equal, group.partial = partial, meanstructure = TRUE,
      int.ov.free = TRUE, int.lv.free = FALSE))
  }
  tab <- function(fits) {
    keys <- c("chisq", "df", "pvalue", "cfi", "rmsea", "srmr", "chisq.scaled", "pvalue.scaled")
    print(t(vapply(fits, function(f) {
      x <- setNames(rep(NA_real_, length(keys)), keys)
      m <- lavaan::fitMeasures(f, keys); x[names(m)] <- as.numeric(m); x
    }, setNames(numeric(length(keys)), keys))))
  }
  lrt <- function(a, b, ordinal = FALSE) {
    print(if (ordinal) lavaan::lavTestLRT(a, b, method = "satorra.2000",
      a.method = "delta", scaled.shifted = TRUE, test = "scaled.shifted") else lavaan::lavTestLRT(a, b))
  }
  seqtest <- function(fs, ordinal = FALSE) {
    tab(fs)
    for (i in seq_len(length(fs)-1L)) {
      cat("\n", names(fs)[i], " vs ", names(fs)[i+1L], "\n", sep = "")
      lrt(fs[[i]], fs[[i+1L]], ordinal)
    }
  }
  cfa <- "f1 =~ x1 + x2 + x3 + x4\nf2 =~ y1 + y2 + y3 + y4\nf1 ~~ f2"
  pa <- "M ~ X + Z\nY ~ M + X"
  pb <- "M ~ X + Z\nY ~ M"
  ob <- "oF =~ o1 + o2 + o3\npF =~ p1 + p2 + p3\noF ~~ pF"
  oa <- paste(ob, "o2 ~~ p2", sep = "\n")
  ord <- c(paste0("o", 1:3), paste0("p", 1:3))
  # Isolate examples so one failure does not conceal later examples.
  errors <- character()
  run <- function(title, expr) {
    cat("\n===== ", title, " =====\n", sep = "")
    tryCatch(force(expr), error = function(e) {
      errors <<- c(errors, paste(title, conditionMessage(e), sep = ": "))
      message("Example error: ", conditionMessage(e)); NULL
    })
  }
  for (est in c("ML", "MLR")) run(paste("Nested", est), {
    fs <- list(A = fit(pa, list(estimator = est)), B = fit(pb, list(estimator = est)))
    seqtest(fs)
  })
  run("Nested ordinal WLSMV (single-group delta)", {
    fs <- list(A = fit(oa, list(estimator = "WLSMV", ordered = ord)),
               B = fit(ob, list(estimator = "WLSMV", ordered = ord)))
    seqtest(fs, ordinal = TRUE)
  })
  eq <- list(Configural = character(), Metric = "loadings", Scalar = c("loadings", "intercepts"),
    Strict = c("loadings", "intercepts", "residuals"))
  full <- run("Full continuous invariance", {
    fs <- lapply(eq, function(e) mg(cfa, e)); seqtest(fs); fs
  })
  partial <- run("Partial continuous invariance", {
    releases <- list(character(), "f1=~x3", c("f1=~x3", "y3~1"), c("f1=~x3", "y3~1"))
    fs <- setNames(lapply(seq_along(eq), function(i) mg(cfa, eq[[i]], releases[[i]])),
      c("Configural", "Partial metric", "Partial scalar", "Partial strict"))
    seqtest(fs); fs
  })
  run("Native score and single-release EPC illustration", {
    # Use actual explicit equality rows and parameter labels, not positions
    # guessed from a printed table. Retain all other equalities on each call.
    get_score <- function(f, lhs, op, rhs) {
      p <- lavaan::parTable(f)
      r <- p[p$lhs == lhs & p$op == op & (op == "~1" | p$rhs == rhs) & p$group %in% 1:2, , drop = FALSE]
      z <- p[p$op == "==", , drop = FALSE]
      idx <- which(z$lhs %in% r$plabel & z$rhs %in% r$plabel)
      if (nrow(r) != 2L || length(idx) != 1L) stop("Cannot identify a unique equality; inspect the parameter table.")
      out <- lavaan::lavTestScore(f, release = idx, univariate = TRUE, epc = TRUE, standardized = FALSE)
      print(out$uni)
      e <- out$epc
      print(e[e$lhs == lhs & e$op == op & (op == "~1" | e$rhs == rhs) & e$group %in% 1:2, , drop = FALSE])
    }
    if (is.null(full) || is.null(partial)) stop("Continuous reference fits unavailable.")
    get_score(full$Metric, "f1", "=~", "x3")
    # Refit scalar stage with ONLY the loading released to diagnose y3.
    get_score(mg(cfa, eq$Scalar, "f1=~x3"), "y3", "~1", "")
    get_score(partial[["Partial strict"]], "y4", "~~", "y4")
  })
  for (est in c("ML", "MLR")) run(paste("Structural equality", est), {
    free <- mg(pa, estimator = est)
    slopes <- c("M~X", "M~Z", "Y~M", "Y~X")
    for (selected in list(slopes, "M~Z", c("M~Z", "Y~M"))) {
      cat("\nSelected: ", paste(selected, collapse = ", "), "\n", sep = "")
      constrained <- mg(pa, "regressions", setdiff(slopes, selected), estimator = est)
      seqtest(list(Free = free, Equal = constrained))
    }
  })
  run("Latent regression with a justified common measurement base", {
    m <- "uF =~ u1 + u2 + u3\nvF =~ v1 + v2 + v3\nvF ~ uF\nu2 ~~ v2"
    # Metric is assumed for illustration; verify the measurement model first in real research.
    seqtest(list(Free = mg(m, "loadings"), Equal = mg(m, c("loadings", "regressions"))))
  })
  if (requireNamespace("semTools", quietly = TRUE)) run("Ordinal full invariance (theta, Wu-Estabrook)", {
    sets <- list(Configural = character(), Thresholds = "thresholds", Metric = c("thresholds", "loadings"),
      Scalar = c("thresholds", "loadings", "intercepts"), Strict = c("thresholds", "loadings", "intercepts", "residuals"))
    fs <- lapply(sets, function(e) {
      s <- semTools::measEq.syntax(configural.model = ob, data = d, group = "groupe", group.label = labs,
        ordered = ord, estimator = "WLSMV", missing = "listwise", parameterization = "theta",
        ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016", group.equal = if (length(e)) e else "", return.fit = FALSE)
      f <- lavaan::cfa(as.character(s), data = d, group = "groupe", group.label = labs,
        ordered = ord, estimator = "WLSMV", parameterization = "theta", meanstructure = TRUE, missing = "listwise")
      if (!isTRUE(lavaan::lavInspect(f, "converged")) || !isTRUE(lavaan::lavInspect(f, "post.check"))) stop("Ordinal reference fit unusable.")
      f
    })
    seqtest(fs, ordinal = TRUE)
    cat("\nDegrees of freedom (expected 16, 22, 26, 30, 36):\n")
    print(vapply(fs, function(f) as.numeric(lavaan::fitMeasures(f, "df")), numeric(1)))
  }) else message("SKIP ordinal invariance: install optional semTools.")
  for (est in c("ML", "MLR")) run(paste("Native defined indirect and total effects", est), {
    # Labels/defined effects are intentionally native R syntax, not a supported
    # labeled specification for the GUI's advanced multiple-group workflow.
    m <- 'M ~ c(aA,aB)*X + c(zA,zB)*Z
          Y ~ c(bA,bB)*M + c(cA,cB)*X
          indA := aA*bA
          indB := aB*bB
          ind_diff := indB-indA
          direct_diff := cB-cA
          totalA := cA+indA
          totalB := cB+indB
          total_diff := totalB-totalA
          zindA := zA*bA
          zindB := zB*bB
          zind_diff := zindB-zindA'
    f <- mg(m, estimator = est)
    p <- lavaan::parameterEstimates(f, level = .95)
    print(p[p$op == ":=", c("lhs", "est", "se", "pvalue", "ci.lower", "ci.upper")])
  })
  print(sessionInfo())
  if (length(errors)) stop(paste(c("Some reference examples could not be completed:", errors), collapse = "\n"), call. = FALSE)
})
