# Resources

Every resource we found, used or rejected. Add yours under your OWN heading so
three people can edit this at once without merge conflicts. For each:
reference or link · type (paper / book / repo / tutorial / site) · language ·
what it does · did you RUN it, and what happened.

## Oscar

Report notebooks: `report/01-Introduction` (cleaning), `report/02-YehLien`,
`report/03-Calibration`. Working in `Oscar/01`–`08`.

### Run, reproduced or adapted

1. **Yeh, I-C. & Lien, C-H. (2009).** The comparisons of data mining techniques
   for the predictive accuracy of probability of default of credit card clients.
   *Expert Systems with Applications* 36(2), 2473–2480.
   https://doi.org/10.1016/j.eswa.2007.12.020
   · paper · no code published
   · Introduces the Taiwan dataset; compares six classifiers on ranking (error
   rate, area ratio, lift chart) and on probability accuracy (its new Sorting
   Smoothing Method).
   · **Reproduced** its logistic-regression results in Python from the text
   alone (`report/02`). Area ratio 0.425 on our test set, mean 0.440 over 20
   splits (paper 0.44). Error rate 0.188 (paper 0.18). Calibration line slope
   and intercept show the same pattern. **Could not reproduce** its naive Bayes
   (area ratio 0.30 vs 0.53), probably because the paper doesn't say how naive
   Bayes handled the money columns (`report/03`, Part C). Also used for the
   variable descriptions in the data-cleaning table (p. 2475), which found six
   mismatches between the paper and the file.

2. **Yeh, I-C. (2009).** *Default of Credit Card Clients* [dataset]. UCI
   Machine Learning Repository. https://doi.org/10.24432/C55S3H
   · dataset + documentation page · `.xls`
   · The data and its variable codebook.
   · Downloaded and read with pandas (needs `xlrd`). Checked against the
   documentation: undocumented `PAY_*`, `EDUCATION` and `MARRIAGE` codes,
   `PAY_0` naming, 35 duplicate pairs (`Oscar/01`, `02`; cleaning in `report/01`).

3. **scikit-learn developers.** *Probability Calibration curves* [code
   example], scikit-learn 1.9.1 documentation.
   https://scikit-learn.org/stable/auto_examples/calibration/plot_calibration_curve.html
   · tutorial / code example · Python · BSD-3-Clause
   · Compares logistic regression and Gaussian naive Bayes, before and after
   sigmoid and isotonic calibration, on synthetic data.
   · **Ran unchanged:** every number matched the documentation page. Then
   **adapted** it to the Taiwan data (`report/03`), with a frozen model
   calibrated on a held-out set, equal-size groups, and our own plots. Isotonic
   fixed the logistic regression's S-shaped calibration (Brier 0.146 → 0.141);
   sigmoid did nothing. Left out the second half (linear SVC), which isn't one
   of the paper's methods.

4. **Lawson, D. (2026).** *Introduction to Classification*, Data Science
   Toolbox lecture 01.2 (v4.0.0), slides and reference R code. University of
   Bristol. https://dsbristol.github.io/dst/assets/slides/01.2-Classification.pdf
   · lecture slides + R demo · R
   · Train / calibration / test splits, ROC and precision–recall, "are these
   probabilities?"
   · **Translated** the R demo to Python. Its score-by-rank plot didn't work on
   6,000 customers (the defaulters are hidden), so it was redesigned as a score
   curve plus a strip of defaulters' ranks (`report/02`, Figure 2.3). Its
   three-way split and precision–recall curve go beyond what the paper reports.
   Note: the "Reference R code (01.2-Classification.R)" link on the block 1 page
   returns 404 (checked 4 Oct 2026).

5. **Pedregosa, F. et al. (2011).** Scikit-learn: machine learning in Python.
   *JMLR* 12, 2825–2830. User guide: https://scikit-learn.org/stable/user_guide.html
   · library + documentation · Python
   · `LogisticRegression`, `CalibratedClassifierCV`, `FrozenEstimator`,
   `calibration_curve`, `precision_recall_curve`, `mutual_info_classif`.
   · Used throughout. One version issue: scikit-learn 1.8 deprecated
   `penalty=None`, so older examples needed changing to `C=np.inf` for an
   unpenalised fit (`report/02`, step 1).

### Read and cited for methods

6. **Engelmann, B., Hayden, E. & Tasche, D. (2003).** Testing rating accuracy.
   *Risk* 16 (January), 82–86.
   · paper · no code
   · Shows the accuracy ratio (Gini) equals 2 × AUC − 1.
   · Used to check our area ratio against the AUC: they agree to six decimal
   places (`report/02`, step 2).

7. **Davis, J. & Goadrich, M. (2006).** The relationship between
   precision-recall and ROC curves. *ICML*, 233–240.
   https://doi.org/10.1145/1143844.1143874
   · paper · no code
   · Why precision–recall suits problems where the positive class matters
   most. Cited by lecture 01.2.
   · Basis for `report/02`, step 4.

8. **Gneiting, T. & Raftery, A. E. (2007).** Strictly proper scoring rules,
   prediction, and estimation. *JASA* 102(477), 359–378.
   https://doi.org/10.1198/016214506000001437
   · paper · no code
   · Proper scoring rules (Brier score, log loss) reward honest probabilities.
   · Why we judge calibration by the Brier score rather than the paper's
   R², which we showed depends on its own smoothing window (`report/02`, step 5).

9. **Niculescu-Mizil, A. & Caruana, R. (2005).** Predicting good probabilities
   with supervised learning. *ICML*, 625–632.
   https://doi.org/10.1145/1102351.1102430
   · paper · no code
   · Which classifiers give well-calibrated probabilities, and how to fix the
   ones that don't. Cited by the scikit-learn example (3).
   · Background for `report/03`.

10. **Platt, J. (1999)** (sigmoid calibration) and **Zadrozny, B. & Elkan, C.
    (2002)** (isotonic calibration), *KDD*, 694–699,
    https://doi.org/10.1145/775047.775151
    · papers · no code
    · The original sources of the two calibration methods in (3).
    · Cited in `report/03`.

11. **Hofmann, H. (1994).** *Statlog (German Credit Data)* [dataset]. UCI.
    https://doi.org/10.24432/C5NC77
    · dataset · —
    · Comes with a 5:1 cost matrix (a missed bad loan costs 5× a wrongly
    refused good one).
    · **Rejected as a dataset**: downloaded at the start, but nobody's analysis
    used it, so it was dropped on 4 Oct. Its cost matrix is still cited when
    choosing a threshold by cost (`report/02`, step 4).

### Theory from another unit

12. **Maullin, T. (2026).** *MATH30028 Statistical Machine Learning, Part I*,
    lecture notes. University of Bristol.
    · lecture notes · —
    · GLMs and ridge (§2), loss and Bayes classifiers (§3.1), naive Bayes and
    LDA (§3.3), validation (§4.5), kernel smoothing (§4.14).
    · Used to explain the results: why the penalty made no difference, why the
    bill weights flip sign, why 0.5 is the right threshold only under equal
    costs, why the paper's Sorting Smoothing Method is a box-kernel smoother,
    and why Gaussian naive Bayes fails here. See the "Link to MATH30028" notes
    in `report/02` and `03`.

## Alex

Working in `Alex/`: review (`01`), survival-analysis literature review
(`02-survival-analysis.md`), hazard model (`02-hazard-model.*`).

### Run, reproduced or adapted

1. **Botha, A. & Muller, M. (2025).** *Approaches for modelling the
   term-structure of default risk under IFRS 9: A tutorial using discrete-time
   survival analysis* [source code], v1.0.
   https://doi.org/10.5281/zenodo.15856389 ·
   https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
   · repo · R · MIT licence · accompanies Botha, A. & Verster, T. (2025),
   arXiv:2507.15441
   · Discrete-time hazard models (weighted logistic regression on person-month
   data) for lifetime default risk on SA mortgages, with Kaplan–Meier
   term-structures and time-dependent Brier scores.
   · Their data isn't public, so the scripts can't be run as published.
     **Adapted** their basic model (scripts 3b, 5b(ii), 0a, 6c, 0e) to the
     Taiwan data in R (`Alex/02-hazard-model.R`): first 3 months as covariates,
     predicting first default in Jul–Oct.
   · **Translated** it to Python (`Alex/02-hazard-model.py`); both print
     identical results.
   · Their ×10 default weight mis-calibrated our data (term-structure MAE 0.150
     vs 0.004 with ×1), so we used ×1.
   · On the October label: AUC 0.613, against 0.632 for a plain logistic
     regression with the same covariates (`Alex/02-hazard-model.md`).

## Louis
