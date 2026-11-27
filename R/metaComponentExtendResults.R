extendResultsUI <- function(id) {
  ns <- NS(id)
  tabsetPanel(
    parameterEstimatesUI(ns("paraEsts")),
    factorScoresUI(ns("factorScores")),
    modificationUI(ns("mod")),
    residualsUI(ns("residuals")),
    exactTestUI(ns("exact")),
    waldTestUI(ns("wald")),
    lavInspectUI(ns("inspect")),
    advancedComparisonUI(ns("compare")),
    advancedMultigroupUI(ns("multigroup"))
  )
}

# Define the overall module server
extendResultsServer <- function(id, fit, getData, analysisSpec) {
  moduleServer(id, function(input, output, session) {
    parameterEstimatesServer("paraEsts", fit)
    factorScoresServer("factorScores", fit)
    residualsServer("residuals", fit)
    lavInspectServer("inspect", fit)
    waldTestServer("wald", fit)
    modificationServer("mod", fit)
    exactTestServer("exact", fit)
    advancedComparisonServer("compare", getData, analysisSpec)
    advancedMultigroupServer("multigroup", getData, analysisSpec)
  })
}
