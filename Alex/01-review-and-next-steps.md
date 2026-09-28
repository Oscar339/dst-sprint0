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

VIF_j = 1 / (1 − R_j²), where R_j² comes from regressing column j on all the others. Equivalently, VIF is the diagonal of the inverse correlation matrix. The usual rule of thumb: above 5 is a concern, above 10 is serious.

| Columns | VIF (all 23 columns) |
|---|---|
| `BILL_AMT1`–`6` | **14–26** |
| `PAY_0`–`PAY_6` | 1.9–4.7 |
| Everything else | below 2.3 |

- These values explain the sign flips in `04-logistic`.
- They stay high within the Apr–Jun scope (`BILL_AMT4`–`6`: 11–25).
- **Fixes:** keep one bill month, or use summaries (mean bill, **utilisation** = bill / limit, payment / bill), or an L1/L2 penalty.
- **Caveats:**
  - VIF affects how we *interpret* coefficients much more than predictive accuracy.
  - VIF on raw category codes (`EDUCATION`, `MARRIAGE`, `SEX`) is meaningless. After one-hot encoding, use the generalised VIF (GVIF).

## 4. Scoring: agree before building more models

| Measure | What it answers | Note |
|---|---|---|
| Confusion matrix, precision / recall / F1 | Does the model flag the right people at a given threshold? | Threshold-dependent. Choosing 0.22 instead of 0.5 raises F1 from 0.11 to 0.41 (Apr–Jun). |
| Brier score, log loss | Are the predicted probabilities right? | Proper scoring rules. Predicting 22% for everyone gives Brier 0.172, so report a **skill score** against that. |
| Calibration curve | Does "20% risk" mean 20% of those customers default? | Banks need calibrated PDs (Basel). |
| AUC / Gini, KS | Does the model rank risky customers above safe ones? | The industry standard, but it ignores calibration. |
| Expected cost | What does a wrong decision cost? | German Credit has a published 5:1 cost matrix. |

**Suggestion:**
- Headline metrics: Brier (skill) + AUC.
- Also report a confusion matrix at a threshold chosen on **validation data, never the test set**.
- This overlaps with Oscar's `04-Evaluation`, so agree it with him.

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
- Any target / WoE encoding must be fitted **inside** the training folds, or it leaks the label.

## 6. Survival model

**Idea:** model *when* a customer defaults, not just whether they do. This fits the "3 months in" scope well: condition on reaching month 3, then model the hazard after that.

**The data's limits:**
- The true default label exists for one month only (October).
- There is no account age and no default date.

**A workable version is a discrete-time hazard model:**
1. Define a monthly event from `PAY_*`, e.g. "first month at 2 or more months behind".
2. Build a person-month table, with customers who never have the event censored at September.
3. Fit a logistic regression on that table. This is a standard discrete-time survival model.

**Caveats:**
- The event is *constructed* from status codes; it is not the real default label.
- The accounts already existed before April (left truncation).

This is probably Sprint 1 material. For Sprint 0, cite it as a resource:
- Stepanova, M. & Thomas, L. C. (2002). Survival analysis methods for personal loan data. *Operations Research* 50(2).
- Bellotti, T. & Crook, J. (2009). Credit scoring with macroeconomic variables using survival analysis. *JORS* 60(12).
- `lifelines` (Python survival analysis library).

## 7. Other things to settle

- **Sprint 0 is a literature review.** It's due Wed 7 Oct, and group content locks **Mon 5 Oct, 12:00**. Most of sections 2–6 is Sprint 1 modelling. For Sprint 0, use it as evidence of what the resources do and don't cover (notebooks 04 and 05), and each of us still needs 4+ *run* resources in `RESOURCES.md`.
- **Owners of `02-Scorecards` and `03-MachineLearning`** (me or Louis) aren't agreed yet.
- **Undocumented codes:** decide what they mean and cite a source (merge into "other" / treat −2, −1, 0 as "not late").
- **Near-duplicates with conflicting labels** (IDs 12431 / 12433 / 14295): drop them, keep them, or flag them? Decide and state it in the cleaning section.
- **Class imbalance:** prefer threshold choice or class weights over resampling (SMOTE etc.), which distorts calibrated probabilities.
- **`PLAN.md`** still says to load the data with `fetch_openml`, but notebook 01 loads the UCI files.
- **German Credit** hasn't been touched yet.

---

<details>
<summary>How the numbers above were made</summary>

Taiwan `.xls` from `data/raw/` (SHA-256 matches `data/README.md`), exact duplicates dropped (29,965 rows), 75/25 stratified split with `random_state=0` (the same as `Oscar/04-logistic`), `StandardScaler` + `LogisticRegression(max_iter=2000)`, all columns used as plain numbers. VIF = diagonal of the inverse of the correlation matrix of the 23 predictors.

```python
static = ["LIMIT_BAL", "SEX", "EDUCATION", "MARRIAGE", "AGE"]
month = {m: [f"PAY_{0 if m == 1 else m}", f"BILL_AMT{m}", f"PAY_AMT{m}"] for m in range(1, 7)}
first3 = static + month[4] + month[5] + month[6]          # Apr–Jun
vif = pd.Series(np.diag(np.linalg.inv(np.corrcoef(X.values, rowvar=False))), index=X.columns)
```

To be turned into a notebook in this folder.
</details>
