# Run all non-interactive statistical and UI-construction tests in fresh R
# processes. From package root: Rscript tests/manual/run_advanced_validation.R
# Logs are written to a new timestamped directory; no results are overwritten.
if (!file.exists("R/advancedAnalysisCore.R")) stop("Start from the package root.")
runner <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
tests <- c("advanced_analysis.R", "advanced_diagrams.R", "advanced_wlsmv_projects.R", "advanced_ordinal_views.R", "advanced_score_differences.R", "advanced_effects_reports.R")
base <- file.path(getwd(), paste0("advanced-validation-",format(Sys.time(),"%Y%m%d-%H%M%S")))
dir <- base; i <- 0L
while (dir.exists(dir)) { i <- i + 1L; dir <- paste0(base,"-",i) }
dir.create(dir)
status <- integer(length(tests)); names(status) <- tests
for (test in tests) {
  path <- file.path("tests","manual",test); log <- file.path(dir,sub("\\.R$",".log",test))
  cat("Running",test,"...\n")
  status[test] <- tryCatch(system2(runner, c("--vanilla", shQuote(path)), stdout=log, stderr=log),error=function(e) {writeLines(conditionMessage(e),log); 99L})
  cat(if(status[test] == 0L) "PASS" else paste("FAIL (exit",status[test],")"),"|",log,"\n")
}
utils::write.csv(data.frame(Test=tests,ExitCode=unname(status),Status=ifelse(status==0L,"PASS","FAIL")),file.path(dir,"summary.csv"),row.names=FALSE)
writeLines(utils::capture.output(sessionInfo()),file.path(dir,"session-info.txt"))
cat("Logs:",dir,"\n")
if (any(status != 0L)) quit(save="no", status=1L)
cat("All non-interactive R tests passed. Complete the live Shiny acceptance checklist separately.\n")
