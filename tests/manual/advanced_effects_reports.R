# Run from package root. Optional: path to the supplied banc_lavaangui.csv.
source("R/advancedAnalysisCore.R")
source("R/advancedGroupDiagram.R")
source("R/advancedEffectsReport.R")
source("R/componentAdvancedAnalysis.R")
assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
expect_error <- function(expr) assert(inherits(try(force(expr), silent = TRUE), "try-error"), "Expected refusal")
near <- function(x,y,tol=1e-6) isTRUE(all.equal(as.numeric(x), as.numeric(y), tolerance=tol))
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) d <- read.csv(args[1L], check.names = FALSE) else {
  set.seed(20261126); n <- 2400L
  d <- data.frame(groupe = rep(c("A","B"), each = n/2), X = rnorm(n), Z = rnorm(n))
  g <- d$groupe == "B"
  d$M <- .4*d$X + (.25 + .5*g)*d$Z + rnorm(n)
  d$Y <- (.45 + .25*g)*d$M + .15*d$X + rnorm(n)
}
# A value not used by the model must not appear in a report.
d$PrivateUnused <- "PRIVATE_INDIVIDUAL_ROW_SENTINEL"
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = FALSE,
  int.ov.free = TRUE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
model <- "M ~ X + Z\nY ~ M + X"
snap <- function(m, o = opts, data = d) advancedSnapshot(list(syntax = m, optionsList = o), data)
labelled <- paste("M ~ c(aA,aB)*X + c(zA,zB)*Z",
  "Y ~ c(bA,bB)*M + c(cA,cB)*X",
  "indA := aA*bA", "indB := aB*bB", "indDiff := indB-indA",
  "directDiff := cB-cA", "totA := cA+indA", "totB := cB+indB", "totDiff := totB-totA",
  "zIndA := zA*bA", "zIndB := zB*bB", "zDiff := zIndB-zIndA", sep="\n")
compare_native <- function(z, native, effect, contrast, defined) {
  got <- z$table[z$table$Effect == effect & z$table$Contrast == contrast, , drop = FALSE]
  want <- native[native$op == ":=" & native$lhs == defined, , drop = FALSE]
  assert(nrow(got) == 1L && nrow(want) == 1L, paste("Missing result", effect, contrast, defined))
  assert(near(got$Estimate,want$est) && near(got$SE,want$se) && near(got$CI.lower,want$ci.lower) && near(got$CI.upper,want$ci.upper) && near(got$p,want$pvalue), paste("Mismatch with native lavaan definition", defined))
}
for (est in c("ML","MLR")) {
  o <- opts; o$estimator <- est
  r <- advancedMultigroup(snap(model,o), d, "groupe", "regressions")
  print(r$summary); print(advancedFitMessages(r$fits))
  out <- r$fits[["Free regressions"]]
  assert(advancedUsable(out), "No usable free model")
  a <- r$labels[1L]; b <- r$labels[2L]
  e <- advancedEffects(out,"X","Y",a,b)
  print(e$table)
  fargs <- r$args[["Free regressions"]]; fargs$model <- labelled
  native <- lavaan::parameterEstimates(do.call(lavaan::lavaan,fargs))
  compare_native(e,native,"Total indirect","First group","indA")
  compare_native(e,native,"Total indirect","Second group","indB")
  compare_native(e,native,"Total indirect","Second - first","indDiff")
  compare_native(e,native,"Direct","Second - first","directDiff")
  compare_native(e,native,"Total","First group","totA")
  compare_native(e,native,"Total","Second group","totB")
  compare_native(e,native,"Total","Second - first","totDiff")
  z <- advancedEffects(out,"Z","Y",a,b)
  compare_native(z,native,"Total","Second - first","zDiff")
  assert(all(z$table$Estimate[z$table$Effect == "Direct"] == 0) && all(is.na(z$table$p[z$table$Effect == "Direct"])), "Absent direct path is not a tested effect")
  rev <- advancedEffects(out,"X","Y",b,a)
  q <- e$table$Contrast == "Second - first"; qr <- rev$table$Contrast == "Second - first"
  assert(near(e$table$Estimate[q],-rev$table$Estimate[qr]) && near(e$table$SE[q],rev$table$SE[qr]),"Reversed group contrast")
  expect_error(advancedEffects(out,"Y","X",a,b)); expect_error(advancedEffects(out,"X","Y",a,a))
  expect_error(advancedEffectGraph(r$fits[["Equal regressions"]]))
  bad <- out; bad$warnings <- "simulated warning"; expect_error(advancedEffectGraph(bad))
  # Actual report serialization from this fitted result, not a browser mock.
  payload <- advancedGroupDiagramData(out, "Free regressions", "groupe")
  view <- list(stage = "Free regressions", group = a, other = b, mode = "difference", scale = "std", kind = "horizontal", digits = 4L, zoom = 85L, covariances = TRUE, variances = FALSE, wide = FALSE,
    positions = lapply(seq_len(nrow(payload$nodes)), function(i) list(label = payload$nodes$label[i], x = 150+100*i, y = 150+40*i)))
  path <- tempfile(fileext=".html"); r$note <- paste(r$note, "<script>INJECT_TEST</script>")
  advancedWriteReport(r,path,view,effects=e)
  h <- paste(readLines(path,warn=FALSE,encoding="UTF-8"),collapse="\n")
  for (part in c("Fit indices", "Comparisons and warnings", "Parameter estimates", "data-payload", "restoredView", "Total indirect", "Reproducible estimation script"))
    assert(grepl(part,h,fixed=TRUE),paste("Report content missing:",part))
  assert(!grepl("<script>INJECT_TEST</script>",h,fixed=TRUE) && !grepl("PRIVATE_INDIVIDUAL_ROW_SENTINEL",h,fixed=TRUE),"Report includes raw markup or unused individual data")
  unlink(path)
  m <- advancedCompare(snap(model,o),snap("M ~ X + Z\nY ~ M",o),d,confirmed=TRUE)
  path <- tempfile(fileext=".html"); advancedWriteReport(m,path); assert(file.info(path)$size > 1000,"Comparison HTML report missing"); unlink(path)
}
# Two indirect paths sharing an edge: total variance must include covariance.
set.seed(1234); n <- nrow(d); d$N <- .4*d$M + .2*d$X + rnorm(n)
d$Y2 <- .3*d$M + .5*d$N + .2*d$X + rnorm(n)
model2 <- "M ~ X + Z\nN ~ M + X\nY2 ~ M + N + X"
r2 <- advancedMultigroup(snap(model2,opts,d), d, "groupe", "regressions")
z <- advancedEffects(r2$fits[["Free regressions"]],"X","Y2",r2$labels[1L],r2$labels[2L])
assert(sum(grepl(" -> ",z$table$Effect)) == 9L,"Expected three indirect paths: X-M-Y2, X-N-Y2, X-M-N-Y2")
lab2 <- paste("M ~ c(a1,a2)*X + Z", "N ~ c(d1,d2)*M + c(e1,e2)*X", "Y2 ~ c(b1,b2)*M + c(f1,f2)*N + c(c1,c2)*X", "i1 := a1*b1+e1*f1+a1*d1*f1", "i2 := a2*b2+e2*f2+a2*d2*f2", "dif := i2-i1", sep="\n")
a2 <- r2$args[["Free regressions"]]; a2$model <- lab2
# Unlabelled Z regression stays group-specific; definition uses only X paths.
native2 <- lavaan::parameterEstimates(do.call(lavaan::lavaan,a2))
compare_native(z,native2,"Total indirect","Second - first","dif")
# Cycles are rejected by the path enumeration graph validation; test no-route guard as well.
assert(inherits(try(advancedEffectPaths(advancedEffectGraph(r2$fits[["Free regressions"]]),"Y2","X"),silent=TRUE),"try-error"),"Reverse route incorrectly accepted")
html <- as.character(advancedMultigroupUI("test"))
for (id in c("Advanced diagnostics", "Indirect &amp; total effects", "Export &amp; restore", "Save / restore", "HTML report", "test-runEffects", "test-effectTable", "test-reportControl"))
  assert(grepl(id,html,fixed=TRUE),paste("UI element missing:",id))
cat("PASS: native ML/MLR effects and contrasts, multiroute covariance, refusal checks, actual HTML generation and navigation\n")
