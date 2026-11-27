# Run from the documented source project root.
# Rscript tools/check-advanced-documentation.R [--installed]
# --installed additionally checks that the installed package exposes the help
# topics and assets. It does not install packages or start a browser.
stopifnot(file.exists("DESCRIPTION"), dir.exists("man"))
topics <- c("lavaangui", "lavaangui-package", "plot_lavaan", "export_plot", "remove_layouts",
  "lavaangui-advanced", "lavaangui-model-comparison", "lavaangui-multiple-groups",
  "lavaangui-diagrams", "lavaangui-constraint-diagnostics", "lavaangui-group-effects",
  "lavaangui-analysis-export", "lavaangui-advanced-validation")
files <- file.path("man", paste0(topics, ".Rd"))
stopifnot(all(file.exists(files)))
for (p in files) {
  rd <- withCallingHandlers(tools::parse_Rd(p, encoding = "UTF-8"),
                            warning = function(w) stop(conditionMessage(w), call. = FALSE))
  stopifnot(inherits(rd, "Rd"))
  cat("PASS Rd parse:", p, "\n")
}
kit <- file.path("inst", "advanced-examples")
stopifnot(file.exists(file.path("inst", "doc", "advanced-analysis.html")),
          file.exists(file.path(kit, "reference-examples.R")),
          length(list.files(file.path(kit, "modeles"), pattern = "[.]lvm$")) == 8L)
invisible(parse(file.path(kit, "reference-examples.R")))
d <- utils::read.csv(file.path(kit, "banc_lavaangui.csv"), check.names = FALSE)
stopifnot(nrow(d) == 2400L, ncol(d) == 25L, !anyNA(d),
          identical(as.integer(table(d$groupe)), c(1200L, 1200L)))
cat("PASS reference script syntax and example files\n")
if ("--installed" %in% commandArgs(trailingOnly = TRUE)) {
  stopifnot(requireNamespace("lavaangui", quietly = TRUE))
  for (topic in topics) {
    h <- utils::help(topic, package = "lavaangui", try.all.packages = FALSE)
    if (!length(h)) stop("Installed help topic not found: ", topic)
    cat("PASS installed help:", topic, "\n")
  }
  installed <- c(system.file("doc", "advanced-analysis.html", package = "lavaangui"),
    system.file("advanced-examples", "reference-examples.R", package = "lavaangui"),
    system.file("advanced-examples", "banc_lavaangui.csv", package = "lavaangui"))
  stopifnot(all(nzchar(installed)), all(file.exists(installed)))
  cat("PASS installed guide and example assets\n")
}
cat("Documentation checks completed. This does not replace R CMD check or the six acceptance suites.\n")
