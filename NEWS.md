# Proposed advanced-analysis contribution (development branch)

Development candidate for maintainer review; not an upstream release. Original author metadata, license, public API and editor behavior are retained.

- Add Model Comparison under More Results: snapshot A/B specifications, conservative nested restriction checks, ML/MLR and simple ordinal WLSMV comparisons, CSV, reproducible R scripts and offline reports.
- Add Multiple Groups: continuous complete and partial CFA invariance, all/selected structural regression equality, and full ordinal CFA invariance using optional semTools and Wu--Estabrook identification.
- Add estimates with matching raw/standardized intervals, synchronized group-specific diagrams, descriptive difference panels, SVG exports, companion JSON settings and last-view restoration.
- Add ordinary ML two-group measurement score/EPC diagnostics and continuous recursive ML/MLR indirect/total effects with full-covariance delta-method group contrasts.
- Group results in five main tabs and provide explicit partial-invariance controls and scoped typography.
- Correct lavaan.vector degrees-of-freedom comparisons and recognize lavaan 0.7-3's additional Browne residual test in ordinary ML score diagnostics; retain scope checks.
- All six non-interactive R acceptance suites passed on 26 November 2026 and again on 27 November 2026 in the fork based on commit `29636db`. The second run used Windows 11, R 4.6.0, lavaan 0.7-3 and semTools 0.5-10, with renv autoloading temporarily disabled. All 13 Rd files parsed and the native reference walkthrough completed. Validation with the upstream lockfile, installed-help checks, full package checks, cross-platform checks and live Shiny acceptance remain review tasks.
- Add native R help topics, offline English guide, exact synthetic example data/models and a native-lavaan walkthrough. The final documentation increment did not change runtime function bodies, statistical routines, JS or the acceptance suites.

See `ADVANCED-EXTENSION-CHANGELOG.md` for development history and `inst/doc/advanced-analysis.html` for current workflows and limits. The existing main app does not import fitted multiple-group lavaan objects for editing.

# lavaangui 0.4.1
- Bugfix: Math in display labels (e.g., Greek letters, subscripts) was garbled when exporting the diagram to PDF (#105).

# lavaangui 0.4.0
- Added: `export_plot()` function to export the graph as PNG, JPEG, SVG, or PDF
- Added: `plot_lavaan()` now saves and restores the layout and viewport between sessions.
- Added: Full composite variable support — composites are their own class with a hexagonal node shape.
- Added: Lavaan labels and display labels are now distinguished; display labels can be edited independently. Display labels support simple math/LaTeX-style notation and multi-line text.
- Added: Option to hide undirected edges.
- Added: Reset button to restore the default state.
- Added: Variable selector for model templates validates that selected variables are still available.
- Added: Package-level documentation page.
- Bugfix: Grid options were not saved with the model file.
- Bugfix: Serialization/state bug in model save and load.
- Bugfix: Minor bug in `lavInspect` output handling.
- Bugfix: Divider in context menu was not rendered correctly.
- Bugfix: Guard added for undefined nodes in cycle detection.
- Security: Removed use of `eval()` on the server side.
- Appearance: Removed the linked/not-linked visual distinction for observed nodes.
- Developer: Detection of local vs. shinyapps.io deployment now uses the `where` command; Heroku support removed.

# lavaangui 0.3.2
- Bugfix: App could crash when hidding edges and trying to move the graph

# lavaangui 0.3.1
- Bugfix: New lines in syntax are now more consistent
- Bugfix: Changed support of composites to match lavaan 0.6-20, lavaan version >= 0.6-20 is now required.
- Bugfix: Directed edges from models imported via `lavaangui()` can now be reverted and set to undirected
- Bugfix: p values stars are shown again (was broken since 0.2.5)
- Bugfix: was possible to create edge in `plot_lavaan`
- Developer: added more playwright tests
- Appearance: Made context menu for edges a bit prettier
- Appearance: `results` is now named `fit`


# lavaangui 0.3.0
-	Added: Allow renaming of nodes and edges in plot_lavaan.
-	Added: Change fixed values in the context menu.
-	Added: Directed arrow from latent to observed variable can be marked as a factor loading or regression coefficient.
-	Added: Line style can be changed between solid, dashed, and dotted.
- Added: Latent variables can also be displayed as hexagons
- Bugfix: Width of dialog windows is now more reasonable. Was caused by a CSS bug.
- Bugfix: Indentation of intercept syntax is correct now.
- Bugfix: Hotkey that deactivates drawing is now listened to everywhere.
- Bugfix: plot_lavaan now works also if do.fit = FALSE.
- Playwright testing is only done on the local version now.
- Switched to lavaan 0.6-20 for the webserver versions.

# lavaangui 0.2.6
- Bugfix: `plot_lavaan()` after `efa` is now working
- Bugfix: Avoid crashing when data("estimates") for an edge is undefined
- Added: renv for deployed version
- Added: display of `lavaan` version number in app


# lavaangui 0.2.5
- Bugfix: Standardized results were not displayed correctly for fixed edges, see https://github.com/karchjd/lavaangui/issues/83

# lavaangui 0.2.4
- Bugfix: Label move, node move, and edge bend interactions no longer cause issues.
- Bugfix: Invalid variables can no longer be entered via the drag-and-drop menu.
= Bugfix: Disabled king edges due to conflicts with the label move algorithm.

# lavaangui 0.2.3
- First version automatic undirected edge bend
- Multiple bug fixes

# lavaangui 0.2.2
- Renamed Download to Save
- Fixed bug that enforced fixed values to be integers

# lavaangui 0.2.1
Multiple bug fixes:
- Undirected arrows no longer change orientation when added to the user model.  
- Renamed "Automatically.." to "Automatically...".  
- Fixed a bug in the code for changing the orientation of loops.

# lavaangui 0.2.0-online
- Enabled the cancel button only for shinyapps.io again

# lavaangui 0.2.0
- Temporarily disabled the cancel button on shinyapps.io due to technical reasons.
- Bugfix: Bootstrap + ordered now works.
- Overly long node names are now automatically abbreviated.
- Removed buggy edge reconnection feature.
- Moved "Mean" options menu into the "Automatically" menu to better convey its functionality.
- Ordinal variables now work for all tested models; included the `auto.th` and `auto.delta` options; added DWLS estimator.
- Data upload now supports a wider range of CSV files.
- Added an auto-save feature to prevent data loss on timeout.
- Data preparation for download has been speed up by 10x.
- Bugfix in hashing functions for caching.
- Improved file upload, now with a status bar.
- The hide/show status of elements is now saved to the file.
- Renamed `plot_interactive` to `plot_lavaan`.
- `plot_lavaan`: Bugfix for multiple groups.
- Removed dependencies on `qgraph` and `htmlwidgets`.

# lavaangui 0.1.2
- Initial CRAN submission.
