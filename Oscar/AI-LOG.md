# AI use log — Oscar

An audit trail of how I directed AI tools (Claude Code and ChatGPT) in this
project: what I asked, what the tool did, and what I checked. AI use is allowed
for this unit; this log is so anyone can see which work is mine, which came
from AI, and how I checked it.

**Rules for this log**
* One entry per session, newest at the bottom. Never edit or delete old entries;
  add a correction as a new entry instead.
* Prompts are copied **word for word**, typos included.
* "What it did" names the files it changed. "What I checked" is my own note:
  did I run it, read it, understand it, change it?

**Entry format**

```
## YYYY-MM-DD — <tool> — <topic>
| # | My prompt (verbatim) | What it did | Files |
|---|---|---|---|
What I checked / changed myself:
```

---

## Using this log with ChatGPT

Paste this at the start of every ChatGPT conversation about the project:

> I am keeping an AI-use audit log for a university data-science project
> (Python, pandas). At the end of this conversation, or whenever I say "log
> it", give me a Markdown entry in exactly this format, which I will paste into
> my log:
>
> `## YYYY-MM-DD — ChatGPT — <topic in a few words>`
>
> then a table with columns `#`, `My prompt (verbatim)`, `What it did`,
> `Files`: one row per message I sent, my prompt copied word for word, a
> one-line factual summary of what you gave me (code, explanation, advice), and
> which of my files it was for, if any. Then a line
> `What I checked / changed myself:` left blank for me to fill in. Do not
> summarise or improve my prompts, and do not leave out any that I sent.

Check ChatGPT's table against the conversation before pasting it in. It can
drop or reword prompts.

---

## Before this log (26 Sep 2026) — Claude Code

Prompts not recorded. Claude co-authored commits `6cfe770` (project plan) and
`0033516` (notebook 01: downloading and loading both datasets). Their commit
messages describe the work.

## 2026-09-26 — Claude Code — loading Taiwan data, first EDA

| # | My prompt (verbatim) | What it did | Files |
|---|---|---|---|
| 1 | lets get the data into this document. the taiwan one is enough for now | Added a dated section and a cell reading the Taiwan `.xls` from `data/raw/` with pandas (`header=1`, `index_col="ID"`). Test-ran it: 30000 x 24. | `Oscar/01-working.ipynb` |
| 2 | what should i do next? | Advice from `PLAN.md`: push notebook 01, explore Taiwan's undocumented codes, start `RESOURCES.md`, agree owners of 02/03. Flagged that `PLAN.md` still says to load the data with `fetch_openml`. | none |
| 3 | lets do some rough eda on my workbook. | Added EDA cells: missing values and duplicates (35), default rate (22%), undocumented codes in `EDUCATION`/`MARRIAGE`/`PAY_*`, bar chart of default rate by `PAY_0`, histogram of `LIMIT_BAL` by default status, and a notes cell. Ran all cells and checked the plots. | `Oscar/01-working.ipynb` |
| 4 | how many data points (rows) are there in the data set? | Answer: 30,000 rows (29,965 unique; about 6,636 defaults). German Credit has 1,000. | none |
| 5 | I want you to keep a prompt record in my folder of how i directed claude (and direct chatgpt to use it as i will be using that as well). i think ai code is ok to be used but its worth having an audit trail | Created this log, including the ChatGPT instructions. | `Oscar/AI-LOG.md` |
| 6 | create a new notebook to test for how likely it is that these duplicate observations are coincidental or actual duplicates. try to link each variable to an underlying distribution so that you can run statistical tests. final result should be the probability of a repeated row and the probability of what we see now, 35 repeated rows. also worth investigating how many of each duplicate there is, lets start there first | Created a new notebook, step 1 only: all 35 duplicates are pairs; 30 pairs are no-activity accounts (all bills/payments 0; 795 such accounts in the whole dataset) and 5 have identical amounts every month. Wrote findings and a proposed two-part model for step 2. Test-ran it; corrected two wrong counts in the notes. | `Oscar/02-duplicates.ipynb` |
| 7 | for this test we can assume independence of columns, we are just trying to check if these rows are actually duplicates | Added steps 2-3: categorical distribution per column, match chance sum p², expected pairs λ = n(n-1)/2·q per activity type, Poisson test, 10,000-run simulation check, a check with the `PAY_*` columns treated as one pattern, and conclusions. Result: ~16 coincidental pairs expected; P(≥35) ≈ 2e-5; the 5 same-every-month pairs are almost certainly real duplicates. Test-ran it and checked the plot. | `Oscar/02-duplicates.ipynb` |
| 8 | so it looks like the same amount each month are real duplicates? | Answer: yes, most likely. Checked how common the monthly amounts are (390 has 27 accounts, 2,400 has 29). Found near-duplicates: IDs 12431/12433/14295 identical except the default label; 1698/25892 identical except PAY codes -1 vs -2. Suggested a near-duplicate check next. | none |
| 9 | add a summary of the findings to the top of the notebook, include the impact on data quality | Added a summary cell under the title: findings, data-quality impact (size, train/test leakage, label noise, inconsistent PAY codes, 35 is a lower bound), and a recommendation. Updated the intro line. | `Oscar/02-duplicates.ipynb` |
| 10 | lets do some plots to identify the main regressors in prediction | Created a new notebook: mutual information of each column with default (ranked bar chart, coloured by column group) and a Spearman correlation heatmap of the predictors. Test-ran it and checked both plots. Found that AGE's MI of 0 is an estimator artefact (0.0026 when treated as discrete) and wrote notes on the findings. | `Oscar/03-predictors.ipynb` |
| 11 | create a new notebook for logistic regression | Created a baseline logistic regression notebook: drops exact duplicates, 75/25 stratified split, scaler + LogisticRegression, test AUC 0.72 / accuracy 0.81 (vs 0.78 baseline), ROC curve, standardised-coefficient chart, and notes on collinearity (BILL_AMT sign flips) and next steps (one-hot codes, PAY_* bins, log amounts). Fixed a `RocCurveDisplay` argument error by plotting `roc_curve` directly. Test-ran it and checked the plots. | `Oscar/04-logistic.ipynb` |

What I checked / changed myself:
