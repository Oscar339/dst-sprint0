# Survival analysis: literature review — Alex

29 Sep 2026. Background for the survival-model idea in section 6 of
[`01-review-and-next-steps.md`](01-review-and-next-steps.md). This is a
literature review: nothing here has been run on our data. The build itself is
Sprint 1 material (see `Oscar/06-07-plan.md`).

## 1. Why survival analysis for credit

A standard credit model asks **whether** a borrower defaults within a fixed
window. Survival analysis asks **when**. Banasik, Crook & Thomas (1999) made
this case for credit scoring directly, in a paper titled *Not if but when will
borrowers default*. Modelling time to default:

- uses customers who have not defaulted *yet* (censored cases) instead of
  forcing them into "good";
- lets covariates change over time, e.g. each month's repayment status
  (Bellotti & Crook, 2013);
- gives a default probability for any horizon from one model, which matters
  for profit and for lifetime loss estimates (Stepanova & Thomas, 2002).

## 2. Basic concepts

Let $T$ be the time until the event (here, default). The standard references
are Klein & Moeschberger (2003) and Kalbfleisch & Prentice (2002).

| Quantity | Definition | Meaning |
|---|---|---|
| Survival function | $S(t) = P(T > t)$ | Probability of no default by time $t$ |
| Hazard (continuous) | $h(t) = \lim_{\delta \to 0} P(t \le T < t + \delta \mid T \ge t) / \delta$ | Instantaneous default rate among those still at risk |
| Hazard (discrete) | $h(t) = P(T = t \mid T \ge t)$ | Probability of defaulting in month $t$, given no default before |
| Cumulative hazard | $H(t) = \int_0^t h(u)\,du$ | Continuous time: $S(t) = e^{-H(t)}$ |

In discrete time, survival is a product of monthly "non-default" probabilities:

$$S(t) = \prod_{s \le t} \bigl(1 - h(s)\bigr).$$

**Censoring.** A customer is *right-censored* if the data ends before they
default: we know only that $T$ exceeds the last month observed. The usual
assumption is that censoring is non-informative, i.e. unrelated to the risk of
default. When censoring comes only from the end of the data, as in ours, that
assumption is reasonable (Klein & Moeschberger, 2003).

**Truncation.** If people enter the study only after some time has already
passed, the data are *left-truncated* (delayed entry). Our customers already
had accounts before April 2005, so this applies (section 7).

## 3. Kaplan–Meier and related non-parametric tools

**Kaplan–Meier estimator** (Kaplan & Meier, 1958). At each event time $t_i$,
let $d_i$ be the number of defaults and $n_i$ the number still at risk. Then

$$\hat S(t) = \prod_{t_i \le t} \left(1 - \frac{d_i}{n_i}\right).$$

Censored customers count in $n_i$ until they leave, so they contribute
information without being treated as "good". Greenwood's formula gives the
variance of $\hat S(t)$ (Klein & Moeschberger, 2003).

**Nelson–Aalen estimator** (Nelson, 1972; Aalen, 1978) estimates the
cumulative hazard instead: $\hat H(t) = \sum_{t_i \le t} d_i / n_i$.

**Log-rank test** (Mantel, 1966). This tests whether two or more groups (e.g.
credit-limit bands) have the same survival curve, by comparing observed and
expected defaults at each event time.

These are descriptive: they need no model and show the shape of default over
time.

## 4. Cox proportional hazards model

Cox (1972) models the hazard as a baseline hazard times a covariate effect:

$$h(t \mid x) = h_0(t)\, \exp(\beta^\top x).$$

- $h_0(t)$ is left unspecified and $\beta$ is estimated by **partial
  likelihood**, so no distribution for $T$ has to be assumed.
- $\exp(\beta_j)$ is a **hazard ratio**: the multiplicative change in default
  risk per unit of $x_j$, at every time.
- **Proportional hazards** is an assumption: hazard ratios must be constant
  over time. It is checked with Schoenfeld residuals (Grambsch & Therneau,
  1994).
- **Ties.** Monthly data has many defaults in the same month. Efron's (1977)
  approximation handles this better than the default Breslow method.
- **Performance** is usually measured by the concordance index, the survival
  version of AUC (Harrell et al., 1982).

## 5. Discrete-time survival models

Our data is monthly, so time is discrete. The discrete-time hazard model fits
this directly (Allison, 1982; Singer & Willett, 1993; Tutz & Schmid, 2016):

$$\operatorname{logit} h(t \mid x_{t}) = \alpha_t + \beta^\top x_{t}.$$

- $\alpha_t$ is one intercept per month: the baseline hazard, left free.
- $x_t$ can change from month to month (time-varying covariates).
- **Estimation is ordinary logistic regression** on a *person-period* table
  (one row per customer per month at risk). Allison (1982) shows the
  likelihood factorises this way, so standard software gives valid
  estimates.
- Using a **complementary log-log** link instead of the logit gives the
  grouped-time version of the Cox model, so $\beta$ are again log hazard
  ratios (Prentice & Gloeckler, 1978).

Shumway (2001) used exactly this model, a logit on firm-years, to forecast
bankruptcy. He argued that single-period models give biased and inconsistent
probability estimates, while the hazard model does not. Bellotti & Crook
(2013) use the same discrete framework for credit cards.

## 6. Survival analysis in credit scoring

| Paper | Data | Model | What it shows |
|---|---|---|---|
| Narain (1992) | Loan applications | Survival models | Early application of survival analysis to credit granting |
| Banasik, Crook & Thomas (1999) | Personal loans | Proportional hazards vs logistic regression | Argues for modelling *when* borrowers default, not only *whether* |
| Stepanova & Thomas (2002) | Personal loans | Cox PH | Survival methods for default and early repayment, with profit in mind |
| Bellotti & Crook (2009) | Large credit-card sample | Cox PH with macroeconomic covariates | Interest rates and unemployment enter as time-varying covariates |
| Bellotti & Crook (2013) | Credit cards | Discrete-time survival with behavioural and macroeconomic variables | Significantly better fit and default forecasts at account and portfolio level; usable for stress testing |
| Dirick, Claeskens & Baesens (2017) | 10 credit datasets (Belgium, UK) | AFT, Cox, Cox with splines, mixture cure models | Benchmark: spline-based methods and the single-event mixture cure model perform well |
| Botha, Verster & Scheepers (2025) | Loan data | Recurrent-event Cox models (Andersen–Gill, PWP) | Tutorial with a codebase; models customers who default more than once |

Bellotti & Crook (2013) is the closest published model to what we would build:
discrete time, credit cards, monthly behavioural covariates.

## 7. How this would apply to our data

**What we have** (Taiwan data, cleaned in `Oscar/05-cleaning`): six months of
repayment status, bills and payments (Apr–Sep 2005), and one default label
(Oct 2005). From section 6 of `01-review`: there is no account age and no
default date.

### Step 0: time axis

Months become time steps:

| Month | Apr | May | Jun | Jul | Aug | Sep | Oct |
|---|---|---|---|---|---|---|---|
| $t$ | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
| Status | `PAY_6` | `PAY_5` | `PAY_4` | `PAY_3` | `PAY_2` | `PAY_1` | default label |

Time 0 is the start of the data, **not** the account's opening date. Every
customer entered before April, so this is calendar time with delayed entry
(left truncation, section 2). With no account age we cannot correct for it,
so we state it as a limitation.

### Step 1: define the event

The data has no default date, so the event has to be built from repayment
status:

- **Proposed event:** the first month with `PAY_t` ≥ 2 (two or more months
  behind), or default in October ($t = 7$), whichever comes first.
- Treat `PAY` values −2, −1 and 0 as "not late" categories, not numbers
  (`data/README.md`).
- **Check:** repeat with a threshold of 1 month behind, and see whether the
  conclusions change.

### Step 2: risk set and censoring

- Customers who are already ≥ 2 months behind in April had their event before
  the data starts. We cannot tell when, so **exclude them** (or analyse them
  separately) and report how many there are.
- Customers with no event by October are **right-censored** at $t = 7$. The
  censoring comes only from the end of the data, so it is non-informative.

### Step 3: Kaplan–Meier (descriptive)

- Estimate $\hat S(t)$ for everyone, and by group: credit-limit quartile,
  April status, education.
- Use the log-rank test for differences between groups.
- This shows *when* people fall behind across the six months, which the
  single-label models in `Oscar/04` and `06` cannot show.
- Tools: `lifelines` `KaplanMeierFitter` and `logrank_test`
  (Davidson-Pilon, 2019).

### Step 4: person-month table

- **One row per customer per month at risk,** up to and including their event
  month. At most 30,000 × 7 = 210,000 rows.
- **Columns:** customer ID; month $t$; event indicator (1 only in the event
  month); static covariates (`LIMIT_BAL`, `AGE`, `SEX`, `EDUCATION`,
  `MARRIAGE`).
- **Time-varying covariates lagged by one month:** status, bill, payment and
  utilisation (bill / limit) from month $t-1$.
- **Why the lag:** status in month $t$ defines the event, so using it as a
  covariate would leak the answer.
- Check the UCI description for which month each `BILL_AMT` and `PAY_AMT`
  column refers to before lagging them.

### Step 5: discrete-time hazard model

Fit $\operatorname{logit} h(t \mid x_{t-1}) = \alpha_t + \beta^\top x_{t-1}$
by logistic regression on the person-month table (section 5).

- Month dummies give $\alpha_t$.
- A complementary log-log link makes $\beta$ hazard ratios, comparable with
  Cox.
- Tools: `statsmodels` GLM with a binomial family (Seabold & Perktold, 2010),
  or scikit-learn's `LogisticRegression`.
- This is the Shumway (2001) and Bellotti & Crook (2013) set-up.

### Step 6: Cox model for comparison

- Fit Cox PH on (time to event, event indicator) with the static covariates,
  using Efron ties.
- Check proportional hazards with Schoenfeld residuals.
- For monthly covariates, use `lifelines` `CoxTimeVaryingFitter`.
- This tests whether the continuous-time model, the usual choice in the
  literature (section 6), gives the same picture as step 5.

### Step 7: link to the "3 months in" scope

This connects to the agreed scope (section 2 of `01-review`, `Oscar/06-07-plan`):

- The customers who matter are those with **no event by the end of June**
  ($t = 3$).
- For them, the model gives the probability of an event by October:

$$P(T \le 7 \mid T > 3, x) = 1 - \prod_{t=4}^{7} \bigl(1 - \hat h(t \mid x)\bigr).$$

- **Catch:** hazards for July–October use covariates from those months, which
  are not known in June. For a fair comparison with Oscar's early-warning
  model, either hold the covariates at their June values or use only static
  and Apr–Jun covariates. State which.

### Step 8: evaluation

- **Survival measures:** concordance index (Harrell et al., 1982) and
  time-dependent AUC (`scikit-survival`, Pölsterl, 2020).
- **For comparison with the other models:** AUC and Brier score of step 7's
  probability against the October label, on the same test split as
  `Oscar/07`. These are the agreed headline metrics (section 4 of `01-review`).

### Limitations

- **Only 7 time points.** Survival models usually cover the account's
  lifetime (years); here they cover half a year.
- **No account age** (left truncation) and **no true default date** (the
  event is a proxy built from `PAY_*`).
- **Recurrent events:** customers can fall behind, catch up and fall behind
  again. First-event models ignore this; Botha et al. (2025) show
  recurrent-event alternatives.
- **No competing risks:** Stepanova & Thomas (2002) also model early
  repayment, which our data does not record.

## 8. Models and code to cite

| Resource | Type | What it provides |
|---|---|---|
| `lifelines` (Davidson-Pilon, 2019) | Python library | Kaplan–Meier, Nelson–Aalen, log-rank test, Cox PH, time-varying Cox |
| `scikit-survival` (Pölsterl, 2020) | Python library | Penalised Cox, random survival forests, concordance and time-dependent AUC, in scikit-learn style |
| `statsmodels` (Seabold & Perktold, 2010) | Python library | GLM with logit or complementary log-log link, for the discrete-time model |
| Shumway (2001) | Paper | The simple discrete-time hazard model: a logit on person-periods |
| Bellotti & Crook (2013) | Paper | Discrete-time survival model for credit-card default: the closest published model to ours |
| Botha, Verster & Scheepers (2025) | Tutorial paper with codebase | Cox models for (recurrent) loan default, evaluated with Harrell's c and time-dependent ROC |

Before listing any of these in `RESOURCES.md`, note that the plan asks for
resources we have actually **run**. For Sprint 0 these are cited reading;
running them is Sprint 1.

## 9. Open questions for the group

- Is the event "first month ≥ 2 behind, or October default"? Or should we use
  the October label only, with months 1–6 as covariates?
- Do we exclude customers already behind in April, or keep them as a separate
  group?
- Does survival analysis go in Sprint 0 as a cited alternative only, and get
  built in Sprint 1?

## References

Entries marked * were checked online on 29 Sep 2026. The rest are standard
references; check page numbers against the published versions before final
submission.

- Aalen, O. (1978). Nonparametric inference for a family of counting processes. *Annals of Statistics* 6(4), 701–726.
- Allison, P. D. (1982). Discrete-time methods for the analysis of event histories. *Sociological Methodology* 13, 61–98.
- \* Banasik, J., Crook, J. N. & Thomas, L. C. (1999). Not if but when will borrowers default. *Journal of the Operational Research Society* 50(12), 1185–1190. [doi:10.1057/palgrave.jors.2600851](https://doi.org/10.1057/palgrave.jors.2600851)
- \* Bellotti, T. & Crook, J. (2009). Credit scoring with macroeconomic variables using survival analysis. *Journal of the Operational Research Society* 60(12), 1699–1707. [doi:10.1057/jors.2008.130](https://doi.org/10.1057/jors.2008.130)
- \* Bellotti, T. & Crook, J. (2013). Forecasting and stress testing credit card default using dynamic models. *International Journal of Forecasting* 29(4), 563–574. [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0169207013000502)
- \* Botha, A., Verster, T. & Scheepers, B. (2025). Exploring different subtypes of recurrent event Cox-regression models in modelling lifetime default risk: a tutorial. [arXiv:2505.01044](https://arxiv.org/abs/2505.01044)
- Cox, D. R. (1972). Regression models and life-tables. *Journal of the Royal Statistical Society B* 34(2), 187–220.
- \* Davidson-Pilon, C. (2019). lifelines: survival analysis in Python. *Journal of Open Source Software* 4(40), 1317. [doi:10.21105/joss.01317](https://doi.org/10.21105/joss.01317)
- \* Dirick, L., Claeskens, G. & Baesens, B. (2017). Time to default in credit scoring using survival analysis: a benchmark study. *Journal of the Operational Research Society* 68(6), 652–665. [doi:10.1057/s41274-016-0128-9](https://doi.org/10.1057/s41274-016-0128-9)
- Efron, B. (1977). The efficiency of Cox's likelihood function for censored data. *Journal of the American Statistical Association* 72(359), 557–565.
- Grambsch, P. M. & Therneau, T. M. (1994). Proportional hazards tests and diagnostics based on weighted residuals. *Biometrika* 81(3), 515–526.
- Harrell, F. E., Califf, R. M., Pryor, D. B., Lee, K. L. & Rosati, R. A. (1982). Evaluating the yield of medical tests. *JAMA* 247(18), 2543–2546.
- Kalbfleisch, J. D. & Prentice, R. L. (2002). *The Statistical Analysis of Failure Time Data*, 2nd ed. Wiley.
- Kaplan, E. L. & Meier, P. (1958). Nonparametric estimation from incomplete observations. *Journal of the American Statistical Association* 53(282), 457–481.
- Klein, J. P. & Moeschberger, M. L. (2003). *Survival Analysis: Techniques for Censored and Truncated Data*, 2nd ed. Springer.
- Mantel, N. (1966). Evaluation of survival data and two new rank order statistics arising in its consideration. *Cancer Chemotherapy Reports* 50(3), 163–170.
- Narain, B. (1992). Survival analysis and the credit granting decision. In Thomas, L. C., Crook, J. N. & Edelman, D. B. (eds), *Credit Scoring and Credit Control*, 109–121. Oxford University Press.
- Nelson, W. (1972). Theory and applications of hazard plotting for censored failure data. *Technometrics* 14(4), 945–966.
- \* Pölsterl, S. (2020). scikit-survival: a library for time-to-event analysis built on top of scikit-learn. *Journal of Machine Learning Research* 21(212), 1–6. [JMLR](https://www.jmlr.org/papers/v21/20-729.html)
- Prentice, R. L. & Gloeckler, L. A. (1978). Regression analysis of grouped survival data with application to breast cancer data. *Biometrics* 34(1), 57–67.
- Seabold, S. & Perktold, J. (2010). statsmodels: econometric and statistical modeling with Python. *Proceedings of the 9th Python in Science Conference*, 92–96.
- \* Shumway, T. (2001). Forecasting bankruptcy more accurately: a simple hazard model. *Journal of Business* 74(1), 101–124. [JSTOR](https://www.jstor.org/stable/10.1086/209665)
- Singer, J. D. & Willett, J. B. (1993). It's about time: using discrete-time survival analysis to study duration and the timing of events. *Journal of Educational Statistics* 18(2), 155–195.
- \* Stepanova, M. & Thomas, L. (2002). Survival analysis methods for personal loan data. *Operations Research* 50(2), 277–289. [doi:10.1287/opre.50.2.277.426](https://doi.org/10.1287/opre.50.2.277.426)
- Tutz, G. & Schmid, M. (2016). *Modeling Discrete Time-to-Event Data*. Springer.
