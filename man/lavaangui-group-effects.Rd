\name{lavaangui-group-effects}
\alias{lavaangui-group-effects}
\title{Compare Direct, Indirect and Total Effects Between Groups}
\description{Computes unstandardized regression-path effects from the Free regressions fit in the continuous multiple-group workflow.}
\details{
Run Equal regressions. In Advanced diagnostics, open Indirect & total effects. Select Source (X), Target (Y), First group and Second group, then Compute effects (second minus first). The groups and variables must be distinct, and a directed regression path must connect the variables. This calculation does not use the equality-constrained structural fit or refit any model.

The direct effect is the coefficient of the length-one directed path (if present). Every directed path of length two or longer contributes the product of its regression coefficients. Total indirect sums those products; Total adds the direct effect. A structural zero (no path) is not an estimated null parameter. Covariance arrows are not directed mediation paths. When only one indirect path exists, that row and Total indirect are identical by definition.

For an effect h with gradient g and full estimated free-parameter covariance matrix V, its delta-method variance is \eqn{g^T V g}. For the contrast second minus first, the gradient is the difference of the two effect gradients, so shared parameters and cross-group covariances are retained. The table provides estimates, standard errors, normal 95\% confidence intervals and unadjusted two-sided Wald p-values. An absent or non-estimable SE is not evidence of equality. Inverse group order reverses the contrast sign, not its SE or p-value.

The supported scope is converged, admissible, warning-free recursive continuous ML/MLR fits with no structural equality constraints in the reference fit, matching directed regression graphs and identifiable covariance indices. Limits: 30 structural variables and 100 directed paths, no feedback, ordinal effects, standardized contrasts or bootstrap. For latent effects, justify a common measurement scale. Regression-path products are model-based associations; causal mediation requires temporal, design and confounding assumptions beyond the software. Normal delta intervals may poorly approximate asymmetric indirect-effect sampling distributions.
}
\section{Example}{Use model 02_Chemins_A_ML.lvm and groupe. Choose X then Y, groups A and B, compute. Compare direct X to Y, X to M to Y, total indirect and total. Choose Z then Y to see a structural zero direct effect. Repeat with MLR model 04. The native R example computes the same effects using explicitly group-labeled parameters and defined parameters (those labels are for the separate native R example, not for the GUI workflow).}
\seealso{\code{\link{lavaangui-multiple-groups}}, \code{\link{lavaangui-analysis-export}}, \url{https://lavaan.ugent.be/tutorial/mediation.html}}
