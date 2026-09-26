# Sprint 0 plan — Credit default

**Domain:** consumer credit risk. Can we predict whether a borrower will
default, and what do the available resources say about how to do it?

**Deadline:** Wed 7 Oct, 12:00 (week 3). **Group content locked Mon 5 Oct,
12:00**, so everyone has 48 hours to write their own reflection, as the
brief asks.

The domain carries into Sprint 1 (set week 3, due Wed 4 Nov), so Sprint 0
doubles as the groundwork for it. See the end of this file.

---

## The data

Both datasets load in one line through scikit-learn. No login is needed and
nothing extra has to be installed; the first run downloads them and caches a copy.

```python
from sklearn.datasets import fetch_openml

taiwan = fetch_openml(data_id=42477, as_frame=True).frame   # 30,000 x 24, target 'y'
german = fetch_openml(data_id=31, as_frame=True).frame      # 1,000 x 21, target 'class'
```

| | Taiwan credit cards | German Credit |
|---|---|---|
| Rows | 30,000 cardholders | 1,000 loans |
| Label | default next month (22% yes) | good / bad (30% bad) |
| Features | credit limit, age, sex, education, marital status, 6 months of repayment status, bill and payment amounts | 20 application attributes: account status, duration, purpose, savings, employment, housing, … |
| Origin | Yeh & Lien (2009); UCI dataset 350 | Hofmann (1994); UCI dataset 144 |
| Useful quirk | OpenML names the columns `x1..x23`, so they need renaming from the UCI description. `EDUCATION` and `PAY_*` contain undocumented codes (0, 5, 6, -2), which is a real data-cleaning finding | Comes with a published **cost matrix**: a bad loan predicted good costs 5, a good loan predicted bad costs 1 |

The two datasets have **different features**, so a model trained on one cannot be
scored on the other. The comparison between them is between *methods and
results*, not a transfer test. The brief's "applied across different datasets"
question is answered by running the same approach on both.

---

## Who does what

Each person owns **one** report notebook. Two people editing the same notebook
causes merge conflicts, because notebook files do not merge cleanly. Your
working, including dead ends, goes in your own folder (`Oscar/`, `Alex/`,
`Louis/`).

| Notebook | Owner | What it covers |
|---|---|---|
| `01-Introduction.ipynb` | **Oscar** | The domain and the brief; the kinds of credit data that exist (application, behavioural, bureau, loan-book, corporate); loading and cleaning both datasets; exploratory plots. |
| `02-Scorecards.ipynb` | **Alex or Louis** | The traditional industry approach: binning, weight of evidence (WoE) and information value (IV), and a logistic-regression scorecard. Run the `optbinning` / `scorecardpy` tutorials on German Credit, then change them to make our own plots, e.g. WoE by variable and score distributions for good vs bad. |
| `03-MachineLearning.ipynb` | **Alex or Louis** | The machine-learning approach on Taiwan: random forest and gradient boosting (`HistGradientBoostingClassifier`), feature and permutation importance, taken from public notebooks and scikit-learn examples and adapted. |
| `04-Evaluation.ipynb` | **Oscar** | How the resources judge a model, and whether that is right: accuracy vs AUC/Gini and KS; log loss and Brier score (proper scoring rules); calibration curves; cost-weighted loss with the German cost matrix (scikit-learn's cost-sensitive example uses this dataset). This notebook sets up Sprint 1, where half the effort goes on performance measures. |
| `05-Wrapup.ipynb` | **All three** | Answers the brief's questions (below). Each person drafts the paragraphs on their own notebook in `WRAPUP.md` first (markdown merges cleanly), and the notebook is built from that at the lock. |

Equity: **equal thirds**, unless we agree otherwise before starting. Write it in
the README.

**What the brief asks the report to answer** (split them between us in `05`):
1. What are the broad types of data?
2. What are the main types of resource?
3. What problems can they solve?
4. Which generic data-science resources apply, and in what sense?
5. How can approaches be compared, or applied across different datasets?
6. How did sharing code on GitHub help or limit us?

**Each person's resource target:** at least 4 resources with code that you have
actually **run**, including at least one paper or book and at least one
repository or tutorial. Add every one to `RESOURCES.md` under your own heading,
so three people can edit the file at once without conflicts. The example
project lost marks on exactly this ("unimpressed by the amount of external
resource ... and referencing"), so breadth and proper citations are where the
easy marks are.

---

## Resources to start from

Marked **[code]** where there is runnable Python.

**Data and the original papers**
* Yeh, I-C. & Lien, C-H. (2009). The comparisons of data mining techniques for
  the predictive accuracy of probability of default of credit card clients.
  *Expert Systems with Applications* 36(2).
* UCI: *Default of Credit Card Clients* (id 350) and *Statlog German Credit* (id 144).

**Surveys and benchmarks (for the literature section)**
* Hand, D. J. & Henley, W. E. (1997). Statistical classification methods in
  consumer credit scoring: a review. *JRSS A* 160(3).
* Lessmann, S., Baesens, B., Seow, H-V. & Thomas, L. C. (2015). Benchmarking
  state-of-the-art classification algorithms for credit scoring: an update of
  research. *European Journal of Operational Research* 247(1).
* Thomas, L. C., Crook, J. & Edelman, D. — *Credit Scoring and Its
  Applications* (SIAM). The standard textbook.

**Scorecards (notebook 02)**
* **[code]** `optbinning`: https://github.com/guillermo-navas-palencia/optbinning.
  Optimal binning plus a scorecard module, with tutorials.
* **[code]** `scorecardpy`: https://github.com/ShichenXie/scorecardpy. Ships
  German Credit as its worked example.
* Siddiqi, N. *Intelligent Credit Scoring* (Wiley, 2nd ed. 2017). The
  practitioner's reference; no code.
* Baesens, Rösch & Scheule, *Credit Risk Analytics* (Wiley, 2016). Good on
  methods, but its code is **SAS**, so use it for ideas rather than code.

**Machine learning (notebook 03)**
* **[code]** scikit-learn user guide: ensembles (random forests, gradient
  boosting) and permutation importance.
* **[code]** Karasan, A. *Machine Learning for Financial Risk Management with
  Python* (O'Reilly, 2021). Has a credit-risk chapter.
* **[code]** Public Kaggle notebooks on the "Default of Credit Card Clients"
  dataset. They are free to read; we load the data from OpenML instead.

**Evaluation (notebook 04)**
* **[code]** scikit-learn, *Post-tuning the decision threshold for
  cost-sensitive learning*, which uses German Credit and its cost matrix:
  https://scikit-learn.org/stable/auto_examples/model_selection/plot_cost_sensitive_learning.html
* **[code]** scikit-learn, *Probability calibration*:
  https://scikit-learn.org/stable/modules/calibration.html
* Gneiting, T. & Raftery, A. E. (2007). Strictly proper scoring rules,
  prediction, and estimation. *JASA* 102(477).
* Hand, D. J. (2009). Measuring classifier performance: a coherent alternative
  to the area under the ROC curve. *Machine Learning* 77. The H-measure;
  **[code]** `hmeasure` is on PyPI.
* Basel Committee (2005). *An Explanatory Note on the Basel II IRB Risk Weight
  Functions*. Why banks need calibrated default probabilities, not just a ranking.

---

## Timeline

| When | What |
|---|---|
| **Sat 26 – Sun 27 Sep** | Agree the domain, who owns 02 and 03, and equity. Clone the repo and set up Python (README). Oscar: data-loading cell in `01` pushed so everyone loads the data the same way. |
| **Mon 28 – Wed 30 Sep** | Everyone: find resources, run their examples in your own folder, log them in `RESOURCES.md`. Push at the end of each session. |
| **Thu 1 Oct** (after the 10:00 DST session) | Check-in: what ran, what didn't, what each notebook will show. Settle the wrap-up split. |
| **Fri 2 – Sat 3 Oct** | Write your report notebook: adapted code, **our own** plots, short factual notes on what was done and why, citations. Draft your `WRAPUP.md` paragraphs. |
| **Sun 4 Oct** | Everything pushed. Each person runs the whole report from a fresh pull, fixes what breaks, and reads the others' notebooks. |
| **Mon 5 Oct, 12:00** | **LOCK.** Final commit with executed notebooks (outputs visible), README reading order and equity filled in. Nothing changes after this. |
| **Mon 5 – Tue 6 Oct** | Individual reflections, ~500-800 words, written alone. |
| **Wed 7 Oct, 12:00** | **Each** of us submits a reflection plus the repo link on Blackboard. |

---

## Looking ahead: Sprint 1 (set week 3, due Wed 4 Nov)

Sprint 1 asks each member to build **one model** that is evaluated on
left-out test data, for the group to **agree a performance measure**, and to
spend **half the effort** on whether that measure is the right one. This
domain fits that directly:

* Three models on Taiwan: a logistic scorecard, a random forest, gradient
  boosting. That is one each, and Sprint 0's notebooks 02 and 03 are the
  groundwork.
* Evaluation (from notebook 04): Gini/AUC as banks report it, against Brier
  score and log loss (is the default *probability* right?), against expected
  cost under a cost matrix. Is the "best" model still best under each?
* Generalisation, as the brief asks ("leave out some types of data"): train
  on some borrowers and test on a group held out on purpose, e.g. by
  credit-limit band or age, to see whether the ranking of models survives.

Consolidation week (w/c 26 Oct, no teaching) is the natural main build week.
Lock: **Mon 2 Nov, 12:00**.
