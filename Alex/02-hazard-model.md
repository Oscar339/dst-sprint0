# Discrete-time hazard model — notes

4 Oct 2026. This implements steps 0–2, 4, 5, 7 and 8 of `02-survival-analysis.md` (section 7).

| File | What it is |
|---|---|
| `02-hazard-model.R` | The model, adapted from the original R codebase |
| `02-hazard-model.py` | Line-by-line Python translation. It prints identical results (checked at both thresholds) |
| `test-ids-oscar07.csv` | The 5,999 test IDs from `Oscar/07`'s split, so R and Python test on the same customers. The Python script checks it against the split |
| `figures/hazard-term-structure-*.png` | Empirical vs model term-structure |

Run `report/01` first; it makes `data/processed/taiwan-clean.csv`. Then run `Rscript Alex/02-hazard-model.R` or `python Alex/02-hazard-model.py`. Add `3` after either command for the 90+ day check.

**Source (cite in the report):** Botha, A. & Muller, M. (2025). *Approaches for modelling the term-structure of default risk under IFRS 9: A tutorial using discrete-time survival analysis* [source code], v1.0. [doi:10.5281/zenodo.15856389](https://doi.org/10.5281/zenodo.15856389) · [GitHub](https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages) · MIT licence. Paper: Botha, A. & Verster, T. (2025), [arXiv:2507.15441](https://arxiv.org/abs/2507.15441). The R header lists which of their scripts each part comes from, and every change.

## Set-up

| | Ours | Theirs (basic model, script 5b(ii)) |
|---|---|---|
| Data | Taiwan credit cards, cleaned (`report/01`) | SA mortgages, 90,000 accounts, 2007–2022 |
| Time | Jul, Aug, Sep, Oct (months 4–7); one spell per customer | Up to 300 months; recurrent spells |
| Event | First month **2+ months behind** (Jul–Sep), or the October label | 90+ days past due |
| At risk | No event in Apr–Jun: 24,822 customers (19,828 train, 4,994 test) | Performing spells |
| Covariates | Month dummies + June status (category), utilisation, log payment, log limit, age, sex, education, marriage — all **as of June** | Time bins, recurrency, arrears, interest rate, inflation |
| Default weight | ×1 (better calibrated, see below) | ×10 |

## Results (test customers, event = 2+ months behind)

| Month | Customers at risk (all) | Empirical f(t) | Model f(t) |
|---|---|---|---|
| Jul | 24,822 | 4.87% | 5.75% |
| Aug | 23,452 | 4.49% | 4.65% |
| Sep | 22,319 | 3.06% | 2.82% |
| Oct | 21,616 | 11.55% | 11.15% |

f(t) is the probability of a first default in that month. The model's f(t) is averaged over test customers.

| Score on the October label (agreed headline metrics) | AUC | Brier |
|---|---|---|
| Hazard model, P(event by Oct) | 0.613 | 0.145 |
| One-period logistic regression, same covariates and customers | **0.632** | **0.137** |

- **The term-structure is well calibrated.** The MAE between empirical and model f(t) is 0.004 with weight ×1. With their ×10 weight it is 0.150, and July is predicted at 36%. So we kept ×1.
- **On the October label alone, the hazard model is slightly worse than plain logistic regression.** That is expected: it is fitted to a broader event (any month), whereas the logistic regression targets October directly. What the hazard model adds is *when*: one model gives a default probability for every month and any horizon.
- **The person-month AUC (0.71) mostly measures which month, not which customer.** Botha & Verster note the same effect.
- **Time-dependent Brier score:** 0.046 (Jul) → 0.175 (Oct). Integrated Brier score (IBS) = 0.102.
- **The strongest predictors** are June payment (larger payment → lower hazard), credit limit (higher → lower) and utilisation (higher → higher). Age and most education levels don't matter. The `-2` June status (no consumption) is the safest.
- **With the 90+ day check (threshold 3):**
  - At risk: 29,425 customers.
  - Term-structure MAE: 0.001.
  - On the October label: AUC 0.642 for the hazard model against 0.644 for logistic regression.
  - Jul–Sep events become rare (0.4–0.8% a month), so October dominates.

## Caveats

- **The event changes definition in October.** Jul–Sep events use payment status; October uses the dataset's own label. Part of the October jump is this change, not a real rise in risk.
- **Excluding customers with an event in Apr–Jun removes the riskiest 17%** (5,173 people) at threshold 2. Results only apply to customers who were not 2+ months behind by June.
- **"First 3 months" = first 3 *observed* months.** The data has no account-opening date.
- **Covariates are frozen at June** (the scope). Their model updates arrears every month, which would break our scope.
- **Only 4 periods.** The hazard model's real benefit would show on loan-level data with long histories.
