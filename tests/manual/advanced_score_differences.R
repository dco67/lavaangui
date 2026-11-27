# Run from the package root. Optional: path to banc_lavaangui.csv.
# Requires lavaan, digest, jsonlite, shiny, DT (existing dependencies).
source("R/advancedAnalysisCore.R")
source("R/advancedGroupDiagram.R")
source("R/advancedEffectsReport.R"); source("R/componentAdvancedAnalysis.R")
assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
expect_error <- function(expr) assert(inherits(try(force(expr), silent = TRUE), "try-error"), "Expected refusal")
# Scope compatibility for pre-0.7-3 and 0.7-3 ordinary ML. No robust or
# other unsupported diagnostic is admitted by this compatibility fix.
base_opts <- list(estimator = "ML", test = "standard", se = "standard", missing = "listwise")
assert(advancedScoreOrdinaryML(base_opts), "Legacy ordinary ML refused")
new_opts <- utils::modifyList(base_opts, list(test = c("standard", "browne.residual.nt.model")))
assert(advancedScoreOrdinaryML(new_opts), "lavaan 0.7-3 ordinary ML refused")
for (bad in list(list(test = c("standard", "yuan.bentler.mplus")),
                 list(test = c("standard", "scaled.shifted")), list(test = "none"),
                 list(test = "browne.residual.nt.model"), list(se = "robust.huber.white"),
                 list(estimator = "DWLS"), list(missing = "ml"))) {
  assert(!advancedScoreOrdinaryML(utils::modifyList(base_opts, bad)), "Unsupported score options accepted")
}
cat("PASS: legacy/current ordinary ML options and unsupported-mode refusals\n")
argv <- commandArgs(trailingOnly = TRUE)
if (length(argv)) {
  d <- read.csv(argv[1L], check.names = FALSE)
} else {
  set.seed(20261126); n <- 2400L
  d <- data.frame(groupe = rep(c("A", "B"), each = n/2))
  a <- rnorm(n); b <- .35*a + sqrt(1-.35^2)*rnorm(n); second <- d$groupe == "B"
  for (i in 1:4) {
    d[[paste0("x", i)]] <- (if (i == 3) ifelse(second, 1.15, .65) else .9) * a + .65*rnorm(n)
    d[[paste0("y", i)]] <- .9*b + (if (i == 3) .65*second else 0) +
      (if (i == 4) ifelse(second, .97, .63) else .63)*rnorm(n)
  }
}
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = FALSE,
  int.ov.free = TRUE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
model <- "f1 =~ x1 + x2 + x3 + x4\nf2 =~ y1 + y2 + y3 + y4\nf1 ~~ f2"
snap <- function(data, options = opts) advancedSnapshot(list(syntax = model, optionsList = options), data)
s <- snap(d)
r <- advancedMultigroup(s, d, "groupe", "invariance", strict = TRUE)
print(r$summary); print(advancedFitMessages(r$fits))
assert(all(vapply(r$fits, advancedUsable, logical(1))), "Unusable fitted model")
expect_error(advancedScoreCandidates(r$fits$Configural))
check_score <- function(out, parameter) {
  z <- advancedScoreDiagnostics(out)
  print(z$table)
  row <- z$table[z$table$Parameter == parameter, , drop = FALSE]
  assert(nrow(row) == 1L && row$Status == "OK", paste("Missing diagnostic for", parameter))
  native <- lavaan::lavTestScore(out$value, release = row$Constraint, univariate = TRUE, epc = TRUE, standardized = FALSE)
  assert(abs(row$X2 - native$uni$X2) < 1e-7 && abs(row$p - native$uni$p.value) < 1e-7, "Score differs from native one-constraint test")
  e <- z$epcs[[as.character(row$Constraint)]]
  print(e)
  assert(nrow(e) == 2L && max(abs(e$Expected - e$Estimate - e$EPC)) < 1e-7, "EPC values misaligned")
  assert(identical(e$Group, r$labels), "Incorrect group order")
  cnd <- advancedScoreCandidates(out)
  a <- cnd[cnd$Constraint == row$Constraint, , drop = FALSE]
  ep <- as.data.frame(native$epc)
  ep <- ep[ep$lhs == a$lhs & ep$op == a$op & ep$rhs == a$rhs & ep$group %in% 1:2, , drop = FALSE]
  ep <- ep[order(ep$group), , drop = FALSE]
  assert(max(abs(ep$epc-e$EPC)) < 1e-7 && max(abs(ep$epv-e$Expected)) < 1e-7, "EPC differs from native output")
  assert(row$p < .05, paste("Expected a detectable population difference for", parameter))
  assert(row$p_Holm >= row$p, "Invalid Holm p-value")
  invisible(z)
}
cat("Effective ML test options:", paste(lavaan::lavInspect(r$fits$Metric$value, "options")$test, collapse = ", "), "\n")
metric <- check_score(r$fits$Metric, "f1=~x3")
p <- advancedMultigroup(s, d, "groupe", "invariance", strict = TRUE, release_loadings = "f1=~x3")
scalar <- check_score(p$fits[["Partial scalar"]], "y3~1")
assert(!"f1=~x3" %in% scalar$table$Parameter, "Released loading still treated as equal")
q <- advancedMultigroup(s, d, "groupe", "invariance", strict = TRUE, release_loadings = "f1=~x3", release_intercepts = "y3~1")
strict <- check_score(q$fits[["Partial strict"]], "y4~~y4")
# An extra release could leave fewer than two anchors. It must not be proposed.
p2 <- advancedMultigroup(s, d, "groupe", "invariance", release_loadings = c("f1=~x2", "f1=~x3"))
anchor <- advancedScoreCandidates(p2$fits[["Partial metric"]])
assert(!any(anchor$Eligible[anchor$Parameter == "f1=~x4"]) && any(anchor$Parameter == "f1=~x4"), "Anchor guard missing")
bad <- r$fits$Metric; bad$warnings <- "simulated warning"; expect_error(advancedScoreCandidates(bad))
rob <- opts; rob$estimator <- "MLR"
r2 <- advancedMultigroup(snap(d, rob), d, "groupe", "invariance")
expect_error(advancedScoreCandidates(r2$fits$Metric))
# The difference display uses the same coefficient rows as the original SVG.
pl <- advancedGroupDiagramData(r$fits$Configural, "Configural", "groupe")
view <- list(stage = "Configural", group = r$labels[1L], other = r$labels[2L], mode = "difference",
  scale = "std", kind = "measurement", digits = 3L, zoom = 100L, covariances = TRUE, variances = FALSE,
  wide = FALSE, positions = lapply(seq_len(nrow(pl$nodes)), function(i) list(label = pl$nodes$label[i], x = 150+10*i, y = 160+20*i)))
f <- tempfile(fileext = ".json"); advancedWriteGroupProject(r, f, view)
restored <- advancedReadGroupProject(f, s, d)
assert(isTRUE(all.equal(restored$diagram_view, view, check.attributes = FALSE)), "Difference view did not round-trip")
unlink(f)
html <- as.character(advancedMultigroupUI("test"))
for (id in c("Constraint diagnostics", "test-scoreStage", "test-runScore", "test-scoreTable", "test-scoreEpc"))
  assert(grepl(id, html, fixed = TRUE), paste("Missing UI:", id))
cat("PASS: score diagnostics, single-release EPC, anchor and scope checks, difference JSON, and UI construction\n")
