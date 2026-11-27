# From package root: Rscript tests/manual/advanced_diagrams.R
# Tests live extraction from lavaan and Shiny bindings, without opening a browser.
stopifnot(requireNamespace("lavaan", quietly = TRUE), requireNamespace("digest", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE), requireNamespace("shiny", quietly = TRUE))
for (file in c("R/advancedAnalysisCore.R", "R/advancedGroupDiagram.R", "R/componentAdvancedAnalysis.R")) parse(file = file)
source("R/advancedAnalysisCore.R")
source("R/advancedGroupDiagram.R")
source("R/advancedEffectsReport.R"); source("R/componentAdvancedAnalysis.R")
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = FALSE,
  int.ov.free = TRUE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
snap <- function(model, d) advancedSnapshot(list(syntax = model, optionsList = opts), d)
assert <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)
check <- function(res) {
  n_checked <- 0L
  for (stage in names(res$fits)) {
    out <- res$fits[[stage]]
    if (!advancedUsable(out)) next
    p <- advancedGroupDiagramData(out, stage, res$group)
    f <- out$value
    assert(identical(p$groups$label, as.character(lavaan::lavInspect(f, "group.label"))), "Group labels mismatch")
    assert(identical(p$groups$n, as.numeric(unlist(lavaan::lavInspect(f, "nobs")))), "Group N mismatch")
    assert(setequal(p$nodes$label, unique(c(lavaan::lavNames(f, "lv"), lavaan::lavNames(f, "ov")))), "Node names mismatch")
    direct <- lavaan::parameterEstimates(f, standardized = TRUE)
    for (i in seq_len(nrow(p$rows))) {
      r <- p$rows[i, ]; a <- p$nodes$label[r$from]; b <- p$nodes$label[r$to]
      if (r$op == "~") { tmp <- a; a <- b; b <- tmp }
      same <- direct$lhs == a & direct$rhs == b
      if (r$op == "~~") same <- same | (direct$lhs == b & direct$rhs == a)
      j <- which(direct$group == r$group & direct$op == r$op & same)
      assert(length(j) == 1L, "Parameter mapping not unique")
      assert(isTRUE(all.equal(r$raw, direct$est[j], tolerance = 1e-8)), "Incorrect raw coefficient")
      assert(isTRUE(all.equal(r$std, direct$std.all[j], tolerance = 1e-7)), "Incorrect standardized coefficient")
      n_checked <- n_checked + 1L
    }
    # Every estimated directed relation in the selected fit is present.
    for (j in which(direct$group > 0L & direct$op %in% c("=~", "~"))) {
      lhs <- direct$lhs[j]; rhs <- direct$rhs[j]; op <- direct$op[j]
      src <- if (op == "~") rhs else lhs; dst <- if (op == "~") lhs else rhs
      if (isTRUE(direct$est[j] == 0)) next
      assert(any(p$rows$op == op & p$rows$group == direct$group[j] & p$rows$from == match(src, p$nodes$label) & p$rows$to == match(dst, p$nodes$label)), "Missing directed relation")
    }
    html <- as.character(advancedDiagramUI(p))
    assert(grepl("data-payload", html, fixed = TRUE), "Missing payload")
    cat("PASS:", stage, "groups", paste(p$groups$label, collapse = ", "), "rows", nrow(p$rows), "\n")
  }
  assert(n_checked > 0L, "No usable fitted model in this fixture")
  n_checked
}
hs <- as.data.frame(lavaan::HolzingerSwineford1939)
model <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
mg <- advancedMultigroup(snap(model, hs), hs, "school", "invariance", TRUE,
  release_loadings = "visual=~x2", release_intercepts = "x7~1")
stopifnot(all(vapply(mg$fits, advancedUsable, logical(1))))
n <- check(mg)
gw <- hs[as.character(hs$school) == "Grant-White", , drop = FALSE]
gw_model <- "f1 =~ x1 + x2 + x3\nf2 =~ x4 + x5 + x6\nf2 ~~ f1\nf2 ~~ f2"
gw_result <- advancedMultigroup(snap(gw_model, gw), gw, "sex")
assert(advancedUsable(gw_result$fits[[1L]]), "Grant-White configural fit failed")
n <- n + check(gw_result)
set.seed(2026)
d <- data.frame(x = rnorm(800), z = rnorm(800), g = rep(c("G1", "G2"), each = 400))
d$m <- .4*d$x + .5*d$z + rnorm(nrow(d))
d$y <- .6*d$m + ifelse(d$g == "G1", .25, .55)*d$x + rnorm(nrow(d))
path <- "m ~ x + z\ny ~ m + x"
rg <- advancedMultigroup(snap(path, d), d, "g", "regressions", selected_regressions = "y~x")
stopifnot(all(vapply(rg$fits, advancedUsable, logical(1))))
n <- n + check(rg)
assert(inherits(try(advancedGroupDiagramData(list(error = "failed", value = NULL), "Failed", "g"), silent = TRUE), "try-error"), "Unusable fit not rejected")
# A quoted/malicious-looking label must remain an escaped attribute, never HTML.
fake <- list(model = "<script>", grouping = "g", nodes = data.frame(id=1, label="x<y", latent=FALSE),
 groups = data.frame(id=1:2, label=c('"A"', 'B<script>'), n=1:2), rows = data.frame())
assert(!grepl("<script>", as.character(advancedDiagramUI(fake)), fixed=TRUE), "HTML injection in diagram payload")
cat("PASS:", n, "parameter-to-edge matches checked across actual fitted models.\n")
