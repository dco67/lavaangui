# Standalone Shiny preview of the actual new modules (no package metadata needed).
# From the root: Rscript tests/manual/advanced_demo.R
source("R/advancedAnalysisCore.R")
source("R/functionsExtendedResults.R")
source("R/advancedGroupDiagram.R")
source("R/advancedEffectsReport.R"); source("R/componentAdvancedAnalysis.R")
stopifnot(requireNamespace("shiny", quietly = TRUE), requireNamespace("DT", quietly = TRUE),
          requireNamespace("lavaan", quietly = TRUE), requireNamespace("digest", quietly = TRUE))
opts <- list(estimator = "ML", se = "default", missing = "listwise", meanstructure = FALSE,
  int.ov.free = TRUE, int.lv.free = FALSE, auto.fix.first = TRUE, auto.fix.single = TRUE,
  auto.var = TRUE, auto.cov.lv.x = TRUE, auto.cov.y = FALSE, fixed.x = TRUE,
  auto.th = TRUE, auto.delta = TRUE)
set.seed(2026)
d <- data.frame(x = rnorm(800), z = rnorm(800), g = rep(c("G1", "G2"), each = 400))
d$m <- .4*d$x + .5*d$z + rnorm(nrow(d))
d$y <- .6*d$m + ifelse(d$g == "G1", .25, .55)*d$x + rnorm(nrow(d))
models <- list(A = "m ~ x + z\ny ~ m + x", B = "m ~ x + z\ny ~ m",
  HS = "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9")
ui <- shiny::fluidPage(shiny::titlePanel("lavaangui - Experimental modules preview"),
  shiny::helpText("Standalone preview with example data. Select a model to simulate a completed diagram estimate. The actual app automatically captures the completed diagram specification."),
  shiny::selectInput("example", "Example model", c("Path model A - less restricted" = "A", "Path model B - more restricted" = "B", "Holzinger CFA (school)" = "HS")),
  shiny::radioButtons("estimator", "Estimator", c("ML", "MLR"), inline = TRUE),
  shiny::tabsetPanel(advancedComparisonUI("comparison"), advancedMultigroupUI("groups")))
server <- function(input, output, session) {
  data <- shiny::reactive(if (identical(input$example, "HS")) as.data.frame(lavaan::HolzingerSwineford1939) else d)
  spec <- shiny::reactive({
    shiny::req(input$example, input$estimator)
    options <- opts; options$estimator <- input$estimator
    advancedSnapshot(list(syntax = models[[input$example]], optionsList = options), data())
  })
  advancedComparisonServer("comparison", data, spec)
  advancedMultigroupServer("groups", data, spec)
}
shiny::runApp(shiny::shinyApp(ui, server), launch.browser = TRUE)
