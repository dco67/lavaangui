\name{lavaangui-analysis-export}
\alias{lavaangui-analysis-export}
\title{Export, Save and Restore Advanced Analyses}
\description{Inspect and export advanced results without changing the original model or requiring downloads to view the results.}
\details{
\describe{
\item{Fit table and Selected estimates}{CSV downloads contain the corresponding tables. The effects and score/EPC tabs offer their own CSV downloads.}
\item{Path diagram}{Download SVG exports the current panel.}
\item{Analysis script}{In Model Comparison > Export, or Multiple Groups > Export & restore, inspect or download the reproducible R script. Load identical data as a data.frame named data before running it. The script checks the fingerprint (including the data representation and column order), preserves actual model syntax/options, refits the models and repeats valid tests. Ordinal generated syntax is retained. The basic script is not a replay of every interactive diagnostic.}
\item{HTML report}{In the same Export or Export & restore group, download an offline report. Includes specifications, assumptions, fit summaries, tests, warnings, available estimates, script and current optional diagnostics where computed. Multiple-group reports include the last valid diagram view or a default usable view. The interactive viewer can switch groups and export SVG without refitting. If local JavaScript is blocked, the tables and script remain readable. Optional diagnostics that were not computed or were invalidated are absent. Native refit recipes for optional diagnostics use the corresponding internal functions of this extension.}
\item{Save / restore}{Only for Multiple Groups. In Export & restore > Save / restore choose Download analysis (.json) after a completed analysis. Save .lvm and original data separately. The JSON contains settings, group labels, fingerprints, aggregate fit summaries, estimates and diagnostics, and the last valid diagram layout/preferences. It does not contain individual data rows or fitted R objects. Numeric tables are audit snapshots, not restored live fits. The JSON is limited to 5 MB. Version 1 snapshots remain readable; version 2 includes view and semTools information.}
}
}
\section{Restore a saved analysis}{
\enumerate{
\item Reopen the identical original data and .lvm model, preserve the estimation settings, and click Estimates.
\item Open More Results > Multiple Groups > Export & restore > Save / restore. Choose Saved analysis (.json) and inspect the status. Data, model and options must match; incompatible or invalid files are rejected.
\item Click Apply saved settings. Review the settings, confirm assumptions and Run multigroup analysis. Nothing is fitted automatically on applying settings.
\item Open Path diagram. If the saved stage and nodes remain valid, its last view is restored, including positions, selected groups, scale, zoom and display preferences. Re-export the SVG if needed.}
Save the original data, model, recipe and relevant outputs together. The restored fit is a new estimation, so differences across software versions are possible. A fingerprint is a consistency check, not a security signature. Uploaded JSON is parsed as data, not executed as R code. Aggregate results, names and labels can still be confidential. Treat exports as research records and review before sharing.}
\seealso{\code{\link{lavaangui-advanced}}, \code{\link{lavaangui-diagrams}}, \code{\link{lavaangui-advanced-validation}}}
