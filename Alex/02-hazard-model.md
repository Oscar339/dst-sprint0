# Discrete-time hazard model — notes

4 Oct 2026. This implements steps 0–2, 4, 5, 7 and 8 of `02-survival-analysis.md` (section 7) by reusing Botha & Muller's code as directly as possible.

| File | What it is |
|---|---|
| `02-hazard-functions-BothaMuller.R` | Their functions, **copied unchanged** with their licence: `coefDeter_glm`, `evalLR` (0a), `aicTable`, `concTable` and helpers (0b), `tBrierScore` (0e) |
| `02-hazard-model.R` | The model. It follows their scripts 5b(ii), 6c and 6d line by line, using their object and column names; our data preparation is section 1 |
| `02-hazard-model.py` | Python translation of both files. It prints identical results (checked for all three runs below) |
| `test-ids-oscar07.csv` | The 5,999 test IDs from `Oscar/07`'s split; used as their "validation" set |
| `figures/EventProb_Default_ActVsExp_CoxDisc_*.png` | Actual vs expected term-structure, in their graph style (`_py` = Python version) |

**To run:**
1. Run `report/01` first; it makes `data/processed/taiwan-clean.csv`.
2. Run `Rscript Alex/02-hazard-model.R` or `python Alex/02-hazard-model.py`.
3. Optional arguments: `3` for the 90+ day definition; `2 10` for their ×10 default weight.

The R script needs: data.table, dplyr, survival, survminer, scales, RColorBrewer, ggplot2, foreach, doParallel, pROC, sandwich, lmtest.

**Source:** Botha, A. & Muller, M. (2025). *Approaches for modelling the term-structure of default risk under IFRS 9: A tutorial using discrete-time survival analysis* [source code], v1.0. [doi:10.5281/zenodo.15856389](https://doi.org/10.5281/zenodo.15856389) · [GitHub](https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages) · MIT licence. Paper: Botha, A. & Verster, T. (2025), [arXiv:2507.15441](https://arxiv.org/abs/2507.15441).



## Set-up

| | Ours | Theirs (basic model) |
|---|---|---|
| Data | Taiwan credit cards, cleaned (`report/01`) | SA mortgages, 90,000 accounts, 2007–2022 |
| Time | Jul–Oct (spell months 1–4); one spell per customer | Up to 300 months; recurrent spells |
| Event | First month **2+ months behind** (Jul–Sep), or the October label | 90+ days past due |
| At risk | No event in Apr–Jun: 24,822 customers (19,828 train, 4,994 test) | Performing spells |
| Covariates | Month bins + June status (category), utilisation, log payment, log limit, age, sex, education, marriage — all **as of June** | Time bins, recurrency, arrears, interest rate, inflation |
| Default weight | ×1 | ×10 |

## Results (event = 2+ months behind)

| Month | Actual f(t) | Model f(t) |
|---|---|---|
| Jul | 5.52% | 5.70% |
| Aug | 4.56% | 4.54% |
| Sep | 2.83% | 2.72% |
| Oct | 11.10% | 10.77% |

Their term-structure method (6c) uses train and test together.

- **Calibration of the term-structure is good:** MAE 0.16%. With their ×10 weight it is **14.96%**, so we use ×1.
- **Diagnostics from their `evalLR()`:** AIC 32,964; McFadden R² 6.7%; person-month AUC 70.7% (train) and 71.2% (test). The person-month AUC mostly reflects *which month*, not *which customer*.
- **Single-factor tables (`aicTable`, `concTable`):** after the month bins, the strongest variables are log limit, June payment and utilisation. Age adds nothing.
- **Time-dependent Brier score** (their `tBrierScore()`, months 1–3): 0.051, 0.048, 0.041 (IBS 0.047). It is barely better than Kaplan–Meier alone (pseudo-R² of 2%, 1% and −2%).
- **Scored on the October label** (test set, agreed headline metrics):

| | AUC | Brier |
|---|---|---|
| Hazard model, P(default by Oct) | 0.613 | 0.145 |
| One-period logistic, same covariates | **0.632** | **0.137** |

- **90+ day check (threshold 3):** 29,425 customers at risk, MAE 0.06%, AUC 0.642 against 0.644 for logistic regression.

## Caveats

- **`tBrierScore()` stops at month 3.** Everyone still at risk is censored in October (the data ends), so their censoring weight explodes there (tBS > 1). October is scored directly against the label instead.
- **The event changes definition in October.** Jul–Sep events use payment status; October uses the dataset's label.
- **Excluding customers with an event in Apr–Jun removes the riskiest 17%** (5,173 at threshold 2).
- **"First 3 months" = first 3 *observed* months.** There is no account-opening date. Covariates are frozen at June, whereas their model updates arrears every month.
