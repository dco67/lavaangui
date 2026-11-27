# Experimental Shiny modules for the existing More Results dialog.
# These modules never overwrite the main fit or the diagram.

# Scope typography to the two new modules; leave the existing GUI untouched.
advancedResultsStyle <- function() {
  shiny::tags$style(shiny::HTML("
    .lvg-advanced-results {font-size: 16px; line-height: 1.5; padding-top: 12px;}
    .lvg-advanced-results h4 {font-size: 21px; margin-top: 16px;}
    .lvg-advanced-results h5 {font-size: 17px;}
    .lvg-advanced-results .help-block,
    .lvg-advanced-results label,
    .lvg-advanced-results .form-control,
    .lvg-advanced-results .selectize-input,
    .lvg-advanced-results .selectize-input input,
    .lvg-advanced-results .selectize-dropdown,
    .lvg-advanced-results .btn,
    .lvg-advanced-results .nav-tabs > li > a,
    .lvg-advanced-results .dataTables_wrapper,
    .lvg-advanced-results table th,
    .lvg-advanced-results table td {font-size: 16px; line-height: 1.45;}
    .lvg-advanced-results .btn {white-space: normal; max-width: 100%;}
    .lvg-advanced-results .nav-tabs {display: flex; flex-wrap: wrap;}
    .lvg-advanced-results .nav-tabs > li {float: none;}
    .lvg-advanced-results pre {font-size: 15px; line-height: 1.5;
      white-space: pre; overflow-x: auto; max-width: 100%;}
    .lvg-advanced-results .lvg-advanced-spec pre {max-height: 220px; overflow-y: auto;}
    .lvg-advanced-results .lvg-advanced-table {max-width: 100%; overflow-x: auto;}
    .lvg-advanced-results .lvg-advanced-tab {padding: 10px 0 14px; min-width: 0;}
    .lvg-advanced-results .lvg-advanced-toolbar {margin: 10px 0 16px;}
    .lvg-advanced-results .lvg-advanced-toolbar .btn {margin-bottom: 4px;}
    .lvg-advanced-results .lvg-advanced-script pre {max-height: 65vh; overflow-y: auto; user-select: text;}
    .lvg-advanced-results .checkbox input[type=checkbox],
    .lvg-advanced-results .radio input[type=radio] {margin-top: 6px;}
    .lvg-advanced-results .lvg-partial-box {border: 1px solid #b8cbdc;
      background: #f4f8fc; border-radius: 6px; padding: 10px 12px; margin: 12px 0;}
    .lvg-advanced-results .lvg-partial-box > .shiny-input-container {margin-bottom: 6px;}
    .lvg-advanced-results .lvg-partial-box .checkbox label {font-weight: 600;}
    .lvg-advanced-results .lvg-workflow {background: #f1f6fa; border: 1px solid #c4d5e3;
      border-radius: 6px; padding: 10px 14px; margin: 0 0 12px;}
    .lvg-advanced-results .lvg-workflow strong {color: #205c8b;}
    .lvg-advanced-results .lvg-secondary {border-left: 3px solid #c4d5e3; padding-left: 10px; margin-top: 8px;}
    .lvg-advanced-results details > summary {cursor: pointer; font-weight: 600; color: #245b81; margin: 8px 0;}
    .lvg-advanced-results .lvg-save-box {border: 1px solid #ccd6df;
      border-radius: 6px; padding: 12px; margin: 12px 0;}
  "))
}

advancedWorkflow <- function(...) {
  shiny::div(class = "lvg-workflow", shiny::strong("Workflow: "), paste(..., collapse = " "))
}

advancedReportTab <- function(ns) {
  shiny::tabPanel("HTML report", value = "report",
    shiny::div(class = "lvg-advanced-tab", shiny::h4("Export a complete analysis report"),
      shiny::helpText("The offline HTML includes specifications, assumptions, fit tables, tests and warnings, available raw and standardized estimates, for multiple groups, the last recorded diagram (or a default view), current optional diagnostics and the R estimation script. It contains no individual data rows. Aggregated results may be confidential."),
      shiny::uiOutput(ns("reportControl"))))
}

advancedEffectsTab <- function(ns) {
  shiny::tabPanel("Indirect & total effects", value = "effects",
    shiny::div(class = "lvg-advanced-tab", shiny::h4("Compare directed regression-path effects"),
      shiny::helpText("Run Equal regressions first. Effects are computed only from Free regressions, without refitting. Choose a source and target; every directed indirect path is included. Continuous recursive ML/MLR models only. Latent comparisons assume a justified common measurement scale."),
      shiny::fluidRow(shiny::column(6, shiny::selectInput(ns("effectX"), "Source (X)", choices = character())),
        shiny::column(6, shiny::selectInput(ns("effectY"), "Target (Y)", choices = character()))),
      shiny::fluidRow(shiny::column(6, shiny::selectInput(ns("effectFirst"), "First group", choices = character())),
        shiny::column(6, shiny::selectInput(ns("effectSecond"), "Second group", choices = character()))),
      shiny::actionButton(ns("runEffects"), "Compute effects (second minus first)", class = "btn-primary"),
      shiny::verbatimTextOutput(ns("effectStatus")),
      DT::DTOutput(ns("effectTable")), shiny::uiOutput(ns("effectDownload")),
      shiny::helpText("Unstandardized products of coefficients. 95% normal delta-method intervals, unadjusted two-sided Wald p-values. No automatic causal interpretation; compare scales, fit and uncertainty.")))
}

advancedResultToolbar <- function(download, note) {
  shiny::div(class = "lvg-advanced-toolbar", download, shiny::helpText(note))
}

advancedScriptTab <- function(ns) {
  shiny::tabPanel("Analysis script", value = "script",
    shiny::div(class = "lvg-advanced-tab lvg-advanced-script",
      shiny::h4("Reproducible R script"),
      advancedResultToolbar(shiny::downloadButton(ns("downloadScript"), "Download script (R)"),
        "Read or select and copy the script below. The download contains the same script. Load the original data as a data.frame named data before running it."),
      shiny::verbatimTextOutput(ns("scriptPreview"))
    )
  )
}

advancedComparisonUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::tabPanel("Model Comparison",
    shiny::div(class = "lvg-advanced-results",
      advancedResultsStyle(),
      advancedWorkflow("1. Save A and B.  2. Confirm nesting and compare.  3. Read Fit table; use Export for the script or report."),
      shiny::fluidRow(
        shiny::column(4,
          shiny::h4("1. Save two estimated diagrams"),
          shiny::helpText("Estimate the less restricted diagram, open More Results and save it as A. Close this dialog, constrain or remove the proposed path, re-estimate, then save as B. You can save the models in either order. Do not change the data or estimation settings."),
          shiny::actionButton(ns("saveA"), "Save latest estimate as A"), shiny::br(), shiny::br(),
          shiny::actionButton(ns("saveB"), "Save latest estimate as B"), shiny::br(), shiny::br(),
          shiny::actionButton(ns("clear"), "Clear saved models"),
          shiny::hr(),
          shiny::h4("2. Confirm and compare"),
          shiny::checkboxInput(ns("confirm"), "I have checked that B is nested in A", FALSE),
          shiny::helpText("The automatic check covers simple restrictions on regressions and off-diagonal covariances. For ordinal indicators, declare the same ordered nodes in both models and use WLSMV with listwise deletion. Other kinds of nesting are not certified."),
          shiny::actionButton(ns("run"), "Compare A and B", class = "btn-primary"),
          shiny::helpText("Read the results in the tabs on the right. Downloads are optional.")
        ),
        shiny::column(8,
          shiny::h4("Saved model specifications"),
          shiny::verbatimTextOutput(ns("status")),
          shiny::tags$details(shiny::tags$summary("Inspect saved specifications A and B"), shiny::div(class = "lvg-advanced-spec",
            shiny::fluidRow(shiny::column(6, shiny::h5("A - less restricted"), shiny::verbatimTextOutput(ns("syntaxA"))),
                            shiny::column(6, shiny::h5("B - more restricted"), shiny::verbatimTextOutput(ns("syntaxB")))))),
          shiny::tabsetPanel(id = ns("resultView"), selected = "fit",
            shiny::tabPanel("Fit table", value = "fit",
              shiny::div(class = "lvg-advanced-tab",
                shiny::h4("Fit comparison"),
                advancedResultToolbar(shiny::downloadButton(ns("downloadFit"), "Download fit table (CSV)"), "Compare the models to populate this table."),
                shiny::div(class = "lvg-advanced-table", shiny::tableOutput(ns("fitTable"))),
                shiny::h4("Difference test and diagnostics"),
                shiny::verbatimTextOutput(ns("diagnostics")),
                shiny::helpText("Supports continuous ML/MLR and simple nested ordinal WLSMV models (delta, listwise, same thresholds/scale specification). WLSMV uses a scaled-shifted Satorra (2000) difference test; AIC/BIC do not apply. Robust tests are not obtained by subtracting scaled chi-squares. A non-significant test is not proof of nesting or equivalence.")
              )
            ),
            shiny::tabPanel("Export", value = "export", shiny::div(class = "lvg-secondary",
              shiny::tabsetPanel(id = ns("exportView"), advancedScriptTab(ns), advancedReportTab(ns))))
          )
        )
      )
    )
  )
}

advancedShowSpec <- function(spec) {
  if (is.null(spec)) return("Not saved")
  paste(c(spec$syntax, "", paste("Data fingerprint:", substr(spec$hash, 1L, 12L)),
    paste("Estimator:", spec$options$estimator), paste("Missing:", spec$options$missing),
    paste("Ordered variables:", if (length(spec$options$ordered)) paste(spec$options$ordered, collapse = ", ") else "none")), collapse = "\n")
}

advancedPrintDiagnostics <- function(res) {
  cat(res$note, "\n\n", sep = "")
  if (!is.null(res$group)) {
    cat("Grouping variable: ", res$group, "\nReference group: ", res$labels[1L],
        "\nRows excluded because group is missing/blank: ", res$dropped, "\n", sep = "")
    cat("Raw group counts (before model-specific missing-data handling):\n")
    print(res$counts)
    cat("Equality constraints by model:\n")
    for (nm in names(res$sets)) {
      cat(nm, ": ", if (length(res$sets[[nm]])) paste(res$sets[[nm]], collapse = ", ") else "none", "\n", sep = "")
      if (length(res$partials[[nm]])) cat("  Exceptions (free across groups): ", paste(res$partials[[nm]], collapse = ", "), "\n", sep = "")
    }
    if (length(res$constrained_regressions)) cat("Regressions tested for equality: ", paste(res$constrained_regressions, collapse = ", "), "\n", sep = "")
    if (length(res$expected_steps)) cat("Expected successive df increases: ", paste(res$expected_steps, collapse = ", "), "\n", sep = "")
  }
  cat("Data fingerprint: ", substr(res$hash, 1L, 12L), "\n", sep = "")
  if (length(res$restrictions)) cat("Detected restrictions:\n", paste(res$restrictions, collapse = "\n"), "\n", sep = "")
  messages <- advancedFitMessages(res$fits)
  if (length(messages)) cat("\nModel diagnostics:\n", paste(messages, collapse = "\n"), "\n", sep = "")
  for (nm in names(res$tests)) {
    test <- res$tests[[nm]]
    cat("\n", nm, "\n", sep = "")
    if (is.null(test$value)) cat("No inferential test: ", test$error, "\n", sep = "") else print(test$value)
    if (length(test$warnings)) cat(paste(test$warnings, collapse = "\n"), "\n")
  }
  if (!length(messages)) cat("\nNo model warnings captured during estimation/post-check.\n")
}

advancedComparisonServer <- function(id, getData, analysisSpec) {
  shiny::moduleServer(id, function(input, output, session) {
    a <- shiny::reactiveVal(NULL)
    b <- shiny::reactiveVal(NULL)
    result <- shiny::reactiveVal(NULL)
    problem <- shiny::reactiveVal(NULL)
    current_hash <- shiny::reactive(advancedDataHash(getData()))
    reset_result <- function() { result(NULL); problem(NULL) }
    save_spec <- function(slot) {
      tryCatch({
        spec <- analysisSpec()
        advancedCheckSnapshot(spec, getData())
        slot(spec)
        reset_result()
        shiny::updateCheckboxInput(session, "confirm", value = FALSE)
      }, error = function(e) { problem(conditionMessage(e)); shiny::showNotification(conditionMessage(e), type = "error") })
    }
    shiny::observeEvent(input$saveA, save_spec(a))
    shiny::observeEvent(input$saveB, save_spec(b))
    shiny::observeEvent(input$clear, { a(NULL); b(NULL); reset_result(); shiny::updateCheckboxInput(session, "confirm", value = FALSE) })
    shiny::observeEvent(current_hash(), reset_result(), ignoreNULL = FALSE)
    shiny::observeEvent(input$confirm, reset_result(), ignoreInit = TRUE)
    output$status <- shiny::renderText({
      h <- current_hash()
      latest <- analysisSpec()
      current <- if (is.null(latest) || !identical(latest$hash, h)) "No completed estimate with the current data. Return to Estimates first." else "Latest completed estimate available. Save it to either slot."
      state <- function(x) if (is.null(x)) "empty" else if (!identical(x$hash, h)) "stale - data changed" else "saved"
      paste(current, paste("A:", state(a()), " | B:", state(b())), sep = "\n")
    })
    output$syntaxA <- shiny::renderText(advancedShowSpec(a()))
    output$syntaxB <- shiny::renderText(advancedShowSpec(b()))
    shiny::observeEvent(input$run, {
      shiny::updateTabsetPanel(session, "resultView", selected = "fit")
      reset_result()
      tryCatch({
        res <- shiny::withProgress(message = "Refitting saved models", value = 0.3,
          advancedCompare(a(), b(), getData(), isTRUE(input$confirm)))
        result(res)
      }, error = function(e) problem(conditionMessage(e)))
    })
    output$fitTable <- shiny::renderTable({ shiny::req(result()); result()$summary }, digits = 4, striped = TRUE, na = "-")
    output$diagnostics <- shiny::renderPrint({
      if (!is.null(problem())) cat("ERROR: ", problem(), "\n", sep = "")
      if (!is.null(result())) advancedPrintDiagnostics(result()) else if (is.null(problem())) cat("Save A and B, then click Compare A and B.")
    })
    output$downloadFit <- shiny::downloadHandler(filename = function() "model-comparison.csv", content = function(file) {
      shiny::req(result()); utils::write.csv(result()$summary, file, row.names = FALSE)
    })
    output$scriptPreview <- shiny::renderText({
      res <- result()
      if (is.null(res)) return("Run the analysis to view its R script here.")
      paste(advancedScript(res), collapse = "\n")
    })
    output$downloadScript <- shiny::downloadHandler(filename = function() "model-comparison.R", content = function(file) {
      shiny::req(result()); writeLines(enc2utf8(advancedScript(result())), file, useBytes = TRUE)
    })
    output$reportControl <- shiny::renderUI({
      if (is.null(result())) return(shiny::helpText("Compare the models to enable the report."))
      shiny::downloadButton(session$ns("downloadReport"), "Download HTML report", class = "btn-primary")
    })
    output$downloadReport <- shiny::downloadHandler(filename = function() "model-comparison-report.html", content = function(file) {
      shiny::req(result()); advancedWriteReport(result(), file)
    })
  })
}

advancedMultigroupUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::tabPanel("Multiple Groups",
    shiny::div(class = "lvg-advanced-results",
      advancedResultsStyle(),
      advancedWorkflow("1. Choose group and analysis.  2. Confirm and run.  3. Review fit, estimates and diagram.  4. Explore diagnostics or use Export & restore."),
      shiny::fluidRow(
        shiny::column(4,
          shiny::h4("1. Configure analysis"),
          shiny::helpText("Uses the last completed diagram estimate and the same loaded data. The main diagram and its estimates are not changed."),
          shiny::selectInput(ns("group"), "Grouping column", choices = c("Choose a column" = "")),
          shiny::helpText("A grouping column must have 2-10 distinct nonblank values and must not be an indicator or predictor in the model."),
          shiny::radioButtons(ns("mode"), "Analysis", c("Measurement invariance (CFA)" = "invariance", "Ordinal measurement invariance (WLSMV)" = "ordinal", "Equal regressions (path model / SEM)" = "regressions")),
          shiny::conditionalPanel(condition = sprintf("input['%s'] === 'invariance'", ns("mode")),
            shiny::checkboxInput(ns("strict"), "Include strict invariance (residual variances)", FALSE),
            shiny::div(class = "lvg-partial-box",
              shiny::checkboxInput(ns("partialEnabled"), "Specify exceptions (partial invariance)", FALSE),
              shiny::helpText("Check this box to choose loadings or intercepts that may differ between groups. Uncheck to run full invariance."),
              shiny::conditionalPanel(condition = sprintf("input['%s'] === true", ns("partialEnabled")),
                shiny::selectizeInput(ns("releaseLoadings"), "Loadings free across groups", choices = character(), multiple = TRUE,
                  options = list(placeholder = "Choose loadings to release...")),
                shiny::selectizeInput(ns("releaseIntercepts"), "Intercepts free across groups", choices = character(), multiple = TRUE,
                  options = list(placeholder = "Choose intercepts to release...")),
                shiny::helpText("Empty selections retain full invariance. Marker loadings cannot be released. Keep at least two jointly invariant indicators per factor. Data-guided releases are exploratory; justify and validate them.")))),
          shiny::conditionalPanel(condition = sprintf("input['%s'] === 'ordinal'", ns("mode")),
            shiny::checkboxInput(ns("ordinalStrict"), "Include strict invariance (ordinal response residual variances)", FALSE),
            shiny::helpText("For a simple CFA with every indicator declared ordered, 4-12 categories, at least three indicators per factor, and identical category sets in every group. The workflow uses WLSMV, theta and Wu & Estabrook identification (std.lv), with thresholds before loadings and intercepts. Requires semTools. Full invariance only; no correlated indicator residuals or cross-loadings.")),
          shiny::conditionalPanel(condition = sprintf("input['%s'] === 'regressions'", ns("mode")),
            shiny::radioButtons(ns("base"), "For latent models, assume justified measurement constraints", choices = c("Equal loadings (metric)" = "metric", "Equal loadings and intercepts (scalar)" = "scalar")),
            shiny::helpText("For a path model without latent variables the measurement option is ignored. Equality tests concern unstandardized coefficients."),
            shiny::radioButtons(ns("regressionScope"), "Regressions to constrain", choices = c("All free regressions" = "all", "Only selected regressions" = "selected")),
            shiny::conditionalPanel(condition = sprintf("input['%s'] === 'selected'", ns("regressionScope")),
              shiny::selectizeInput(ns("selectedRegressions"), "Regressions equal across groups", choices = character(), multiple = TRUE),
              shiny::helpText("Unselected regressions stay free. Select one regression for a targeted test, or several for a joint test."))),
          shiny::h4("2. Confirm and run"),
          shiny::checkboxInput(ns("confirm"), "I have checked the grouping variable, measurement type and assumptions", FALSE),
          shiny::actionButton(ns("run"), "Run multigroup analysis", class = "btn-primary"),
          shiny::helpText("Read the results in the tabs on the right. Downloads are optional.")
        ),
        shiny::column(8,
          shiny::h4("3. Review results"),
          shiny::textOutput(ns("readyStatus")),
          shiny::tags$details(shiny::tags$summary("Inspect current model and estimation settings"),
            shiny::div(class = "lvg-advanced-spec", shiny::verbatimTextOutput(ns("status")))),
          shiny::tabsetPanel(id = ns("resultView"), selected = "fit",
            shiny::tabPanel("Fit table", value = "fit",
              shiny::div(class = "lvg-advanced-tab",
                shiny::h4("Fit indices (ordinary and robust where available)"),
                advancedResultToolbar(shiny::downloadButton(ns("downloadFit"), "Download fit table (CSV)"), "Run the analysis to populate the fit table and sequential comparisons."),
                shiny::div(class = "lvg-advanced-table", shiny::tableOutput(ns("fitTable"))),
                shiny::h4("Observations used per group"), shiny::tableOutput(ns("used")),
                shiny::h4("Sequential comparisons and diagnostics"), shiny::verbatimTextOutput(ns("diagnostics"))
              )
            ),
            shiny::tabPanel("Selected estimates", value = "estimates",
              shiny::div(class = "lvg-advanced-tab",
                shiny::h4("Parameters by group"),
                shiny::fluidRow(shiny::column(5, shiny::selectInput(ns("stage"), "Model", choices = character())),
                                shiny::column(7, shiny::radioButtons(ns("std"), "Estimates and matching confidence intervals", c("Unstandardized" = "raw", "Fully standardized" = "std"), inline = TRUE))),
                advancedResultToolbar(shiny::downloadButton(ns("downloadParams"), "Download selected estimates (CSV)"), "Choose a fitted model and standardization. The CSV contains the full selected parameter table, including unrounded values."),
                DT::DTOutput(ns("parameters"))
              )
            ),
            advancedDiagramTab(ns),
            shiny::tabPanel("Advanced diagnostics", value = "advanced", shiny::div(class = "lvg-secondary",
              shiny::helpText("Choose measurement constraint diagnostics or structural indirect and total effects."),
              shiny::tabsetPanel(id = ns("advancedView"),
            shiny::tabPanel("Constraint diagnostics", value = "constraints",
              shiny::div(class = "lvg-advanced-tab",
                shiny::h4("Explore measurement equality constraints"),
                shiny::helpText("Continuous CFA, two groups, ordinary ML with listwise deletion only. Select a constrained fitted model and request score tests. Each test and EPC releases one equality hypothetically while retaining the others. No model is changed or refitted. These are exploratory diagnostics, not automatic recommendations; justify and cross-validate releases."),
                shiny::selectInput(ns("scoreStage"), "Fitted model with equality constraints", choices = character()),
                shiny::actionButton(ns("runScore"), "Compute score tests and EPC", class = "btn-primary"),
                shiny::verbatimTextOutput(ns("scoreStatus")),
                shiny::div(class = "lvg-advanced-table", DT::DTOutput(ns("scoreTable"))),
                shiny::helpText("Holm-adjusted p-values use the number of listed constraints, including unavailable tests. Residual-variance diagnostics are for inspection; the current partial-invariance settings release only loadings and intercepts."),
                shiny::uiOutput(ns("scoreEpcControls")),
                shiny::tableOutput(ns("scoreEpc"))
              )
            ),
            advancedEffectsTab(ns)))),
            shiny::tabPanel("Export & restore", value = "export", shiny::div(class = "lvg-secondary",
              shiny::helpText("Save an analysis and its diagram layout, read its R script, or export a complete HTML report."),
              shiny::tabsetPanel(id = ns("exportView"), selected = "project",
            shiny::tabPanel("Save / restore", value = "project",
              shiny::div(class = "lvg-advanced-tab",
                shiny::h4("Save the analysis"),
                shiny::div(class = "lvg-save-box",
                  shiny::helpText("Save the original diagram (.lvm) and data separately. This companion JSON contains the analysis settings, fit summaries, parameter tables, group counts and test diagnostics, and the last viewed diagram layout (if opened), but no individual observations or fitted R objects."),
                  shiny::verbatimTextOutput(ns("viewSaveStatus")),
                  shiny::uiOutput(ns("saveProjectControl"))),
                shiny::h4("Restore analysis settings"),
                shiny::div(class = "lvg-save-box",
                  shiny::helpText("Open the original diagram and identical data, and estimate it first. Choose the companion JSON below. The saved settings will be checked against the current diagram and data; applying them does not automatically fit a model."),
                  shiny::fileInput(ns("projectFile"), "Saved analysis (.json)", accept = c(".json", "application/json")),
                  shiny::verbatimTextOutput(ns("projectStatus")),
                  shiny::uiOutput(ns("applyProjectControl")),
                  shiny::helpText("Review the restored settings, confirm the assumptions and click Run multigroup analysis to obtain fresh results.")))
            ), advancedScriptTab(ns), advancedReportTab(ns))))
          ),
          shiny::helpText("Continuous CFA uses marker scaling and a mean structure. Ordinal CFA uses a separate theta/WLSMV sequence with std.lv identification. The first listed group is the reference. Partial invariance is currently continuous only. Existing equality labels, higher-order and special models are not included.")
        )
      )
    )
  )
}

advancedMultigroupServer <- function(id, getData, analysisSpec) {
  shiny::moduleServer(id, function(input, output, session) {
    result <- shiny::reactiveVal(NULL)
    problem <- shiny::reactiveVal(NULL)
    imported_project <- shiny::reactiveVal(NULL)
    project_message <- shiny::reactiveVal("Choose a saved analysis JSON file.")
    pending_view <- shiny::reactiveVal(NULL)
    score_run <- shiny::reactiveVal(NULL)
    score_problem <- shiny::reactiveVal(NULL)
    effect_run <- shiny::reactiveVal(NULL)
    effect_problem <- shiny::reactiveVal(NULL)
    view_counter <- 0L
    # The token ties a browser view to a particular completed estimation run.
    # Ignore stale events after the user changes the data or model.
    current_view <- function() {
      res <- result()
      if (is.null(res)) return(NULL)
      raw <- shiny::isolate(input$diagramViewState)
      v <- tryCatch({
        if (!is.character(raw) || length(raw) != 1L || is.na(raw) || nchar(raw, type = "bytes") > 250000L) NULL else {
          obj <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
          if (!is.list(obj) || !identical(as.character(obj$token), res$view_token)) NULL else advancedViewForResult(obj$view, res)
        }
      }, error = function(e) NULL)
      if (is.null(v)) res$restored_view else v
    }
    reset_result <- function() {
      result(NULL); problem(NULL); score_run(NULL); score_problem(NULL); effect_run(NULL); effect_problem(NULL)
      for (key in c("effectX", "effectY", "effectFirst", "effectSecond"))
        shiny::updateSelectInput(session, key, choices = character())
      shiny::updateSelectInput(session, "scoreStage", choices = character())
      shiny::updateSelectInput(session, "stage", choices = character())
      shiny::updateSelectInput(session, "diagramStage", choices = character())
    }
    shiny::observe({
      choices <- advancedGroupCandidates(getData(), analysisSpec())
      old <- shiny::isolate(input$group)
      selected <- if (!is.null(old) && old %in% choices) old else ""
      shiny::updateSelectInput(session, "group", choices = c("Choose a column" = "", choices), selected = selected)
    })
    shiny::observeEvent(analysisSpec(), {
      reset_result()
      pending_view(NULL)
      imported_project(NULL)
      project_message("Choose a saved analysis JSON file for the current model.")
      shiny::updateCheckboxInput(session, "confirm", value = FALSE)
      shiny::updateCheckboxInput(session, "partialEnabled", value = FALSE)
      choices <- tryCatch(advancedGroupChoices(analysisSpec()), error = function(e)
        list(loadings = character(), intercepts = character(), regressions = character()))
      display_keys <- function(keys) {
        labels <- gsub("=~", " =~ ", keys, fixed = TRUE)
        # Keep the two-character loading operator intact.
        labels <- ifelse(grepl("=~", keys, fixed = TRUE), labels, gsub("~", " ~ ", keys, fixed = TRUE))
        stats::setNames(keys, labels)
      }
      shiny::updateSelectizeInput(session, "releaseLoadings", choices = display_keys(choices$loadings), selected = character())
      shiny::updateSelectizeInput(session, "releaseIntercepts", choices = display_keys(choices$intercepts), selected = character())
      shiny::updateSelectizeInput(session, "selectedRegressions", choices = display_keys(choices$regressions), selected = character())
    }, ignoreNULL = FALSE)
    shiny::observeEvent(getData(), {
      reset_result(); imported_project(NULL); pending_view(NULL)
      project_message("Choose a saved analysis JSON file for the current data.")
      shiny::updateCheckboxInput(session, "confirm", value = FALSE)
    }, ignoreNULL = FALSE)
    shiny::observeEvent(list(input$group, input$mode, input$strict, input$ordinalStrict, input$base, input$partialEnabled,
      input$releaseLoadings, input$releaseIntercepts, input$regressionScope, input$selectedRegressions), {
      reset_result(); shiny::updateCheckboxInput(session, "confirm", value = FALSE)
    }, ignoreInit = TRUE)
    output$readyStatus <- shiny::renderText({
      spec <- analysisSpec()
      if (is.null(spec) || !identical(spec$hash, advancedDataHash(getData()))) return("Estimate the diagram with the current data first.")
      if (is.null(result())) return("A completed diagram estimate is available. Configure and run the multiple-group analysis.")
      paste("Analysis complete. Grouping:", result()$group, "|", paste(result()$labels, collapse = ", "))
    })
    output$status <- shiny::renderText({
      spec <- analysisSpec()
      if (is.null(spec) || !identical(spec$hash, advancedDataHash(getData()))) return("Estimate the diagram with the current data first.")
      advancedShowSpec(spec)
    })
    shiny::observeEvent(input$run, {
      shiny::updateTabsetPanel(session, "resultView", selected = "fit")
      reset_result()
      tryCatch({
        if (!isTRUE(input$confirm)) stop("Please confirm the grouping and measurement assumptions first.", call. = FALSE)
        res <- shiny::withProgress(message = "Fitting multiple-group models", value = 0, {
          advancedMultigroup(analysisSpec(), getData(), input$group, input$mode,
            if (identical(input$mode, "ordinal")) isTRUE(input$ordinalStrict) else isTRUE(input$strict), input$base,
            progress = function(name, n) shiny::incProgress(1/n, detail = name),
            release_loadings = if (identical(input$mode, "invariance") && isTRUE(input$partialEnabled)) input$releaseLoadings else character(),
            release_intercepts = if (identical(input$mode, "invariance") && isTRUE(input$partialEnabled)) input$releaseIntercepts else character(),
            selected_regressions = if (identical(input$mode, "regressions") && identical(input$regressionScope, "selected"))
              as.character(input$selectedRegressions) else NULL)
        })
        view_counter <<- view_counter + 1L
        res$view_token <- digest::digest(list(session$token, view_counter))
        saved <- pending_view(); pending_view(NULL)
        if (!is.null(saved) && identical(saved$request, res$request) &&
            identical(saved$hash, res$hash) && identical(saved$spec_id, res$spec_id)) {
          res$restored_view <- tryCatch(advancedViewForResult(saved$diagram_view, res), error = function(e) {
            shiny::showNotification(paste("Saved diagram view not restored:", conditionMessage(e)), type = "warning"); NULL
          })
        }
        result(res)
        usable <- names(res$fits)[vapply(res$fits, advancedUsable, logical(1))]
        shiny::updateSelectInput(session, "stage", choices = usable, selected = if (length(usable)) usable[1L] else character())
        stage <- if (!is.null(res$restored_view)) res$restored_view$stage else if (length(usable)) usable[1L] else character()
        shiny::updateSelectInput(session, "diagramStage", choices = usable, selected = stage)
        scores <- if (identical(res$mode, "invariance")) intersect(usable, names(res$sets)[lengths(res$sets) > 0L]) else character()
        shiny::updateSelectInput(session, "scoreStage", choices = scores, selected = if (length(scores)) scores[1L] else character())
        shiny::updateTabsetPanel(session, "advancedView", selected = if (identical(res$mode, "regressions")) "effects" else "constraints")
        if (identical(res$mode, "regressions") && "Free regressions" %in% usable) {
          graph <- tryCatch(advancedEffectGraph(res$fits[["Free regressions"]]), error = function(e) {
            effect_problem(conditionMessage(e)); NULL
          })
          if (!is.null(graph)) {
            roots <- setdiff(graph$ref$rhs, graph$ref$lhs)
            sinks <- setdiff(graph$ref$lhs, graph$ref$rhs)
            shiny::updateSelectInput(session, "effectX", choices = unique(graph$ref$rhs), selected = if (length(roots)) roots[1L] else graph$ref$rhs[1L])
            shiny::updateSelectInput(session, "effectY", choices = unique(graph$ref$lhs), selected = if (length(sinks)) sinks[1L] else graph$ref$lhs[1L])
            shiny::updateSelectInput(session, "effectFirst", choices = graph$groups, selected = graph$groups[1L])
            shiny::updateSelectInput(session, "effectSecond", choices = graph$groups, selected = graph$groups[2L])
          }
        }
      }, error = function(e) problem(conditionMessage(e)))
    })
    output$fitTable <- shiny::renderTable({ shiny::req(result()); result()$summary }, digits = 4, striped = TRUE, na = "-")
    output$used <- shiny::renderTable({ shiny::req(result()); result()$used }, digits = 0, striped = TRUE)
    output$diagnostics <- shiny::renderPrint({
      if (!is.null(problem())) cat("ERROR: ", problem(), "\n", sep = "")
      if (!is.null(result())) advancedPrintDiagnostics(result()) else if (is.null(problem())) cat("Choose a grouping column and analysis type, then click Run multigroup analysis.")
    })
    params <- shiny::reactive({
      res <- result()
      shiny::req(res, input$stage, input$stage %in% names(res$fits))
      advancedParameters(res$fits[[input$stage]], identical(input$std, "std"))
    })
    output$groupDiagram <- shiny::renderUI({
      res <- result()
      if (is.null(res)) return(shiny::helpText("Run a multiple-group analysis first."))
      usable <- names(res$fits)[vapply(res$fits, advancedUsable, logical(1))]
      if (!length(usable)) return(shiny::helpText("No converged, admissible model is available. See Fit table and diagnostics."))
      shiny::req(input$diagramStage %in% usable)
      saved <- if (!is.null(res$restored_view) && identical(res$restored_view$stage, input$diagramStage)) res$restored_view else NULL
      tryCatch(advancedDiagramUI(advancedGroupDiagramData(res$fits[[input$diagramStage]], input$diagramStage, res$group),
        state_input = session$ns("diagramViewState"), token = res$view_token, restored_view = saved),
        error = function(e) shiny::div(class = "alert alert-warning", conditionMessage(e)))
    })
    # Store scores only for the current estimation token and selected stage.
    # This prevents a table from appearing to describe a different model.
    current_scores <- shiny::reactive({
      z <- score_run(); res <- result()
      if (is.null(z) || is.null(res) || !identical(z$token, res$view_token) || !identical(z$stage, input$scoreStage)) return(NULL)
      z$value
    })
    shiny::observeEvent(input$scoreStage, { score_run(NULL); score_problem(NULL) }, ignoreInit = TRUE)
    shiny::observeEvent(input$runScore, {
      score_run(NULL); score_problem(NULL)
      tryCatch({
        res <- result(); stage <- input$scoreStage
        if (is.null(res) || !identical(res$mode, "invariance") || length(stage) != 1L || !stage %in% names(res$fits))
          stop("Run a continuous CFA invariance analysis, then select a constrained fitted model.", call. = FALSE)
        z <- shiny::withProgress(message = "Computing one-constraint score tests", value = 0, {
          advancedScoreDiagnostics(res$fits[[stage]], progress = function(i, n) shiny::setProgress(i/n, detail = paste(i, "of", n)))
        })
        score_run(list(token = res$view_token, stage = stage, value = z))
      }, error = function(e) score_problem(conditionMessage(e)))
    })
    output$scoreStatus <- shiny::renderText({
      if (!is.null(score_problem())) return(paste("ERROR:", score_problem()))
      z <- current_scores()
      if (is.null(z)) return("Select a constrained fitted model and compute diagnostics. See Fit table for convergence and warnings.")
      paste(input$scoreStage, "| ordinary ML score tests |", sum(z$table$Status == "OK"), "of", nrow(z$table), "constraints evaluated. EPC = expected change; Expected = current estimate + EPC, not a refitted estimate.")
    })
    output$scoreTable <- DT::renderDT({
      z <- current_scores(); shiny::req(z)
      DT::formatSignif(DT::datatable(z$table, rownames = FALSE, escape = TRUE, width = "100%",
        options = list(scrollX = TRUE, pageLength = 10, order = list())),
        c("X2", "p", "p_Holm"), digits = 5)
    })
    output$scoreEpcControls <- shiny::renderUI({
      z <- current_scores(); if (is.null(z) || !length(z$epcs)) return(NULL)
      tab <- z$table[z$table$Status == "OK", , drop = FALSE]
      shiny::tagList(shiny::h5("Expected parameter changes for a single equality"),
        shiny::selectInput(session$ns("scoreEpcId"), "Choose a tested constraint", choices = stats::setNames(as.character(tab$Constraint), paste(tab$Parameter, "[", tab$Type, "]"))),
        shiny::downloadButton(session$ns("downloadScore"), "Download score table (CSV)"),
        shiny::downloadButton(session$ns("downloadEpc"), "Download selected EPC (CSV)"))
    })
    selected_epc <- shiny::reactive({
      z <- current_scores(); shiny::req(z, input$scoreEpcId, input$scoreEpcId %in% names(z$epcs))
      z$epcs[[input$scoreEpcId]]
    })
    output$scoreEpc <- shiny::renderTable(selected_epc(), digits = 5, striped = TRUE)
    output$downloadScore <- shiny::downloadHandler(filename = function() "measurement-score-tests.csv", content = function(file) {
      z <- current_scores(); shiny::req(z); utils::write.csv(z$table, file, row.names = FALSE)
    })
    output$downloadEpc <- shiny::downloadHandler(filename = function() "measurement-selected-epc.csv", content = function(file) {
      utils::write.csv(selected_epc(), file, row.names = FALSE)
    })
    effect_selection <- shiny::reactive(list(input$effectX, input$effectY, input$effectFirst, input$effectSecond))
    current_effects <- shiny::reactive({
      z <- effect_run(); res <- result()
      if (is.null(z) || is.null(res) || !identical(z$token, res$view_token) || !identical(z$selection, effect_selection())) return(NULL)
      z$value
    })
    shiny::observeEvent(effect_selection(), { effect_run(NULL); effect_problem(NULL) }, ignoreInit = TRUE)
    shiny::observeEvent(input$runEffects, {
      effect_run(NULL); effect_problem(NULL)
      tryCatch({
        res <- result()
        if (is.null(res) || !identical(res$mode, "regressions")) stop("Run Equal regressions first.", call. = FALSE)
        sel <- effect_selection()
        value <- do.call(advancedEffects, c(list(out = res$fits[["Free regressions"]]), sel))
        effect_run(list(token = res$view_token, selection = sel, value = value))
      }, error = function(e) effect_problem(conditionMessage(e)))
    })
    output$effectStatus <- shiny::renderText({
      if (!is.null(effect_problem())) return(paste("ERROR:", effect_problem()))
      z <- current_effects()
      if (is.null(z)) return("Select the source, target and groups, then compute effects from Free regressions.")
      paste(z$exposure, "to", z$outcome, "|", z$second, "minus", z$first, "| SE:", z$se, "\n", z$note)
    })
    output$effectTable <- DT::renderDT({
      z <- current_effects(); shiny::req(z)
      DT::formatSignif(DT::datatable(z$table, rownames = FALSE, escape = TRUE, width = "100%",
        options = list(scrollX = TRUE, pageLength = 15, order = list())), c("Estimate", "SE", "CI.lower", "CI.upper", "p"), digits = 5)
    })
    output$effectDownload <- shiny::renderUI({
      if (is.null(current_effects())) return(NULL)
      shiny::downloadButton(session$ns("downloadEffects"), "Download effects (CSV)")
    })
    output$downloadEffects <- shiny::downloadHandler(filename = function() "multigroup-effects.csv", content = function(file) {
      z <- current_effects(); shiny::req(z); utils::write.csv(z$table, file, row.names = FALSE)
    })
    output$reportControl <- shiny::renderUI({
      if (is.null(result())) return(shiny::helpText("Run the analysis to enable the report."))
      shiny::downloadButton(session$ns("downloadReport"), "Download HTML report", class = "btn-primary")
    })
    output$downloadReport <- shiny::downloadHandler(filename = function() "multigroup-report.html", content = function(file) {
      res <- result(); shiny::req(res)
      z <- current_scores()
      score <- if (is.null(z)) NULL else list(stage = input$scoreStage, value = z)
      advancedWriteReport(res, file, diagram_view = current_view(), score = score, effects = current_effects())
    })
    output$parameters <- DT::renderDT({
      DT::datatable(round_df(params(), 4), rownames = FALSE,
        options = list(scrollX = TRUE, pageLength = 15, autoWidth = TRUE),
        width = "100%", escape = TRUE)
    })
    output$downloadFit <- shiny::downloadHandler(filename = function() "multigroup-fit.csv", content = function(file) {
      shiny::req(result()); utils::write.csv(result()$summary, file, row.names = FALSE)
    })
    output$downloadParams <- shiny::downloadHandler(filename = function() "multigroup-parameters.csv", content = function(file) {
      utils::write.csv(params(), file, row.names = FALSE)
    })
    output$scriptPreview <- shiny::renderText({
      res <- result()
      if (is.null(res)) return("Run the analysis to view its R script here.")
      paste(advancedScript(res), collapse = "\n")
    })
    output$downloadScript <- shiny::downloadHandler(filename = function() "multigroup-analysis.R", content = function(file) {
      shiny::req(result()); writeLines(enc2utf8(advancedScript(result())), file, useBytes = TRUE)
    })
    output$viewSaveStatus <- shiny::renderText({
      input$diagramViewState # react when the browser sends a new view
      if (is.null(result())) return("No completed analysis.")
      v <- current_view()
      if (is.null(v)) "No diagram view recorded. Open Path diagram to include one." else
        paste("Diagram view ready to save:", v$stage, "|", v$group,
          if (v$mode != "single") paste("and", v$other, if (v$mode == "difference") "(difference)") else "", "|", paste0(v$zoom, "%"), "|", v$scale)
    })
    output$saveProjectControl <- shiny::renderUI({
      if (is.null(result())) return(shiny::helpText("Run the analysis to enable saving."))
      shiny::downloadButton(session$ns("downloadProject"), "Download analysis (.json)", class = "btn-primary")
    })
    output$downloadProject <- shiny::downloadHandler(filename = function() "multigroup-analysis.json", content = function(file) {
      shiny::req(result()); advancedWriteGroupProject(result(), file, diagram_view = current_view())
    })
    shiny::observeEvent(input$projectFile, {
      imported_project(NULL)
      tryCatch({
        project <- advancedReadGroupProject(input$projectFile$datapath, analysisSpec(), getData())
        imported_project(project)
        r <- project$request
        project_message(paste(c("Compatible analysis file. Review settings before applying.",
          paste("Saved:", project$created_utc, " | lavaan:", project$lavaan_version,
            if (!is.null(project$semTools_version)) paste(" | semTools:", project$semTools_version) else ""),
          paste("Grouping:", r$group, " | Groups:", paste(project$labels, collapse = ", ")),
          paste("Analysis:", r$mode, " | Strict:", r$strict, " | Measurement base:", r$base),
          paste("Loadings released:", if (length(r$release_loadings)) paste(r$release_loadings, collapse = ", ") else "none"),
          paste("Intercepts released:", if (length(r$release_intercepts)) paste(r$release_intercepts, collapse = ", ") else "none"),
          paste("Regressions:", if (is.null(r$selected_regressions)) "all (if regression mode)" else paste(r$selected_regressions, collapse = ", ")),
          paste("Saved diagram view:", if (is.null(project$diagram_view)) "none" else project$diagram_view$stage)), collapse = "\n"))
      }, error = function(e) project_message(paste("ERROR:", conditionMessage(e))))
    }, ignoreNULL = TRUE)
    output$projectStatus <- shiny::renderText(project_message())
    output$applyProjectControl <- shiny::renderUI({
      if (is.null(imported_project())) return(NULL)
      shiny::actionButton(session$ns("applyProject"), "Apply saved settings", class = "btn-primary")
    })
    shiny::observeEvent(input$applyProject, {
      tryCatch({
        project <- imported_project()
        if (is.null(project) || !identical(project$spec_id, advancedSpecId(analysisSpec())) ||
            !identical(project$hash, advancedDataHash(getData())))
          stop("The current model or data changed. Select the saved file again.", call. = FALSE)
        r <- project$request
        # Validate once again before changing any controls. Do not fit the model.
        invisible(do.call(advancedGroupPlan, c(list(spec = analysisSpec(), data = getData(), validate_only = TRUE), r)))
        reset_result()
        pending_view(project)
        shiny::updateSelectInput(session, "group", selected = r$group)
        shiny::updateRadioButtons(session, "mode", selected = r$mode)
        shiny::updateCheckboxInput(session, "strict", value = identical(r$mode, "invariance") && r$strict)
        shiny::updateCheckboxInput(session, "ordinalStrict", value = identical(r$mode, "ordinal") && r$strict)
        shiny::updateRadioButtons(session, "base", selected = r$base)
        shiny::updateCheckboxInput(session, "partialEnabled", value = length(r$release_loadings) + length(r$release_intercepts) > 0L)
        shiny::updateSelectizeInput(session, "releaseLoadings", selected = r$release_loadings)
        shiny::updateSelectizeInput(session, "releaseIntercepts", selected = r$release_intercepts)
        shiny::updateRadioButtons(session, "regressionScope", selected = if (is.null(r$selected_regressions)) "all" else "selected")
        shiny::updateSelectizeInput(session, "selectedRegressions", selected = if (is.null(r$selected_regressions)) character() else r$selected_regressions)
        shiny::updateCheckboxInput(session, "confirm", value = FALSE)
        imported_project(NULL)
        project_message("Settings restored. Review the controls, confirm assumptions and run the analysis again. The saved view is restored after a compatible successful refit. Previous fit summaries are not treated as current estimates.")
        shiny::showNotification("Saved settings applied. Review, confirm and run the analysis.", type = "message")
      }, error = function(e) project_message(paste("ERROR:", conditionMessage(e))))
    })
  })
}
