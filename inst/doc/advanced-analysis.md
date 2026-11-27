---
title: "Advanced analysis with lavaangui"
subtitle: "User guide for the proposed development contribution · 0.4.0.9000"
lang: en-US
---

**Purpose.** This guide documents the local development contribution validated on 26 November 2026. It adds two advanced results modules to the original graphical application. It is not an official upstream release. The original author, public functions, model editor, and `.lvm` model format are retained. All estimation remains in lavaan. The new modules do not change the main diagram or replace its fitted results.

The guide covers the final, grouped navigation. Earlier development notes may show intermediate tab names. Follow the paths in this guide instead. The public hosted version at [lavaangui.org](https://lavaangui.org/) may not contain this contribution.

## Quick start {#quick-start}

### Install and launch

Use the documented development checkout with its `DESCRIPTION` dependencies installed. For the optional ordinal multiple-group workflow, install semTools (at least 0.5-6):

```r
if (!requireNamespace("semTools", quietly = TRUE)) {
  install.packages("semTools")
}
```

A developer may launch from the source root using `pkgload::load_all()` followed by `lavaangui::lavaangui()`. For a normally installed package, run `lavaangui::lavaangui()` directly. `pkgload` is a separate development tool, not a new runtime dependency. The other workflows do not require semTools.

To find this installed guide and the example kit:

```r
help("lavaangui-advanced", package = "lavaangui")
guide <- system.file("doc", "advanced-analysis.html",
                     package = "lavaangui")
stopifnot(nzchar(guide))
utils::browseURL(guide)
kit <- system.file("advanced-examples", package = "lavaangui")
print(kit)
list.files(kit, recursive = TRUE)
```

In an extracted source project, the guide is `inst/doc/advanced-analysis.html` and the files are in `inst/advanced-examples/`. Copy the kit to a writable working folder before changing a model or saving results. All examples use simulated data. There is no need to supply real participant data.

### How to reach the modules

1. In the main application, use **File > Load Data** to open `banc_lavaangui.csv`.
2. Use **File > Load Model** to open the example `.lvm`. Inspect its syntax and estimation options.
3. Click **Estimates** and wait for a completed fit. Resolve estimation errors first.
4. Click **More Results**, then choose **Model Comparison** or **Multiple Groups**.
5. Configure, confirm the assumptions, run, and read the results. Exports are optional. Changing analysis controls resets confirmation; check it last.

The list of available variables in the main editor omits columns already represented by observed nodes in the diagram. They are not missing from the data. The grouping column must not itself be an indicator or predictor in the model. Importing an already fitted multiple-group lavaan object via `lavaangui(fit)` remains unsupported. `plot_lavaan(fit)` can visualize existing fitted models; its original layout mechanism is separate from this extension.

### Which workflow should I choose?

| Research question | Analysis entry | Supported scope |
|:--|:--|:--|
| Does restricting a path worsen fit? | Model Comparison | Simple nested regression or off-diagonal covariance restrictions; ML, MLR or ordinal WLSMV |
| Is the measurement model comparable across groups? | Multiple Groups > Measurement invariance (CFA) | Continuous first-order CFA; full or partial invariance; ML/MLR |
| Is an ordinal measurement model invariant? | Multiple Groups > Ordinal measurement invariance (WLSMV) | Fully ordinal simple CFA; full invariance with theta and Wu–Estabrook identification |
| Does a structural coefficient differ across groups? | Multiple Groups > Equal regressions (path model / SEM) | Continuous ML/MLR; all or selected regressions |
| Which constrained measurement parameter is problematic? | Advanced diagnostics > Constraint diagnostics | Simple continuous CFA, exactly two groups, ordinary ML, listwise deletion |
| How do indirect or total effects differ? | Advanced diagnostics > Indirect & total effects | Continuous recursive ML/MLR; free regressions fit |

For WLSMV comparison in the first row, two single-group model specifications are compared. The ordinal multiple-group sequence in the third row uses a different, explicitly generated identification scheme. Do not conflate the two workflows.

## Navigation map {#navigation}

**Model Comparison** has two results tabs:

| Main tab | What is inside |
|:--|:--|
| Fit table | Fit summaries, valid difference test if available, warnings and diagnostics; CSV |
| Export | Analysis script; HTML report |

**Multiple Groups** has five main results tabs:

| Main tab | What is inside |
|:--|:--|
| Fit table | Fit summaries, used observations by group, sequential comparisons and diagnostics; CSV |
| Selected estimates | Model, unstandardized or fully standardized parameter estimates and matching CIs; CSV |
| Path diagram | One group, two groups or two groups plus difference; layout and SVG |
| Advanced diagnostics | Constraint diagnostics; Indirect & total effects |
| Export & restore | Save / restore; Analysis script; HTML report |

The left panel contains the model/group settings and confirmation. The right panel contains results. `Expand viewer` in Path diagram can temporarily widen the diagram area. Open `Inspect current model and estimation settings` or `Inspect saved specifications A and B` to see the syntax and options.

## The synthetic example kit {#example-kit}

`banc_lavaangui.csv` contains **2,400 simulated observations**, 25 columns, no missing values, and two groups (A and B; 1,200 each) in `groupe`. The factor indicators `x1`–`x4`, `y1`–`y4` are continuous; `X`, `Z`, `M`, `Y` are observed structural variables; `u1`–`u3`, `v1`–`v3` are continuous latent-SEM indicators; `o1`–`o3`, `p1`–`p3` are four-category ordinal indicators. Keep the exact CSV and its order for comparisons and JSON restoration.

| File in `modeles/` | Intended use | Single-group df (design) |
|:--|:--|--:|
| `01_AFC_continue.lvm` | Continuous two-factor CFA | 19 |
| `02_Chemins_A_ML.lvm` | Less restricted paths, ML; group regression/effects | 1 |
| `03_Chemins_B_ML.lvm` | More restricted paths, ML | 2 |
| `04_Chemins_A_MLR.lvm` | Less restricted paths, MLR; robust effects | 1 |
| `05_Chemins_B_MLR.lvm` | More restricted paths, MLR | 2 |
| `06_Ordinale_A_WLSMV.lvm` | Less restricted ordinal CFA (includes `o2 ~~ p2`) | 7 |
| `07_Ordinale_B_WLSMV.lvm` | More restricted ordinal CFA; also ordinal group invariance | 8 |
| `08_SEM_latent_ML.lvm` | Continuous SEM with a latent direct regression | 7 |

`specifications.csv` records the syntax, estimator, ordinal variables and intended single-group df. The model files and CSV are unmodified copies of the contributor's teaching kit. Example-specific numerical values below come from the kit's independently calculated ML reference; the acceptance tests printed other numbers when run on their own simulated data. Always check your actual lavaan output.

## 1. Compare nested models {#nested}

### What is tested?

Model A is the less restricted model. Model B fixes or removes one or more independent free regressions or off-diagonal covariances in A. It must not introduce a new free parameter or change another fixed value. The models must describe the same variables, cases, grouping, exogenous roles, measurement specification and effective options. The automatic check is a conservative parameter-space check, not a general algorithm for model nesting. A and B may be saved in either order, but A must remain the less restricted specification.

| Estimator | Formal test | Important interpretation |
|:--|:--|:--|
| ML | Ordinary `lavTestLRT()` | Difference of ordinary chi-square statistics under the appropriate regularity assumptions |
| MLR | lavaan's fitted robust-test dispatch in `lavTestLRT()` | Do not subtract scaled chi-square values |
| WLSMV | `lavTestLRT(..., method="satorra.2000", a.method="delta", scaled.shifted=TRUE, test="scaled.shifted")` | Corrected scaled-shifted difference; do not subtract scaled values; AIC/BIC not applicable |

Both fits must converge, be admissible and have no captured fit warnings; incompatibilities, unsupported restrictions, nonpositive or mismatched df differences and invalid tests suppress formal inference. If the table reports incompatible fits, do not compare even AIC/BIC. Ordinary and robust fit indices are displayed where available. Missing robust measures are unavailable, not zero. The comparison requires the same cases and estimation settings; supported continuous missing-data options include listwise and ML/FIML when the actual fitted cases and options agree. Bootstrap is not supported. WLSMV requires declared ordered endogenous variables, automatic thresholds and scale parameters, listwise deletion and matching threshold/correlation moments and weights. Ordered exogenous variables and arbitrary threshold or scale changes are outside this scope.

### Walkthrough A: ML and MLR

Load the shared CSV and `02_Chemins_A_ML.lvm`. The two equations are `M ~ X + Z` and `Y ~ M + X`.

1. Estimate A, open More Results > Model Comparison, click **Clear saved models**, then **Save latest estimate as A**.
2. Close the results dialog. Load `03_Chemins_B_ML.lvm` (or remove the arrow X → Y in A). Do not reload or modify the CSV. Estimate B.
3. Return to Model Comparison, click **Save latest estimate as B**. Check the status and saved syntaxes. If loading a model has reset the session, use the in-place removal of the path instead.
4. Check **I have checked that B is nested in A** and click **Compare A and B**. Read the fit table and diagnostic text. Expected df: A = 1, B = 2; the difference is one. The omitted path is intentionally important in this kit.
5. Repeat with `04_Chemins_A_MLR.lvm` / `05_Chemins_B_MLR.lvm`. Keep estimator settings identical within the pair, not across the two separate comparisons. Compare ordinary and robust quantities and the actual corrected test. In **Export** you can read/download the R script or download an HTML report.

Check the guard: swap A and B, or save the same model to both slots. There must not be a valid nested difference test. Restore the intended pair before interpretation. A failed test is not evidence for equality.

### Walkthrough B: ordinal WLSMV

Repeat the workflow with `06_Ordinale_A_WLSMV.lvm` and `07_Ordinale_B_WLSMV.lvm`. Inspect that `o1`, `o2`, `o3`, `p1`, `p2`, `p3` are ordered in both models, WLSMV is selected and listwise deletion and automatic thresholds/scales are enabled. A includes the residual covariance `o2 ~~ p2`; B omits it. Expected df: 7 and 8. Read the **Scaled and Shifted Chi-Squared Difference Test** rather than the arithmetic difference of individual scaled chi-squares. The test column labeled `Chisq` may contain ordinary statistics, as indicated in lavaan's note. Report the appropriate model-specific scaled fit and corrected difference statistic. Do not use AIC/BIC in this comparison.

## 2. Continuous multiple-group measurement invariance {#continuous}

### Meaning and conditions

A grouping variable must be separate from the modeled variables with 2–10 nonblank groups. Missing or blank group labels are excluded. Group order is first occurrence in the data, not alphabetical; the first group is the reference. Each group must contain at least two rows before estimation, but that is only a technical guard; actual information and sample size must be adequate. Check the used observations for each fitted model. The continuous workflow requires finite numeric or missing model columns, ML/MLR, a first-order factor structure, ordinary first-marker scaling, automatic variances and a mean structure for the group fits. It rejects additional fixed loadings/variances, fixed nonzero paths, labels, defined effects, explicit intercept syntax, special constraints and higher-order factors. A CFA invariance sequence contains no structural regressions. The sequence below constrains **unstandardized** parameters.

| Stage | Cross-group equality imposed |
|:--|:--|
| Configural | Same measurement structure; parameters otherwise free subject to identification |
| Metric | Add equal factor loadings |
| Scalar | Add equal observed intercepts; nonreference latent means may become estimable |
| Strict (optional) | Add equal residual variances |

Interpret fit and changes in context of theory, identification and design. Subsequent stages condition on earlier restrictions. Rejection of configural fit is not cured by mechanically adding equality. Non-rejection of a difference test does not establish invariance. Review fit indices, uncertainty and substantive plausibility; no universal cutoff or automatic model-selection rule is implemented.

### Walkthrough C: full invariance

1. Load `01_AFC_continue.lvm` and the CSV; estimate. Open More Results > Multiple Groups.
2. Choose **Grouping column** = `groupe`; choose **Measurement invariance (CFA)**. Check **Include strict invariance (residual variances)**. Leave **Specify exceptions (partial invariance)** unchecked.
3. Check **I have checked the grouping variable, measurement type and assumptions** last; click **Run multigroup analysis**.
4. Read Fit table, observations used, sequential comparisons and diagnostics. The two groups have 1,200 observations each in the unmodified kit. Four models have expected df 38, 44, 50, 58. The intentionally unequal loading/intercept/residual variance makes the complete constraints poorly supported.

### Walkthrough D: partial invariance

The extension can release selected **nonmarker loadings** and **observed intercepts** between all groups using `group.partial`. Loadings released at the metric stage remain free at scalar and strict stages; intercept releases apply at scalar and strict. Partial invariance currently requires simple structure and at least two indicators per factor with both invariant loadings and intercepts. No residual variance can be released through these controls.

1. In the same analysis, check **Specify exceptions (partial invariance)**. Under **Loadings free across groups**, select `f1 =~ x3`. Under **Intercepts free across groups**, select `y3 ~ 1`.
2. Re-confirm and run. Read Partial metric, Partial scalar and Partial strict.
3. Compare full and partial sequences. In a nested sequence the df must increase by the expected number of independent restrictions. The kit's expected df are 38, 43, 48, 56 for these partial stages.
4. Uncheck the partial-invariance checkbox to return to the complete sequence. Re-confirm and run; retained selections do not apply while the box is unchecked.

| Stage | Full df | Full χ² (ref.) | Partial df | Partial χ² (ref.) |
|:--|--:|--:|--:|--:|
| Configural | 38 | 69.641 | 38 | 69.641 |
| Metric | 44 | 241.806 | 43 | 72.124 |
| Scalar | 50 | 682.143 | 48 | 73.284 |
| Strict | 58 | 863.641 | 56 | 239.255 |

These ML values are independent calculations on the bundled teaching CSV, not the numerical values printed by the acceptance suites on their separate fixtures. The partial metric and scalar restrictions have expected non-rejections (approximately p = .779 and .949); strict remains rejected. The configural fit must still be assessed on its own. Use actual native R output and the GUI diagnostics to verify results. Partial invariance selected from the same data is exploratory and should be justified and checked independently.

## 3. Ordinal multiple-group CFA {#ordinal}

Ordinal items represent ordered categories of underlying continuous responses. Thresholds, response location and scale are not separately identified without restrictions. The extension therefore constructs the sequence using `semTools::measEq.syntax()` with `ID.fac="std.lv"`, `ID.cat="Wu.Estabrook.2016"` (Wu & Estabrook, 2016), WLSMV, theta parameterization and listwise deletion. The graphic model supplies structure; marker scaling from the original editor is replaced by the generated identification. All latent covariances are free in the generated configural structure.

The supported prototype requires simple correlated first-order CFA, every indicator declared ordered, at least three indicators per factor, 4–12 observed categories after listwise deletion, the same category sets and at least five complete cases per category in each group. Five is a minimal guard, not a sample-size or information guarantee. Enable automatic variances and latent covariances; no correlated indicator residuals, cross-loadings, fixed additional parameters, mixed measurement, binary/three-category items, structural regressions, partial ordinal invariance or pairwise/FIML missingness. These cases are outside this implementation, not necessarily impossible scientifically.

### Walkthrough E: ordinal full invariance

1. Install semTools if needed and restart R. Load `07_Ordinale_B_WLSMV.lvm`, not model 06 (which includes a correlated residual). Confirm all six `o` and `p` indicators are ordinal and WLSMV is selected.
2. Estimate and open Multiple Groups, choose `groupe`, **Ordinal measurement invariance (WLSMV)**, and **Include strict invariance (ordinal response residual variances)**. Re-confirm and run.
3. Inspect the fit table and successive corrected tests. Do not predeclare whether a test will be significant; model 07 omits a residual covariance built into the kit, so fit may be imperfect.

| Stage | Constraint added | Expected df for model 07 |
|:--|:--|--:|
| Configural | Common structure and identification | 16 |
| Thresholds | Equal thresholds | 22 |
| Metric | Add equal loadings | 26 |
| Scalar | Add equal intercepts of underlying responses | 30 |
| Strict | Add equal underlying response residual variances | 36 |

These theoretical df (increments 6, 4, 4, 6) were also confirmed in the ordinal acceptance suite using a separate simple ordinal fixture. Review actual df and diagnostics on your own data. `Selected estimates` includes thresholds (`|`), intercepts/means (`~1`) and variances (`~~`). The diagram does not draw thresholds or intercepts. A raw ordinal coefficient can change scale across stages because identification changes. The script in `Export & restore > Analysis script` stores the generated syntax used for estimation, with theta/WLSMV. The native corrected test uses Satorra's 2000 scaled-shifted procedure, not a subtraction of corrected statistics. Robust fit indices may be unavailable for some stages.

## 4. Structural regression equality {#regressions}

Choose **Equal regressions (path model / SEM)** to fit a reference model with free regressions and a model with all or selected structural coefficients equal. The group measurement base is shared across the two fits. For latent models choose **Equal loadings (metric)** or **Equal loadings and intercepts (scalar)**, and justify that measurement restriction before testing structure. For observed path models the measurement option is ignored. Equality is tested on raw coefficients. A significant joint test does not identify which slope differs. Tests of coefficients chosen after seeing the results are exploratory.

### Walkthrough F: all, single and joint tests

1. Load `02_Chemins_A_ML.lvm`; estimate. Select `groupe` and Equal regressions.
2. Under **Regressions to constrain**, choose **All free regressions**. Confirm and run. Read Free regressions and Equal regressions (expected df 2 and 6 for the kit).
3. Change to **Only selected regressions**. Under **Regressions equal across groups**, choose `M ~ Z` only. Re-confirm and run; expected df difference = 1. The other coefficients remain free.
4. Select `M ~ Z` and `Y ~ M` jointly. Re-confirm and run; expected df difference = 2. Repeat with model 04 for MLR.

For the latent example `08_SEM_latent_ML.lvm`, `vF ~ uF` is a direct structural regression. The example includes `u2 ~~ v2`. Establish a defensible common scale before comparing the regression. It is not a latent mediation example. Partial measurement releases in the structural workflow, special labeled constraints and ordinal structural equality are outside this implementation.

## 5. Explore constraints with score tests and EPC {#scores}

The score module is a diagnostic, not an automatic model-modification procedure. It is restricted to warning-free, converged, admissible simple continuous CFA (at least three indicators per factor), two groups, ordinary ML with standard SEs and listwise deletion, and at most 100 explicit equality constraints. The additional Browne residual normal-theory statistic supplied by lavaan 0.7-3 does not turn the ordinary ML fit into MLR. Robust and ordinal score tests are not offered.

From a constrained fitted CFA, select **Advanced diagnostics > Constraint diagnostics**, choose **Fitted model with equality constraints**, then click **Compute score tests and EPC**. The table lists candidate loading, intercept and residual variance equality constraints, chi-square score, df, p, Holm-adjusted p and status. The adjustment includes the number of all listed constraints, including unavailable ones. Choose **Choose a tested constraint** to see each group's current estimate, EPC and Expected (estimate + EPC). Each score/EPC is computed by `lavTestScore(release = id, univariate = TRUE, epc = TRUE, standardized = FALSE)` with one equality released hypothetically; all others remain. A release violating the two-common-anchor safeguard is not evaluated. EPC is a local approximation, not the actual coefficient of a refitted model. Very small p-values may print as 0; do not report them as exactly zero.

### Walkthrough G: discover the designed differences

Use the continuous CFA kit. Run the complete sequence, then inspect Metric for `f1 =~ x3`. Release that loading only, rerun, then inspect Partial scalar for `y3 ~ 1`. Release both and inspect Partial strict for `y4 ~~ y4`. Read the full table; other constraints may also be significant when a true violation is retained. Do not assume the first displayed row is the only relevant parameter. The strict residual-variance diagnosis is informative, but the interface cannot free that variance across groups in the current partial workflow. Refit only theoretically justified partial models, using the available controls, and seek independent evidence. Use **Download score table (CSV)** and **Download selected EPC (CSV)** to retain the diagnostics.

## 6. Compare indirect and total effects {#effects}

For a recursive directed path model, the direct effect is the length-one path coefficient; each indirect effect is the product of coefficients along one directed path of length at least two; total indirect is their sum and total is direct plus total indirect. If there is no direct or indirect path of that kind, the corresponding component is a structural zero (not a hypothesis-test result). Covariances are not directed mediation paths.

The module uses only the **Free regressions** fit in the continuous ML/MLR group workflow. It does not refit or use the constrained model. It enumerates paths in the common acyclic graph (at most 30 structural variables and 100 directed paths). It calculates estimates using raw regression coefficients and their full fitted covariance. With gradient `g` of an effect and covariance matrix `V`, delta-method variance is `g^T V g`. For the difference second minus first, use the difference of gradients, retaining cross-group covariance where present. Normal 95% intervals and unadjusted two-sided Wald p-values are reported. A missing SE/p-value is not proof of equality. A warning-free admissible fit and aligned covariance indices are required; no cycles, standardized-effect tests, ordinal effects or bootstrap are implemented. Normal intervals can be poor for asymmetric indirect-effect distributions. A path product is associational unless identification, temporal ordering and confounding assumptions support causal interpretation.

### Walkthrough H: X or Z through M to Y

1. Use `02_Chemins_A_ML.lvm`, run Equal regressions, and inspect the Free regressions fit.
2. Choose **Advanced diagnostics > Indirect & total effects**. Select Source (X) = `X`, Target (Y) = `Y`, First group = A, Second group = B. Click **Compute effects (second minus first)**.
3. The table contains the two group effects and the contrast for each component. Repeat with Source = `Z`. There is no direct Z → Y path. The direct row is a structural zero; Z's total equals its indirect effect. Reverse the groups: sign changes, SE and p do not.
4. Download **effects (CSV)**. Repeat with MLR model 04; the point estimates should be close while robust SEs may differ. Try an invalid same-group or no-directed-path contrast; it should be refused.

Independent approximate ML reference values for the kit, not the separate acceptance-test fixture:

| Effect | A | B | B − A |
|:--|--:|--:|--:|
| Direct X → Y | .355586 | .427134 | .071548 |
| Indirect X → M → Y | .258823 | .392097 | .133274 |
| Total X → Y | .614409 | .819231 | .204822 |
| Indirect/total Z → M → Y | .124485 | .526580 | .402095 |

Use the bundled native script or actual fitted output for exact SEs, CIs and p-values. The script includes separate native lavaan labeled models with defined parameters (`:=`) to verify these effects. Such labels and definitions are not supported inputs to the advanced GUI group workflow.

## 7. Inspect estimates and diagrams {#diagrams}

**Selected estimates:** choose a usable fitted Model and Unstandardized or Fully standardized. The latter uses `standardizedSolution()` (std.all), including its matching uncertainty, rather than appending raw SEs to standardized estimates. CSV exports contain the full selected table, including unrounded values. Group labels appear alongside lavaan's parameter rows. Ordinal thresholds and intercepts are available in the table even though they are not drawn.

**Path diagram:** choose **Fitted model** and **Display**: One group, Compare two groups, or Two groups + difference (second minus first). Choose Group and Second group. Coefficients can be unstandardized or fully standardized (`std.all`). The third panel subtracts corresponding estimates before rounding. NA is unavailable, not zero. Equal raw coefficients can have unequal standardized values. Signed differences are descriptive, not tests of significance. Use formal equality tests or model-based contrasts for inference, and compare raw scales only where meaningful.

Rectangles denote observed variables, ellipses latent variables. Single-headed arrows are loadings/regressions, double-headed arrows are covariances. Use Covariances and Variances to choose what to display. Layout offers Compact CFA (when applicable), Left to right, or Top to bottom. Drag variables to arrange the diagram; the same coordinates are used in every displayed panel. Keyboard: focus a node, use arrow keys (Shift for larger steps). Use Zoom, Decimals, Reset layout and Expand viewer for clarity. **Download SVG** on each panel exports its current vector drawing. The diagram does not change any fitted result or the main editor. For the original `plot_lavaan()` viewer, consult its own help and `export_plot()`; the two layout systems are separate.

## 8. Reproducible exports and restoration {#exports}

| Output | Where to find it | What it contains / does not contain |
|:--|:--|:--|
| CSV | Fit table, Selected estimates, diagnostics/effects | Numeric tables; no fitted model object |
| SVG | Path diagram, each panel | Current vector drawing, not a data or model file |
| `.R` | Analysis script, under Export or Export & restore | Model syntax, actual options, original data fingerprint, refit and valid tests |
| `.json` | Multiple Groups > Export & restore > Save / restore | Settings, audit tables and last valid diagram view; no individual rows or fitted objects |
| `.html` | HTML report, under Export or Export & restore | Offline readable report, optional interactive multiple-group diagram; no individual rows |

### Save and restore an analysis

Open `Path diagram` before saving if you want the last view recorded. For example, choose the scalar stage, two groups plus difference, B then A, std.all, 125%, four decimals, move two nodes and set the covariance/variance toggles. Open **Export & restore > Save / restore**. Look for **Diagram view ready to save**, verify the model, group order, scale and zoom, then **Download analysis (.json)**. Keep the `.lvm`, original CSV and JSON together. Version 2 stores the last valid view, not every model's individual layout. Version 1 remains readable; it has no view. A snapshot is limited to 5 MB. It records aggregate fit results, group labels/counts, estimates, diagnostics, settings, version information and model/data fingerprints. Old numeric tables are for audit, not restored live results.

To restore, reopen the same CSV and `.lvm` with identical estimation settings, estimate it, open Multiple Groups > Export & restore > Save / restore, choose **Saved analysis (.json)** and read the status. **Apply saved settings** only populates the controls. Review, confirm and **Run multigroup analysis** to obtain fresh fits. Open Path diagram and check the saved stage, groups, coordinates and view settings. If a saved stage is no longer usable, the view may be declined. Any modified data or specification is rejected. Do not edit fingerprints to force acceptance. Refit may differ after software upgrades.

### Read or run the R script

Choose Analysis script under the relevant export tab. You may read/copy the text without downloading. If downloading, load the identical original data as a data.frame named `data` before running it. For the synthetic CSV, start with the same reader as the application:

```r
data <- as.data.frame(readr::read_csv("banc_lavaangui.csv",
                                     show_col_types = FALSE))
# Review the exported script first. Then source its actual local file.
# source("multigroup-analysis.R")  # replace with the file name saved
```

The fingerprint depends on the actual imported data representation, column order and attributes, not just values; match the original loader and do not disable the check if it fails. The script stores the fitted specifications (including ordinal generated syntax), refits, reports convergence and post-checks, repeats tests that were valid in the GUI and prints session information. It does not automatically rerun every optional exploratory diagnostic. Keep the source data separately. The extension does not execute imported JSON or arbitrary R code from a report.

### Offline HTML report

After running an analysis (and any optional diagnostics you want to include), choose **HTML report** and click **Download HTML report**. It includes specifications and assumptions, fit measures, group counts where relevant, tests and warnings, available raw/standardized estimates, current score/EPC or effects if computed, and reproducible R syntax. In Multiple Groups, the last valid diagram view (or a default usable view) is embedded in the file. The diagram reader works without Shiny or R, can change groups and export SVG, and performs no new estimation. If local JavaScript is blocked, tables and script remain readable. The comparison report does not have a multigroup diagram. Optional analyses absent or invalidated by changing the selection are not included. Recipes for optional diagnostic refits use internal functions from this same development contribution; they are not new public API. Review all notes before sharing.

**Confidentiality.** These exports contain no individual data rows by design, but group labels, variable names, group sizes, estimates, warnings and data fingerprints can be confidential. The fingerprint checks consistency, not authenticity. Use appropriate storage and sharing procedures.

## 9. Verify and reproduce {#validation}

### Native R walkthrough

The installed example script uses the native lavaan API and optional semTools, not the extension's internal helpers. It prints fit tables, corrected tests, selected native scores/EPC and defined effects. From the installed package:

```r
source(system.file("advanced-examples", "reference-examples.R",
                   package = "lavaangui"))
```

From a source checkout root:

```sh
Rscript inst/advanced-examples/reference-examples.R
```

A CSV path may be supplied as the first Rscript argument. The script reads the exact teaching data and does not overwrite files. Ordinal invariance is skipped if semTools is unavailable. This is a newly documented reference walkthrough; its execution should be checked in R. It is separate from the previously passed acceptance scripts, which use native-lavaan comparisons and simulated/built-in fixtures.

### Acceptance status

On 26 November 2026 the contributor executed the six consolidated R suites on Windows 11 x64, R 4.6.0 and lavaan 0.7-3. All returned exit code 0 after two compatibility corrections. A notice that lavaan was built under R 4.6.2 did not prevent the tests from passing. The evidence is in the author review package, not invented example values.

| Suite | Final result | Coverage |
|:--|:--|:--|
| `advanced_analysis.R` | PASS | ML/MLR nesting, df classes, marker scaling, complete/partial invariance, group regression equality, script replay and refusals |
| `advanced_diagrams.R` | PASS | 318 parameter-to-edge matches from actual fitted models |
| `advanced_wlsmv_projects.R` | PASS | Ordinal WLSMV corrected comparison, settings restore and guard checks |
| `advanced_ordinal_views.R` | PASS | Five ordinal stages, corrected tests, script, JSON v1/v2 and view validation |
| `advanced_score_differences.R` | PASS | Ordinary ML options, score and single-release EPC, anchor guards and difference JSON |
| `advanced_effects_reports.R` | PASS | Native ML/MLR effects/contrasts, covariance for shared paths, actual HTML report serialization and navigation |

The ordinal test fixture produced df 16, 22, 26, 30, 36. The diagnostic test fixture detected the intended `f1=~x3`, `y3~1`, and `y4~~y4` violations. The single-group WLSMV fixture produced a corrected difference statistic of 52.343 with 1 df. These are results on the acceptance fixtures; do not use them as the exact teaching CSV results.

From the source project root, install dependencies including semTools, then run:

```sh
Rscript tests/manual/run_advanced_validation.R
```

It creates a new timestamped `advanced-validation-*` directory at the root with `summary.csv`, logs and session information. A nonzero exit code identifies failed suites. The existing passing code and tests are preserved unchanged by the documentation increment. Browser tests with simulated Shiny inputs and contributor trials are additional evidence, not a full end-to-end Shiny matrix. The documented package still needs installed-help checks, `R CMD check`, further interactive/accessibility checks and cross-platform review before an upstream release.

### Practical acceptance checklist

- Open an existing `.lvm`, estimate and ensure the original editor behaves as before.
- Check ML, MLR and WLSMV A/B, including reversed/non-nested pairs; no invalid formal test should be presented.
- Compare full and partial continuous sequences, check the ordinal sequence and category/anchor safeguards.
- Test all, individual and joint regression restrictions, and justify latent measurement base.
- Check raw/std estimates, group order and difference direction, synchronized dragging and SVG export.
- Save/restore JSON including last view and reject changed data; recompute scores and effects; open HTML offline.
- Check small/large windows and keyboard navigation. Confirm new data/settings invalidate stale results. Save logs, actual versions and reproducible syntax.

## 10. Troubleshooting {#troubleshooting}

| Symptom | What to check |
|:--|:--|
| No completed estimate with current data | Return to the main diagram, estimate, wait; check data and errors. |
| Group column not listed | It must have 2–10 nonblank values and be absent from the modeled variables. |
| Partial options missing | Choose continuous CFA mode and check Specify exceptions (partial invariance). Marker loading is intentionally excluded. |
| Please confirm assumptions | Complete all selections, then check the confirmation box again. |
| Latent variances/marker warning | Use ordinary first-marker scaling and automatic variances; do not explicitly fix latent variances or nonmarker loadings. |
| No inferential test | Read the diagnostic. Check nesting, identical data/options, observed variables, cases, warnings, admissibility and df. Do not remove the safeguards. |
| Ordinal module rejected | Verify semTools, ordered declarations, WLSMV, category counts in every group, automatic variances/covariances and simple CFA. |
| Score unavailable | Use two-group simple continuous CFA with ordinary ML/standard SE and listwise deletion. |
| Effect unavailable | Run Equal regressions, inspect the warning-free Free regressions fit and choose distinct groups and a valid directed path. |
| Missing SVG or crowded diagram | Select a usable model, scroll/zoom, expand or move nodes; save individual SVG panels. |
| Save / restore or Analysis script missing | Look under Export & restore. In Model Comparison look under Export (no group JSON there). |
| JSON fingerprint mismatch | Restore identical original model, options and data representation/order, estimate first; use the saved file, not a manually edited recipe. |
| Offline diagram blocked | Open the HTML in a local browser allowing trusted local JavaScript; tables remain readable. |

## References and further reading {#references}

- Karch, J. D. (2025). *lavaangui: A Web-Based Graphical Interface for Specifying Lavaan Models by Drawing Path Diagrams*. Structural Equation Modeling: A Multidisciplinary Journal. [doi:10.1080/10705511.2024.2420678](https://doi.org/10.1080/10705511.2024.2420678).
- Wu, H., & Estabrook, R. (2016). Identification of confirmatory factor analysis models of different levels of invariance for ordered categorical outcomes. *Psychometrika, 81*, 1014–1045. [doi:10.1007/s11336-016-9506-0](https://doi.org/10.1007/s11336-016-9506-0).
- Satorra, A. (2000). Scaled and adjusted restricted tests in multi-sample analysis of moment structures. See the method documentation in `help("lavTestLRT", package="lavaan")` for the implementation and further references.
- lavaan documentation: `lavTestLRT`, `lavTestScore`, `parameterEstimates`, `standardizedSolution`, `lavInspect`, `fitMeasures`; [multiple groups](https://lavaan.ugent.be/tutorial/groups.html), [categorical data](https://lavaan.ugent.be/tutorial/cat.html), [mediation](https://lavaan.ugent.be/tutorial/mediation.html).
- semTools: [`measEq.syntax`](https://search.r-project.org/CRAN/refmans/semTools/html/measEq.syntax.html), available as an optional dependency for the ordinal sequence.

See the installed R help index (`help(package="lavaangui")`), the overview topic `lavaangui-advanced`, `NEWS.md` and the technical contribution dossier for the proposed extension and remaining review tasks.
