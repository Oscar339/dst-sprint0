# Data

`data/raw/` holds the datasets exactly as published: downloaded, unzipped,
never edited. It is **not committed** (see `.gitignore`), so re-create it from
the links below. Anything derived goes in `data/processed/`, made by code.

## Use the cleaned Taiwan data

**For any Taiwan analysis, load `data/processed/taiwan-clean.csv`, not the raw
`.xls`.** It is not committed. Make it by running `Oscar/05-cleaning.ipynb`
top to bottom (after `report/01-Introduction.ipynb` has downloaded the raw
data). Then:

```python
taiwan = pd.read_csv(ROOT / "data" / "processed" / "taiwan-clean.csv", index_col="ID")
```

Changes from the raw file (29,995 rows; reasons in `Oscar/01-working` and
`Oscar/02-duplicates`):

* 5 duplicate customers removed (IDs 14295, 20876, 21882, 27352, 29266).
* `PAY_0` renamed `PAY_1`, so month 1 (September 2005) matches `BILL_AMT1` and `PAY_AMT1`.
* `EDUCATION` 0, 5, 6 merged into 4 (others); `MARRIAGE` 0 merged into 3 (others).
* `PAY_*` values -2 and 0 are **left as they are**. They are undocumented
  status codes, not amounts of delay, so treat -2/-1/0 as categories when modelling.

Downloaded 26 Sep 2026 from the UCI Machine Learning Repository.

| File | Source | SHA-256 |
|---|---|---|
| `raw/taiwan-credit-default/default of credit card clients.xls` | [UCI 350 — Default of Credit Card Clients](https://archive.ics.uci.edu/dataset/350/default+of+credit+card+clients) ([zip](https://archive.ics.uci.edu/static/public/350/default+of+credit+card+clients.zip)) | `30c6be3a…00933` |
| `raw/german-credit/german.data` | [UCI 144 — Statlog (German Credit Data)](https://archive.ics.uci.edu/dataset/144/statlog+german+credit+data) ([zip](https://archive.ics.uci.edu/static/public/144/statlog+german+credit+data.zip)) | `b21f3d81…cb5871` |
| `raw/german-credit/german.data-numeric` | same zip — numeric-coded version | `2752b044…ec02f8` |
| `raw/german-credit/german.doc` | same zip — the codebook (what `A11`, `A34`… mean) and the cost matrix | `69b92cb5…fe49` |
| `raw/german-credit/Index` | same zip — file listing | `30cd5a2e…501e91` |

Notes for reading them:
* The Taiwan file is an old-format Excel `.xls`, with a title row above the
  real header row. pandas needs the `xlrd` package to read `.xls`.
* `german.data` is space-separated with no header; column names and codes
  are in `german.doc`. Class 1 = good, 2 = bad.

Cite as: Yeh, I-C. (2009) *Default of Credit Card Clients* [dataset], UCI,
doi:10.24432/C55S3H; Hofmann, H. (1994) *Statlog (German Credit Data)*
[dataset], UCI, doi:10.24432/C5NC77.
