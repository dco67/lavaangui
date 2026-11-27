# Run from the development repository root: Rscript tests/manual/advanced_analysis.R
# Optional: pass the root of the revised manual as the first command argument.
stopifnot(requireNamespace("lavaan", quietly = TRUE), requireNamespace("digest", quietly = TRUE))
for (f in c("R/advancedAnalysisCore.R", "R/componentAdvancedAnalysis.R", "R/start_app.R",
            "R/serverLavaanRun.R", "R/metaComponentExtendResults.R")) parse(file = f)
source("R/advancedAnalysisCore.R")
cat("lavaan ", as.character(utils::packageVersion("lavaan")), "\n", sep = "")
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = FALSE,
  int.ov.free = TRUE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
snap <- function(model, d, options = opts) advancedSnapshot(list(syntax = model, optionsList = options), d)
assert <- function(condition, msg) if (!isTRUE(condition)) stop(msg, call. = FALSE)
check_test <- function(result, name = names(result$tests)[1L]) {
  advancedPrint <- function() {
    print(result$summary)
    print(advancedFitMessages(result$fits))
    print(result$tests[[name]])
  }
  if (is.null(result$tests[[name]]$value)) { advancedPrint(); stop("Expected a valid difference test: ", name) }
  result$tests[[name]]$value
}
expect_error <- function(expr) assert(inherits(try(force(expr), silent = TRUE), "try-error"), "Expected rejection")
# A lavaan.vector's presentation attributes must not change the numerical
# df check. Real fits below also exercise this guard end-to-end.
classed_df <- function(x) structure(stats::setNames(x, "df"), class = c("lavaan.vector", "numeric"))
assert(advancedRestrictionDfMatches(classed_df(1), classed_df(2), 1L), "Classed df false rejection")
assert(!advancedRestrictionDfMatches(classed_df(1), classed_df(3), 1L), "Mismatched df accepted")
assert(!advancedRestrictionDfMatches(classed_df(2), classed_df(1), 1L), "Reversed df accepted")
assert(!advancedRestrictionDfMatches(1, 1, 0L), "Zero restrictions accepted")
assert(!advancedRestrictionDfMatches(NA_real_, 2, 1L), "Unavailable df accepted")
assert(!advancedRestrictionDfMatches(c(1, 2), 3, 1L), "Non-scalar df accepted")
cat("PASS: numeric df compatibility and guard retention\n")
set.seed(2026)
d <- data.frame(x = rnorm(800), z = rnorm(800), g = rep(c("G1", "G2"), each = 400))
d$m <- .4*d$x + .5*d$z + rnorm(nrow(d))
d$y <- .6*d$m + ifelse(d$g == "G1", .25, .55)*d$x + rnorm(nrow(d))
A <- "m ~ x + z\ny ~ m + x"
B <- "m ~ x + z\ny ~ m"
a <- snap(A, d); b <- snap(B, d)
res <- advancedCompare(a, b, d, TRUE)
print(res$summary)
tab <- check_test(res)
assert(abs(tab[2L, "Df diff"] - 1) < 1e-8, "Expected a one-df difference")
assert(abs(tab[2L, "Chisq diff"] - diff(res$summary$chisq)) < 1e-6, "Ordinary LRT mismatch")
assert("y ~ x" %in% res$restrictions, "Expected y ~ x restriction")
# Native LRT comparison, including the classed scalar returned by lavaan.
assert(advancedRestrictionDfMatches(lavaan::fitMeasures(res$fits$A$value, "df"),
  lavaan::fitMeasures(res$fits$B$value, "df"), length(res$restrictions)), "Native df guard mismatch")
ref_ml <- lavaan::lavTestLRT(res$fits$A$value, res$fits$B$value)
assert(abs(tab[2L, "Chisq diff"] - ref_ml[2L, "Chisq diff"]) < 1e-7, "Native ML LRT mismatch")
assert(is.null(advancedCompare(a, b, d, FALSE)$tests[[1L]]$value), "LRT displayed without nesting confirmation")
assert(is.null(advancedCompare(b, a, d, TRUE)$tests[[1L]]$value), "Reversed models were not rejected")
assert(is.null(advancedCompare(a, a, d, TRUE)$tests[[1L]]$value), "Identical models should not be tested")
non_nested <- snap("m ~ x + z\ny ~ m + z", d)
assert(is.null(advancedCompare(a, non_nested, d, TRUE)$tests[[1L]]$value), "Non-nested model was not rejected")
d_changed <- d; d_changed$x[1] <- d_changed$x[1] + 1
expect_error(advancedCompare(a, b, d_changed, TRUE))
changed_opts <- opts; changed_opts$estimator <- "MLR"
expect_error(advancedCompare(a, snap(B, d, changed_opts), d, TRUE))
robust <- advancedCompare(snap(A, d, changed_opts), snap(B, d, changed_opts), d, TRUE)
robust_tab <- check_test(robust)
assert(is.finite(robust_tab[2L, "Pr(>Chisq)"]), "Robust LRT missing")
assert(is.finite(robust$summary$chisq.scaled[1]), "Robust fit indices missing")
ref_mlr <- lavaan::lavTestLRT(robust$fits$A$value, robust$fits$B$value)
assert(abs(robust_tab[2L, "Chisq diff"] - ref_mlr[2L, "Chisq diff"]) < 1e-7, "Native MLR LRT mismatch")
ordinal <- opts; ordinal$ordered <- "y"; ordinal$estimator <- "ML"
expect_error(advancedCompare(snap(A, d, ordinal), snap(B, d, ordinal), d, TRUE))
cat("PASS: nested-model comparisons, MLR and refusal cases\n")

hs <- as.data.frame(lavaan::HolzingerSwineford1939)
HS <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
# Regression test for GUI syntax reported by the user (Grant-White, sex).
# lavaanify(auto = FALSE) adds unspecified variances fixed at zero;
# they must not be mistaken for explicitly fixed parameters.
gw <- hs[as.character(hs$school) == "Grant-White", , drop = FALSE]
GW <- "f1 =~ x1 + x2 + x3\nf2 =~ x4 + x5 + x6\nf2 ~~ f1\nf2 ~~ f2"
gw_opts <- opts
gw_opts$estimator <- "default"
gw_opts$meanstructure <- "default"
gw_opts$int.ov.free <- FALSE
gw_opts$auto.cov.y <- TRUE
gw_spec <- snap(GW, gw, gw_opts)
for (syntax in c(GW, HS, paste(GW, "f1 ~~ f1", sep = "\n"),
                 sub("x2", "start(0.5)*x2", GW, fixed = TRUE))) {
  p <- advancedGroupPlan(snap(syntax, gw, gw_opts), gw, "sex", "invariance", TRUE)
  assert(length(p$args) == 4L, "Expected four invariance specifications")
  assert(identical(p$args$Configural$model, syntax), "Original syntax changed")
  assert(sum(p$counts) == 145L, "Unexpected Grant-White group count")
}
expect_error(advancedGroupPlan(snap(paste(GW, "f1 ~~ 1*f1", sep = "\n"), gw, gw_opts), gw, "sex"))
expect_error(advancedGroupPlan(snap(sub("f2 ~~ f2", "f2 ~~ 0*f2", GW, fixed = TRUE), gw, gw_opts), gw, "sex"))
expect_error(advancedGroupPlan(snap(sub("x1", "NA*x1", GW, fixed = TRUE), gw, gw_opts), gw, "sex"))
expect_error(advancedGroupPlan(snap(sub("x2", "1*x2", GW, fixed = TRUE), gw, gw_opts), gw, "sex"))
cat("PASS: GUI syntax, automatic variances, explicit fixed restrictions and marker scaling\n")

h <- snap(HS, hs)
assert("school" %in% advancedGroupCandidates(hs, h), "School group unavailable")
mg <- advancedMultigroup(h, hs, "school", "invariance", TRUE)
print(mg$summary); print(mg$used)
assert(all(vapply(mg$fits, advancedUsable, logical(1))), "Some CFA fits failed")
assert(isTRUE(all.equal(as.numeric(mg$summary$df), c(48, 54, 60, 69))), "Unexpected invariance degrees of freedom")
# Official lavaan tutorial, ML, complete data. Rounded reference values.
assert(max(abs(mg$summary$chisq[1:3] - c(115.85, 124.04, 164.10))) < .03, "Invariance reference chi-square mismatch")
for (nm in names(mg$tests)) check_test(mg, nm)
assert(setequal(as.character(mg$labels), c("Pasteur", "Grant-White")), "Wrong group labels")
assert(sum(mg$used$N_used[mg$used$Model == "Configural"]) == 301L, "Wrong group sample size")
assert(all(c("Group", "est", "ci.lower", "ci.upper") %in% names(advancedParameters(mg$fits$Configural))), "Missing raw parameter fields")
assert(all(c("Group", "est.std", "ci.lower", "ci.upper") %in% names(advancedParameters(mg$fits$Configural, TRUE))), "Missing standardized parameter fields")
assert(length(parse(text = advancedScript(mg))) > 0L, "Exported script cannot be parsed")
assert(length(parse(text = advancedScript(res))) > 0L, "Exported comparison script cannot be parsed")
# Existing single labels would silently constrain parameters across groups.
expect_error(advancedGroupPlan(snap(sub("x2", "a*x2", HS, fixed = TRUE), hs), hs, "school"))
expect_error(advancedGroupPlan(h, hs, "x1"))
cat("PASS: Holzinger invariance and parameter exports\n")

rg <- advancedMultigroup(a, d, "g", "regressions")
print(rg$summary); print(rg$used); check_test(rg)
assert(rg$summary$df[2] > rg$summary$df[1], "Regression equality did not constrain model")
d_na <- d; d_na$g[1:2] <- NA; d_na$g[3] <- ""
plan <- advancedGroupPlan(snap(A, d_na), d_na, "g", "regressions")
assert(plan$dropped == 3L, "Missing group values not correctly excluded")
cat("PASS: multiple-group structural regression and group exclusions\n")

# Partial measurement invariance, documented native lavaan example.
choice <- advancedGroupChoices(h)
assert(setequal(choice$loadings, c("visual=~x2", "visual=~x3", "textual=~x5", "textual=~x6", "speed=~x8", "speed=~x9")), "Incorrect selectable loadings")
assert(setequal(choice$intercepts, paste0("x", 1:9, "~1")), "Incorrect selectable intercepts")
partial <- advancedMultigroup(h, hs, "school", "invariance", TRUE,
                              release_loadings = "visual=~x2", release_intercepts = "x7~1")
print(partial$summary)
assert(identical(names(partial$fits), c("Configural", "Partial metric", "Partial scalar", "Partial strict")), "Unexpected partial-invariance stages")
assert(all(vapply(partial$fits, advancedUsable, logical(1))), "Partial invariance fit failed")
assert(isTRUE(all.equal(as.numeric(partial$summary$df), c(48, 53, 58, 67))), "Partial invariance df mismatch")
for (nm in names(partial$tests)) check_test(partial, nm)
assert(identical(partial$partials[[2L]], "visual=~x2"), "Metric release missing")
assert(setequal(partial$partials[[3L]], c("visual=~x2", "x7~1")), "Scalar releases missing")
assert(setequal(partial$partials[[4L]], partial$partials[[3L]]), "Strict model lost prior releases")
ref <- lavaan::cfa(HS, data = hs, group = "school", group.label = partial$labels,
                   group.equal = c("loadings", "intercepts"), group.partial = c("visual=~x2", "x7~1"),
                   estimator = "ML", meanstructure = TRUE, auto.cov.y = FALSE)
assert(abs(unname(lavaan::fitMeasures(ref, "chisq")) - partial$summary$chisq[3L]) < 1e-5, "Native partial-invariance comparison mismatch")
assert(identical(advancedGroupPlan(h, hs, "school", release_intercepts = "x7~1")$partials[[2L]], character()), "Intercept release applied too early")
expect_error(advancedGroupPlan(h, hs, "school", release_loadings = "visual=~x1"))
expect_error(advancedGroupPlan(h, hs, "school", release_loadings = c("visual=~x2", "visual=~x3")))
expect_error(advancedGroupPlan(h, hs, "school", release_loadings = "visual=~x2", release_intercepts = "x3~1"))
expect_error(advancedGroupPlan(h, hs, "school", release_intercepts = "not_an_indicator~1"))
expect_error(advancedGroupPlan(snap(paste(HS, "visual =~ x9", sep = "\n"), hs), hs, "school", release_loadings = "visual=~x2"))
cat("PASS: partial invariance, native comparison and identification safeguards\n")

# Targeted regression constraints (all other slopes remain free across groups).
assert(setequal(advancedGroupChoices(a)$regressions, c("m~x", "m~z", "y~m", "y~x")), "Incorrect selectable regressions")
assert(!"m~z" %in% advancedGroupChoices(snap("m ~ x + 0*z\ny ~ m + x", d))$regressions, "Fixed regression offered for selection")
sel <- advancedMultigroup(a, d, "g", "regressions", selected_regressions = "y~x")
print(sel$summary)
sel_test <- check_test(sel)
assert(sel_test[2L, "Df diff"] == 1, "Targeted test must impose one equality for two groups")
assert(setequal(sel$partials[[2L]], c("m~x", "m~z", "y~m")), "Unselected regressions were not released")
ref_reg <- lavaan::sem(A, data = d, group = "g", group.label = sel$labels,
                       group.equal = "regressions", group.partial = c("m~x", "m~z", "y~m"),
                       meanstructure = TRUE, auto.cov.y = FALSE, fixed.x = TRUE, estimator = "ML")
assert(abs(unname(lavaan::fitMeasures(ref_reg, "chisq")) - sel$summary$chisq[2L]) < 1e-5, "Native selective regression comparison mismatch")
sel2 <- advancedMultigroup(a, d, "g", "regressions", selected_regressions = c("y~x", "m~x"))
assert(check_test(sel2)[2L, "Df diff"] == 2, "Joint selected test must impose two equalities")
sel_robust <- advancedMultigroup(snap(A, d, changed_opts), d, "g", "regressions", selected_regressions = "y~x")
assert(check_test(sel_robust)[2L, "Df diff"] == 1, "Robust targeted difference test mismatch")
expect_error(advancedGroupPlan(a, d, "g", "regressions", selected_regressions = character()))
expect_error(advancedGroupPlan(a, d, "g", "regressions", selected_regressions = "m~unknown"))
expect_error(advancedGroupPlan(h, hs, "school", selected_regressions = "y~x"))
for (obj in list(partial, sel)) {
  env <- new.env(parent = globalenv())
  env$data <- if (identical(obj$mode, "invariance")) hs else d
  invisible(utils::capture.output(eval(parse(text = advancedScript(obj)), envir = env)))
  replay_chisq <- vapply(env$fits, function(f) unname(lavaan::fitMeasures(f, "chisq")), numeric(1))
  assert(max(abs(replay_chisq - obj$summary$chisq)) < 1e-5, "Partial or targeted analysis script replay mismatch")
}
cat("PASS: selected regression tests, robust comparison, and replay\n")

# Replay exported script on the exact data, without changing the global data object.
replay <- new.env(parent = globalenv()); replay$data <- d
invisible(utils::capture.output(eval(parse(text = advancedScript(res)), envir = replay)))
assert(abs(lavaan::fitMeasures(replay$fits$A, "chisq") - res$summary$chisq[1]) < 1e-6, "Exported analysis not reproducible")
cat("PASS: replay of exported R script\n")

extra <- commandArgs(trailingOnly = TRUE)
if (length(extra)) {
  path <- file.path(extra[1], "donnees", "etudiants.csv")
  stu <- read.csv(path, check.names = FALSE)
  m0 <- "Motivation ~ SSE + Soutien\nEffort ~ Motivation\nReussite ~ Effort"
  m1 <- paste(m0, "Reussite ~ SSE", sep = "\n")
  stud <- advancedCompare(snap(m1, stu), snap(m0, stu), stu, TRUE)
  print(stud$summary); stu_tab <- check_test(stud)
  assert(abs(stu_tab[2L, "Chisq diff"] - 22.17727) < .01, "Manual student model delta chi-square mismatch")
  syd <- read.csv(file.path(extra[1], "donnees", "syndicat.csv"), check.names = FALSE)
  s0 <- "Deference ~ Age\nSupport ~ Deference + Age\nSentiment ~ Deference + Support + Years"
  s1 <- sub("Deference + Support + Years", "Support + Years", s0, fixed = TRUE)
  sy <- advancedCompare(snap(s0, syd), snap(s1, syd), syd, TRUE)
  print(sy$summary); sy_tab <- check_test(sy)
  assert(abs(sy_tab[2L, "Chisq diff"] - 5.02053) < .01, "Manual union model delta chi-square mismatch")
  cat("PASS: examples from the revised manual\n")
}
cat("All requested advanced-analysis tests completed.\n")
