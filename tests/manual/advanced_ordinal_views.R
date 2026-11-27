# Run from the package root. Requires the optional semTools package.
# Optional first argument: path to banc_lavaangui.csv from the existing test kit.
stopifnot(requireNamespace("lavaan", quietly=TRUE), requireNamespace("semTools", quietly=TRUE),
          requireNamespace("digest", quietly=TRUE), requireNamespace("jsonlite", quietly=TRUE),
          requireNamespace("shiny", quietly=TRUE), requireNamespace("DT", quietly=TRUE))
source("R/advancedAnalysisCore.R"); source("R/advancedGroupDiagram.R"); source("R/advancedEffectsReport.R"); source("R/componentAdvancedAnalysis.R")
assert <- function(ok, msg) if (!isTRUE(ok)) stop(msg, call. = FALSE)
expect_error <- function(expr) assert(inherits(try(force(expr), silent = TRUE), "try-error"), "Expected refusal")
argv <- commandArgs(trailingOnly=TRUE)
model <- "oF =~ o1 + o2 + o3\npF =~ p1 + p2 + p3\noF ~~ pF"
ordered <- c(paste0("o",1:3),paste0("p",1:3))
if (length(argv)) {
  d <- read.csv(argv[1L], check.names=FALSE)
} else {
  # Fully invariant population, with well populated categories. These data
  # differ from the existing comparison bank (which has residual dependence).
  set.seed(20261126); n <- 2400L
  z <- rnorm(n); w <- .35*z+sqrt(1-.35^2)*rnorm(n)
  ordinalize <- function(v) as.integer(cut(v,c(-Inf,-.7,0,.7,Inf),labels=FALSE))
  d <- data.frame(groupe=rep(c("A","B"),each=n/2))
  for (nm in ordered) d[[nm]] <- ordinalize(.75*(if (startsWith(nm,"o")) z else w)+.65*rnorm(n))
}
opts <- list(estimator="WLSMV", ordered=ordered, se="default", missing="listwise", meanstructure="default",
  int.ov.free=FALSE, int.lv.free=FALSE, auto.fix.first=TRUE, auto.fix.single=TRUE,
  auto.var=TRUE, auto.cov.lv.x=TRUE, auto.cov.y=FALSE, fixed.x=TRUE, auto.th=TRUE, auto.delta=TRUE)
snap <- function(model,data,options=opts) advancedSnapshot(list(syntax=model,optionsList=options),data)
s <- snap(model,d)
r <- advancedMultigroup(s,d,"groupe","ordinal",strict=TRUE)
print(r$summary); print(r$tests); print(advancedFitMessages(r$fits))
assert(identical(names(r$fits),c("Configural","Thresholds","Metric","Scalar","Strict")),"Wrong ordinal sequence")
assert(all(vapply(r$fits,advancedUsable,logical(1))),"One or more ordinal fits are unusable; inspect diagnostics")
assert(all(r$summary$df==c(16,22,26,30,36)),"Unexpected degrees of freedom for six four-category indicators")
assert(all(r$expected_steps==c(6,4,4,6)),"Incorrect theoretical df increments")
assert(all(vapply(r$fits,function(x) identical(lavaan::lavInspect(x$value,"options")$parameterization,"theta"),logical(1))),"Not theta")
assert(all(vapply(r$tests,function(x)!is.null(x$value),logical(1))),"A corrected sequential test was refused; examine the test diagnostics")
# Independent native call for every stage, using semTools' documented workflow.
for (i in seq_along(r$fits)) {
  eq <- r$sets[[i]]
  syntax <- semTools::measEq.syntax(configural.model=model, data=d, group="groupe", group.label=r$labels,
    ordered=ordered, estimator="WLSMV", missing="listwise", parameterization="theta", ID.fac="std.lv",
    ID.cat="Wu.Estabrook.2016",group.equal=if(length(eq)) eq else "",return.fit=FALSE)
  ref <- lavaan::cfa(as.character(syntax),data=d,group="groupe",group.label=r$labels,ordered=ordered,
    estimator="WLSMV",missing="listwise",parameterization="theta",meanstructure=TRUE)
  assert(abs(unname(lavaan::fitMeasures(ref,"chisq"))-r$summary$chisq[i])<1e-5,"Native stage chi-square mismatch")
  if(i>1L) {
    test <- lavaan::lavTestLRT(prev,ref,method="satorra.2000",a.method="delta",scaled.shifted=TRUE,test="scaled.shifted")
    assert(abs(test[2L,"Chisq diff"]-r$tests[[i-1L]]$value[2L,"Chisq diff"])<1e-5,"Native corrected difference mismatch")
  }
  prev <- ref
}
# Generated script must replay all models without semTools once syntax is saved.
e <- new.env(parent=globalenv()); e$data <- d
invisible(utils::capture.output(eval(parse(text=advancedScript(r)),envir=e)))
assert(max(abs(vapply(e$fits,function(f)unname(lavaan::fitMeasures(f,"chisq")),numeric(1))-r$summary$chisq))<1e-5,"Script replay mismatch")
# Scope guards, including 3 categories and groups with a missing category.
expect_error(advancedGroupPlan(s,d,"groupe","invariance"))
expect_error(advancedGroupPlan(snap(paste(model,"o2 ~~ p2",sep="\n"),d),d,"groupe","ordinal"))
expect_error(advancedGroupPlan(s,d,"groupe","ordinal",release_loadings="oF=~o2"))
bad <- d; bad$o1[bad$o1==4] <- 3L
expect_error(advancedGroupPlan(snap(model,bad),bad,"groupe","ordinal"))
bad <- d; bad$o1[bad$groupe=="B" & bad$o1==4] <- 3L
expect_error(advancedGroupPlan(snap(model,bad),bad,"groupe","ordinal"))
bad <- opts; bad$ordered <- ordered[-1L]
expect_error(advancedGroupPlan(snap(model,d,bad),d,"groupe","ordinal"))
cat("PASS: ordinal stages, native corrected tests, reproducible script and scope guards\n")
# Actual fitted labels and a synthetic last-view recipe.
payload <- advancedGroupDiagramData(r$fits$Scalar,"Scalar","groupe")
view <- list(stage="Scalar",group=as.character(r$labels[2L]),other=as.character(r$labels[1L]),
  mode="compare",scale="std",kind="measurement",digits=2L,zoom=125L,
  covariances=TRUE,variances=FALSE,wide=TRUE,
  positions=lapply(seq_len(nrow(payload$nodes)),function(i) list(label=payload$nodes$label[i],x=180+10*i,y=150+20*i)))
f <- tempfile(fileext=".json"); advancedWriteGroupProject(r,f,view)
restored <- advancedReadGroupProject(f,s,d)
assert(identical(restored$request,r$request),"Ordinal request not restored")
assert(isTRUE(all.equal(restored$diagram_view,view,check.attributes=FALSE)),"Layout recipe not restored")
raw <- jsonlite::fromJSON(f,simplifyVector=FALSE)
assert(raw$version==2,"Expected v2 companion file")
assert(!any(c("args","fits","data")%in%names(raw)),"Individual data or R objects included")
# A malformed layout is rejected and does not execute anything.
bad <- raw; bad$diagram_view$positions[[1L]]$x <- "<script>"
jsonlite::write_json(bad,f,auto_unbox=TRUE,null="null"); expect_error(advancedReadGroupProject(f,s,d))
bad <- raw; bad$diagram_view$group <- "unknown"
jsonlite::write_json(bad,f,auto_unbox=TRUE,null="null"); expect_error(advancedReadGroupProject(f,s,d))
# Backwards compatibility: simulate old v1 file schema with a continuous request.
hs <- as.data.frame(lavaan::HolzingerSwineford1939)
co <- opts; co$ordered <- NULL; co$estimator <- "ML"
h <- snap("visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9",hs,co)
mg <- advancedMultigroup(h,hs,"school")
advancedWriteGroupProject(mg,f)
v1 <- jsonlite::fromJSON(f,simplifyVector=FALSE); v1$version <- 1L
v1$diagram_view <- NULL; v1$semTools_version <- NULL
jsonlite::write_json(v1,f,auto_unbox=TRUE,null="null"); old <- advancedReadGroupProject(f,h,hs)
assert(identical(old$request,mg$request)&&is.null(old$diagram_view),"Legacy v1 restore failed")
unlink(f)
html <- as.character(advancedMultigroupUI("test"))
for(id in c("test-ordinalStrict","test-viewSaveStatus","Ordinal measurement invariance (WLSMV)"))
  assert(grepl(id,html,fixed=TRUE),paste("UI element missing:",id))
cat("PASS: saved view round trip, validation guards, backward compatibility and UI construction\n")
