# Data Science Toolbox — Sprint 0: Credit Default Risk

Formative Sprint 0 for [Data Science Toolbox](https://dsbristol.github.io/dst/)
(MATHM0029, University of Bristol, 2026-27): a literature review of the
resources for doing data science in **credit default risk**. Laid out after the unit's
[example project](https://github.com/dsbristol/dst_example_project).

Repository: https://github.com/Oscar339/dst-sprint0

## Project Group

* Oscar Butler — getting, checking and cleaning the Taiwan data (01); reproducing
  Yeh & Lien (2009) (02); probability calibration with scikit-learn's example (03).
* Alex Robinson — survival-analysis literature review (04); the
  discrete-time hazard model built on Botha, Muller & Breedt's code, in R (05)
  with a Python translation in `Alex/`; the conclusion (07).
* Louis Mulryan — the Markov chain model of repayment status (06).

Equity: equal, 1/3 each.

## Reading order

All report content is in `report/`, read in this order:

1. `01-Introduction.ipynb` — the brief, the domain, and getting and cleaning
   the Taiwan credit-card data. **Run this first**: it makes the clean data
   file every later notebook loads.
2. `02-YehLien.ipynb` — reproducing the logistic regression of Yeh & Lien (2009).
3. `03-Calibration.ipynb` — fixing the probabilities, with scikit-learn's
   calibration example.
4. `04-HazardModelResearch.ipynb` — literature review of survival analysis
   for credit, and how it applies to our data.
5. `05-HazardModel-R.R` — a discrete-time hazard model on the Taiwan data,
   reusing the R code of Botha, Muller & Breedt (2025). Run from the
   repository root with `Rscript report/05-HazardModel-R.R`; its figures are
   saved to `Alex/figures/`.
6. `06-MarkovChainModel.ipynb` — a Markov chain model of repayment status,
   after Leow & Crook (2014).
7. `07-Conclusion.md` — what the resources tell us, the limits, and the outcome.

Executed copies (with output) are committed so the output can be read without
running anything.

### Requirements

Python 3.13. From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

`05-HazardModel-R.R` also needs R, with the packages it loads at the top of
the script installed.

Data is downloaded by `report/01-Introduction.ipynb` into `data/raw/` (not
committed). Any manual step is stated in the notebook where it happens.

**Taiwan data: use the cleaned version.** Run `report/01-Introduction.ipynb` to make
`data/processed/taiwan-clean.csv`, and load that instead of the raw `.xls`. See
`data/README.md` for what was changed. From a notebook in `report/` or your own
folder:

```python
import pandas as pd
from pathlib import Path

ROOT = Path.cwd().parent
taiwan = pd.read_csv(ROOT / "data" / "processed" / "taiwan-clean.csv", index_col="ID")
```

`PAY_0` is renamed `PAY_1` in the clean file.

## Evidence

Each member's working, including dead ends, is in their own folder:

* `Oscar/`
* `Alex/`
* `Louis/`

## References

### Data

* Yeh, I-C. (2009). *Default of Credit Card Clients* [dataset]. UCI Machine
  Learning Repository. https://doi.org/10.24432/C55S3H
* Hofmann, H. (1994). *Statlog (German Credit Data)* [dataset]. UCI Machine
  Learning Repository. https://doi.org/10.24432/C5NC77 (considered, not used)

### Papers

* Yeh, I-C. & Lien, C-H. (2009). The comparisons of data mining techniques for
  the predictive accuracy of probability of default of credit card clients.
  *Expert Systems with Applications* 36(2), 2473–2480.
  https://doi.org/10.1016/j.eswa.2007.12.020
* Botha, A. & Verster, T. (2025). Approaches for modelling the term-structure
  of default risk under IFRS 9: A tutorial using discrete-time survival
  analysis. arXiv:2507.15441. https://arxiv.org/abs/2507.15441
* Leow, M. & Crook, J. (2014). Intensity models and transition probabilities
  for credit card loan delinquencies. *European Journal of Operational
  Research* 236(2), 685–694. https://doi.org/10.1016/j.ejor.2013.12.026
* Engelmann, B., Hayden, E. & Tasche, D. (2003). Testing rating accuracy.
  *Risk* 16 (January), 82–86.
* Davis, J. & Goadrich, M. (2006). The relationship between precision-recall
  and ROC curves. *ICML*, 233–240. https://doi.org/10.1145/1143844.1143874
* Gneiting, T. & Raftery, A. E. (2007). Strictly proper scoring rules,
  prediction, and estimation. *JASA* 102(477), 359–378.
  https://doi.org/10.1198/016214506000001437
* Niculescu-Mizil, A. & Caruana, R. (2005). Predicting good probabilities with
  supervised learning. *ICML*, 625–632. https://doi.org/10.1145/1102351.1102430
* Platt, J. (1999). Probabilistic outputs for support vector machines and
  comparisons to regularized likelihood methods. *Advances in Large Margin
  Classifiers*, 61–74.
* Zadrozny, B. & Elkan, C. (2002). Transforming classifier scores into accurate
  multiclass probability estimates. *KDD*, 694–699.
  https://doi.org/10.1145/775047.775151
* Chen, S. F. & Goodman, J. (1999). An empirical study of smoothing techniques
  for language modeling. *Computer Speech & Language* 13(4), 359–394.
  https://doi.org/10.1006/csla.1999.0128
* Pedregosa, F. et al. (2011). Scikit-learn: machine learning in Python.
  *JMLR* 12, 2825–2830.

### Code, tutorials and course material

* Botha, A., Muller, M. & Breedt, R. (2025). *Approaches for modelling the
  term-structure of default risk under IFRS 9* [source code], v1.0. MIT
  licence. https://doi.org/10.5281/zenodo.15856389 ·
  https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
* scikit-learn developers. *Probability Calibration curves* [code example],
  scikit-learn 1.9.1 documentation.
  https://scikit-learn.org/stable/auto_examples/calibration/plot_calibration_curve.html
* Lawson, D. (2026). *Introduction to Classification*, Data Science Toolbox
  lecture 01.2. University of Bristol.
  https://dsbristol.github.io/dst/assets/slides/01.2-Classification.pdf
* Hoff, P. (2025). *Shrinkage and empirical Bayes* [lecture notes]. Duke
  University. https://www2.stat.duke.edu/~pdh10/Teaching/732/Notes/shrinkage.pdf
* Maullin, T. (2026). *MATH30028 Statistical Machine Learning, Part I*
  [lecture notes]. University of Bristol.
