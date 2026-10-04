# Data

`data/raw/` holds the datasets exactly as published: downloaded, unzipped,
never edited. It is **not committed** (see `.gitignore`), so re-create it from
the links below. Anything derived goes in `data/processed/`, made by code.

## Use the cleaned Taiwan data

**For any Taiwan analysis, load `data/processed/taiwan-clean.csv`, not the raw
`.xls`.** It is not committed. Make it by running `report/01-Introduction.ipynb`
top to bottom: it downloads the raw data, cleans it and saves the file. Then:

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

Notes for reading it:
* The Taiwan file is an old-format Excel `.xls`, with a title row above the
  real header row. pandas needs the `xlrd` package to read `.xls`.

Cite as: Yeh, I-C. (2009) *Default of Credit Card Clients* [dataset], UCI,
doi:10.24432/C55S3H.
