# Run from the package root: Rscript tests/manual/advanced_wlsmv_projects.R
# No GUI required. Separate from the previously validated ML/MLR tests.
stopifnot(requireNamespace("lavaan", quietly = TRUE), requireNamespace("digest", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE), requireNamespace("shiny", quietly = TRUE))
for (file in c("R/advancedAnalysisCore.R", "R/componentAdvancedAnalysis.R", "R/advancedGroupDiagram.R")) parse(file = file)
source("R/advancedAnalysisCore.R")
source("R/advancedGroupDiagram.R")
source("R/advancedEffectsReport.R"); source("R/componentAdvancedAnalysis.R")
assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
expect_error <- function(expr) assert(inherits(try(force(expr), silent = TRUE), "try-error"), "Expected rejection")
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = "default",
  int.ov.free = FALSE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
snap <- function(model, data, options = opts) advancedSnapshot(list(syntax = model, optionsList = options), data)

# An ordinal CFA with one cross-factor residual covariance. All indicators
# have four well-populated categories and both models have identical scales.
set.seed(20261126)
n <- 2400L
f1 <- rnorm(n); f2 <- .35*f1 + sqrt(1-.35^2)*rnorm(n); method <- rnorm(n)
ordinalize <- function(x) as.integer(cut(x, breaks = c(-Inf, -.7, 0, .7, Inf), labels = FALSE))
d <- data.frame(x1 = ordinalize(.8*f1 + .6*rnorm(n)),
  x2 = ordinalize(.7*f1 + .35*method + .65*rnorm(n)), x3 = ordinalize(.75*f1 + .65*rnorm(n)),
  y1 = ordinalize(.8*f2 + .6*rnorm(n)), y2 = ordinalize(.7*f2 + .35*method + .65*rnorm(n)),
  y3 = ordinalize(.75*f2 + .65*rnorm(n)), g = rep(c("A", "B"), each = n/2))
B <- "f1 =~ x1 + x2 + x3\nf2 =~ y1 + y2 + y3"
A <- paste(B, "x2 ~~ y2", sep = "\n")
o <- opts; o$estimator <- "WLSMV"; o$ordered <- names(d)[1:6]
a <- snap(A, d, o); b <- snap(B, d, o)
r <- advancedCompare(a, b, d, confirmed = TRUE)
print(r$summary); print(r$tests); print(advancedFitMessages(r$fits))
assert(all(vapply(r$fits, advancedUsable, logical(1))), "WLSMV fits not usable")
assert(!is.null(r$tests[[1]]$value), "Expected WLSMV difference test")
tab <- r$tests[[1]]$value
assert(tab[2L,"Df diff"] == 1, "Expected one restriction")
assert("x2 ~~ y2" %in% r$restrictions, "Wrong detected restriction")
ref <- lavaan::lavTestLRT(r$fits$A$value, r$fits$B$value, method = "satorra.2000",
  a.method = "delta", scaled.shifted = TRUE, test = "scaled.shifted")
assert(abs(tab[2L,"Chisq diff"] - ref[2L,"Chisq diff"]) < 1e-7, "Native WLSMV difference test mismatch")
assert(abs(tab[2L,"Pr(>Chisq)"] - ref[2L,"Pr(>Chisq)"]) < 1e-7, "Native WLSMV p-value mismatch")
assert(all(is.na(r$summary$aic)) && all(is.na(r$summary$bic)), "Likelihood criteria must be unavailable")
assert(all(is.finite(r$summary$chisq.scaled)), "Missing corrected chi-square")
assert(is.null(advancedCompare(b, a, d, TRUE)$tests[[1]]$value), "Reverse comparison was accepted")
assert(is.null(advancedCompare(a, b, d, FALSE)$tests[[1]]$value), "Comparison without confirmation")
bad <- o; bad$missing <- "fiml"; expect_error(advancedCompare(snap(A,d,bad),snap(B,d,bad),d,TRUE))
bad <- o; bad$ordered <- o$ordered[-1]; expect_error(advancedCompare(a,snap(B,d,bad),d,TRUE))
expect_error(advancedGroupPlan(a,d,"g")) # continuous mode must still reject an ordinal model
script <- advancedScript(r)
assert(any(grepl("satorra.2000", script, fixed = TRUE)), "Script lost the correction")
env <- new.env(parent=globalenv()); env$data <- d
invisible(utils::capture.output(eval(parse(text=script),envir=env)))
assert(max(abs(vapply(env$fits, function(f) unname(lavaan::fitMeasures(f,"chisq")), numeric(1)) - r$summary$chisq)) < 1e-5, "WLSMV replay mismatch")
cat("PASS: ordinal WLSMV fit, corrected test, refusals, and script replay\n")

# Save and restore a partial invariance analysis without embedding the data.
hs <- as.data.frame(lavaan::HolzingerSwineford1939)
HS <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
h <- snap(HS, hs)
mg <- advancedMultigroup(h, hs, "school", "invariance", TRUE,
  release_loadings = "visual=~x2", release_intercepts = "x7~1")
file <- tempfile(fileext=".json"); advancedWriteGroupProject(mg,file)
raw <- jsonlite::fromJSON(file, simplifyVector=FALSE)
assert(!any(c("data", "fits", "args", "syntax") %in% names(raw)), "Raw observations, fitted objects or model code in project")
restored <- advancedReadGroupProject(file,h,hs)
assert(identical(restored$request, mg$request), "Partial settings did not round-trip")
assert(identical(restored$labels,mg$labels), "Group order lost")
plan <- do.call(advancedGroupPlan,c(list(spec=h,data=hs),restored$request))
assert(identical(plan$sets,mg$sets) && identical(plan$partials,mg$partials), "Restored plan differs")
rerun <- do.call(advancedMultigroup,c(list(spec=h,data=hs),restored$request))
assert(isTRUE(all.equal(rerun$summary$chisq,mg$summary$chisq,tolerance=1e-7)), "Restored estimates differ")
changed <- hs; changed$x1[1] <- changed$x1[1]+.01
expect_error(advancedReadGroupProject(file,snap(HS,changed),changed))
expect_error(advancedReadGroupProject(file,snap(paste(HS,"x1 ~~ x4",sep="\n"),hs),hs))
changed_opts <- opts; changed_opts$estimator <- "MLR"
expect_error(advancedReadGroupProject(file,snap(HS,hs,changed_opts),hs))
raw$request$release_loadings <- "malicious_unknown_parameter"; bad <- tempfile(fileext=".json")
jsonlite::write_json(raw,bad,auto_unbox=TRUE,null="null"); expect_error(advancedReadGroupProject(bad,h,hs))
raw$version <- 99; jsonlite::write_json(raw,bad,auto_unbox=TRUE,null="null"); expect_error(advancedReadGroupProject(bad,h,hs))
writeLines("not JSON",bad); expect_error(advancedReadGroupProject(bad,h,hs))
# Single targeted coefficient and all-regressions (NULL) survive JSON roundtrip.
set.seed(2026); p <- data.frame(x=rnorm(800), z=rnorm(800), g=rep(c("1","2"),each=400))
p$m <- .4*p$x+.5*p$z+rnorm(nrow(p)); p$y <- .6*p$m+.35*p$x+rnorm(nrow(p))
ps <- snap("m ~ x + z\ny ~ m + x",p)
for (selected in list(NULL,"y~x",c("y~x","m~z"))) {
  rr <- advancedMultigroup(ps,p,"g","regressions",selected_regressions=selected)
  advancedWriteGroupProject(rr,file)
  restore <- advancedReadGroupProject(file,ps,p)
  assert(identical(restore$request,rr$request), "Selected regressions did not round-trip")
}
unlink(c(file,bad))
cat("PASS: saved settings, replay, data/model/version guards, invalid files, targeted regressions\n")
html <- as.character(advancedMultigroupUI("test"))
for (id in c("test-partialEnabled", "test-releaseLoadings", "test-releaseIntercepts", "test-projectFile", "test-saveProjectControl", "test-applyProjectControl"))
  assert(grepl(id,html,fixed=TRUE),paste("Missing UI element",id))
cat("PASS: Shiny UI construction and explicit partial-invariance checkbox\n")
cat("All requested WLSMV and project tests completed.\n")
