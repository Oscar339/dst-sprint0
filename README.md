# Data Science Toolbox — Sprint 0: <domain title>

Formative Sprint 0 for [Data Science Toolbox](https://dsbristol.github.io/dst/)
(MATHM0029, University of Bristol, 2026-27): a literature review of the
resources for doing data science in **<domain>**. Laid out after the unit's
[example project](https://github.com/dsbristol/dst_example_project).

Repository: https://github.com/Oscar339/dst-sprint0

## Project Group

* Oscar Butler
* Alex <surname>
* Louis <surname>

Equity: <agree before starting — e.g. "equal 1/3 each">.

<One line per person on what they contributed, filled in at the end.>

## Reading order

All report content is in `report/`, read in this order:

1. `01-Introduction.ipynb` — the domain, the questions, and getting the data.
2. `02-...ipynb` — <resource / analysis>
3. `03-...ipynb` — <resource / analysis>
4. `NN-Wrapup.ipynb` — what the resources can and cannot do, and conclusions.

Each notebook runs top to bottom from a fresh clone. Executed copies (with
output) are committed for the final submission.

### Requirements

Python 3.13. From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Data is downloaded by `report/01-Introduction.ipynb` into `data/raw/` (not
committed). Any manual step is stated in the notebook where it happens.

**Taiwan data: use the cleaned version.** Run `report/01-Introduction.ipynb` to make
`data/processed/taiwan-clean.csv`, and load that instead of the raw `.xls`. See
`data/README.md` for what was changed.

## Evidence

Each member's working, including dead ends, is in their own folder:

* `Oscar/`
* `Alex/`
* `Louis/`

## References

<Every book, website, repository and paper used, with links.>
