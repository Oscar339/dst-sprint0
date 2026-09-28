# Review of Oscar's work, and next steps — Alex

27 Sep 2026. Covers `Oscar/01`–`04` and `Oscar/AI-LOG.md` at commit `08f8345`.
The numbers in sections 2–4 come from my own quick check (method at the end).

## 1. What Oscar has done

| Notebook | Finding | Consequence |
|---|---|---|
| `01-working` | No missing values; 22% default; undocumented codes (`EDUCATION` 0/5/6, `MARRIAGE` 0, `PAY_*` −2/0); `PAY_0` is the clearest signal | Accuracy is a poor metric (78% for "never default") |
| `02-duplicates` | 35 duplicate pairs, ~16 expected by chance (P ≈ 2×10⁻⁵); 5 almost certainly real; near-duplicates with **conflicting labels** | De-duplicate before splitting; some label noise |
| `03-predictors` | `PAY_*` dominate mutual information; demographics ≈ 0; strong columns overlap | Six months of data is not six times the information |
| `04-logistic` | Baseline AUC 0.72; `BILL_AMT` coefficients flip sign | Collinearity; categorical codes used as numbers |

The work is careful and well documented. What's missing: an agreed scope (what exactly we predict, and when), scoring, data smoothing.

## 2. Scope: predict default from 3 months in

The data covers six months of behaviour (Apr–Sep 2005) and one outcome (default in Oct 2005):

| Month | Apr | May | Jun | Jul | Aug | Sep | **Oct** |
|---|---|---|---|---|---|---|---|
| Status | `PAY_6` | `PAY_5` | `PAY_4` | `PAY_3` | `PAY_2` | `PAY_0` | **default?** |
| Bill / paid | `*_AMT6` | `*_AMT5` | `*_AMT4` | `*_AMT3` | `*_AMT2` | `*_AMT1` | |

**Proposal:** use only the first 3 months of observed behaviour (Apr–Jun) to predict the outcome of default or not default. This should result in a more useful model rather than us predicting whether they will default or not the month before. A useful test could be to build one model containing all months and one containing only the first three months and compare.

**Results:** We will end up with a less accurate model using only the first 3 months. We will assess how different our models are at the end.

## 3. Collinearity: variance inflation factor (VIF)

VIF_j = 1 / (1 − R_j²), where (R_j^2) is obtained by regressing predictor (j) on all the other predictors. Equivalently, VIF is given by the diagonal elements of the inverse correlation matrix. As a rule of thumb, VIF values above 5 indicate potentially concerning multicollinearity, while values above 10 indicate severe multicollinearity. We can therefore use VIF to identify which predictors contain redundant information and assess whether individual predictors are contributing distinct information to the model.

- **Caveats:**
  - VIF affects how we *interpret* coefficients much more than predictive accuracy.
  - VIF on raw category codes (`EDUCATION`, `MARRIAGE`, `SEX`) is meaningless. After one-hot encoding, use the generalised VIF (GVIF).

## 4. Scoring: agree before building more models

| Measure | What it answers | Note |
|---|---|---|
| Confusion matrix, F1 | Does the model flag the right people at a given threshold? | Threshold-dependent.|
| Brier score,log loss | Are the predicted probabilities right? | Proper scoring rules.|
| Calibration curve | Does "20% risk" mean 20% of those customers default? | |
| AUC / Gini, KS | Does the model rank risky customers above safe ones? | The industry standard, but it ignores calibration. |
| Expected cost | What does a wrong decision cost? | German Credit has a published 5:1 cost matrix. Most of our work is done on Taiwan data. |

**Suggestion:**
- Headline metrics: Brier + AUC.
- Also report a confusion matrix at a threshold chosen on validation data, never the test set.
- This overlaps with Oscar's `04-Evaluation`.

## 5. Sparse categories: smoothing

Some categories have very few customers, so their default rates are unreliable:

| Category | Customers | Default rate |
|---|---|---|
| `EDUCATION` = 0 | 14 | 0% |
| `PAY_4` = 1 | 2 | 50% |
| `PAY_4` = 8 | 2 | 50% |

- **Laplace (add-one)** smoothing: (k + 1) / (n + 2). It shrinks every rate towards 50%, which is the wrong prior when the base rate is 22%.
- **Better: the m-estimate / beta-binomial (empirical Bayes)** version: (k + m·p̄) / (n + m), which shrinks towards the overall rate p̄ = 0.22. For example, `EDUCATION` = 0 with m = 10 gives (0 + 2.2) / 24 = 0.09 instead of 0. m can be chosen by cross-validation.
- **Or merge sparse categories:**
  - undocumented `EDUCATION` codes into "other";
  - `PAY` values of 3 or more into "3+".

  Scorecard binning (notebook 02) does this anyway.
- Any target / WoE encoding must be fitted inside the training folds, or it leaks the label.

## 6. Survival model

**Idea:** model loaners monthly. This fits the "3 months in" scope well: condition on reaching month 3, then model the hazard after that.

**The data's limits:**
- The true default label exists for one month only (October).
- There is no account age and no default date.

**A workable version is a discrete-time hazard model:**
1. Define a monthly event from `PAY_*`, e.g. "first month at 2 or more months behind".
2. Build a person-month table, with customers who never have the event censored at September.
3. Fit a logistic regression on that table. This is a standard discrete-time survival model.
