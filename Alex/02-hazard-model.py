"""Discrete-time hazard model: Taiwan credit-card default (Python translation of 02-hazard-model.R).

Using only the first 3 observed months (Apr-Jun 2005), predict the probability of first default in
each later month (Jul-Oct 2005). This is a line-by-line translation of `02-hazard-model.R`: the
section numbers match, both use the same data and test split, and they print the same results.

ADAPTED FROM (MIT licence, copyright (c) 2023 Dr Arno Botha):
  Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of default risk under
    IFRS 9: A tutorial using discrete-time survival analysis [source code], v1.0.
    https://doi.org/10.5281/zenodo.15856389
    https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
  accompanying Botha, A. & Verster, T. (2025), arXiv:2507.15441.
  Original scripts used: 3b (timeBinning), 5b(ii) (basic DtH model), 0a (evalLR),
  6c (term-structure), 0e (time-dependent Brier score). The header of the R script lists what was
  changed for our data and why, and the definitions of the event, risk set and test set.

R -> Python equivalents used here:
  glm(..., family="binomial", weights=)   -> statsmodels GLM(Binomial, freq_weights=)
  sandwich::vcovHC(type="HC0")            -> .fit(cov_type="HC0")
  survival::survfit(Surv(...))            -> statsmodels SurvfuncRight (Kaplan-Meier)
  pROC::auc                               -> sklearn.metrics.roc_auc_score

Run from the repository root or from Alex/, after report/01 has made the cleaned data:
    python Alex/02-hazard-model.py        # event = 2+ months behind (main run)
    python Alex/02-hazard-model.py 3      # event = 3+ months behind (90+ days, check)
Packages: numpy, pandas, statsmodels, scikit-learn, matplotlib.
"""
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.api as sm
import statsmodels.formula.api as smf
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split
from statsmodels.duration.survfunc import SurvfuncRight

DEF_THRESH = int(sys.argv[1]) if len(sys.argv) > 1 else 2   # months behind = event

ROOT = Path.cwd().parent if Path.cwd().name == "Alex" else Path.cwd()
OUT_FIG = ROOT / "Alex" / "figures"
OUT_FIG.mkdir(exist_ok=True)
print("Event threshold: PAY >=", DEF_THRESH, "months behind")


# ------ 1. Load the cleaned data and the test split

dat = pd.read_csv(ROOT / "data" / "processed" / "taiwan-clean.csv")
dat = dat.rename(columns={"default payment next month": "DefaultOct"})
test_ids = pd.read_csv(ROOT / "Alex" / "test-ids-oscar07.csv")["ID"]
print("customers (cleaned):", len(dat))

# Check the saved IDs are exactly Oscar/07's test set (the split R cannot recreate itself)
_, X_test, _, _ = train_test_split(dat.set_index("ID").drop(columns="DefaultOct"), dat["DefaultOct"],
                                   test_size=0.20, stratify=dat["DefaultOct"], random_state=0)
assert set(X_test.index) == set(test_ids), "test-ids-oscar07.csv does not match Oscar/07's split"


# ------ 2. Scope: at-risk population and covariates frozen at month 3 (June)

# Exclude customers with an event in the first 3 months (step 2)
dat = dat[~((dat["PAY_6"] >= DEF_THRESH) | (dat["PAY_5"] >= DEF_THRESH) | (dat["PAY_4"] >= DEF_THRESH))].copy()
print("at risk from month 4:", len(dat))

# Covariates known at month 3 (June). PAY codes -2, -1, 0 are categories, not numbers.
dat["Status_M3"] = pd.Categorical(np.where(dat["PAY_4"] >= 0, "0+", dat["PAY_4"].astype(str)),
                                  categories=["-2", "-1", "0+"])
dat["Utilisation_M3"] = dat["BILL_AMT4"] / dat["LIMIT_BAL"]     # June bill / credit limit
dat["logPay_M3"] = np.log1p(dat["PAY_AMT4"])                    # amount paid in June
dat["logLimit"] = np.log(dat["LIMIT_BAL"])
for c in ("SEX", "EDUCATION", "MARRIAGE"):
    dat[c] = pd.Categorical(dat[c].astype(str), categories=sorted(dat[c].astype(str).unique()))
COVARS = ["Status_M3", "Utilisation_M3", "logPay_M3", "logLimit", "AGE", "SEX", "EDUCATION", "MARRIAGE"]

dat["Sample"] = np.where(dat["ID"].isin(test_ids), "test", "train")
print(dat["Sample"].value_counts().to_string())


# ------ 3. Person-month data (step 4: one row per customer per month at risk)

evt = dat[["ID", "Sample", *COVARS, "DefaultOct"]].copy()
evt["E4"] = (dat["PAY_3"] >= DEF_THRESH).astype(int)    # Jul
evt["E5"] = (dat["PAY_2"] >= DEF_THRESH).astype(int)    # Aug
evt["E6"] = (dat["PAY_1"] >= DEF_THRESH).astype(int)    # Sep
evt["E7"] = (dat["DefaultOct"] == 1).astype(int)        # Oct (dataset label)

# Time to first event (1..4 months into the window), or 4 with no event (censored at Oct)
first = np.select([evt["E4"] == 1, evt["E5"] == 1, evt["E6"] == 1, evt["E7"] == 1], [1, 2, 3, 4], default=0)
evt["Event"] = (first > 0).astype(int)
evt["Time"] = np.where(first > 0, first, 4)

# Expand: a customer appears in months 1..Time; the event flag is 1 only in the last row if Event
pm = evt.loc[evt.index.repeat(evt["Time"])].copy()
pm["TimeInPerfSpell"] = pm.groupby("ID").cumcount() + 1
pm["PerfSpell_Event"] = ((pm["Event"] == 1) & (pm["TimeInPerfSpell"] == pm["Time"])).astype(int)

BIN_LEVELS = [f"{t:02d}.M{t + 3}" for t in range(1, 5)]


def time_binning(t):
    """timeBinning(), adapted: with only 4 months, each month is its own bin."""
    return pd.Categorical(t.map(lambda x: f"{x:02d}.M{x + 3}"), categories=BIN_LEVELS)


pm["Time_Binned"] = time_binning(pm["TimeInPerfSpell"])
print("person-months:", len(pm), " events:", pm["PerfSpell_Event"].sum())
print(pm.groupby(pm["TimeInPerfSpell"] + 3)["PerfSpell_Event"]
        .agg(AtRisk="size", Events="sum", Hazard="mean").rename_axis("Month").round(4))

train, test = pm[pm["Sample"] == "train"].copy(), pm[pm["Sample"] == "test"].copy()


# ------ 4. Basic discrete-time hazard model (after 5b(ii); step 5)

FORM = "PerfSpell_Event ~ -1 + Time_Binned + " + " + ".join(COVARS)

mod_base = smf.glm("PerfSpell_Event ~ 1", data=train, family=sm.families.Binomial()).fit()   # empty model
fits = {}
for w in (1, 10):                                   # their weight was 10; test it against 1
    weight = np.where(train["PerfSpell_Event"] == 1, w, 1)
    fits[f"w{w}"] = smf.glm(FORM, data=train, family=sm.families.Binomial(), freq_weights=weight).fit()


# ------ 5. evalLR (after 0a): AIC, McFadden R^2 (train), AUC (test person-months)

def eval_lr(model, model_base, dat_given, target="PerfSpell_Event"):
    pred = model.predict(dat_given)
    return pd.DataFrame({"AIC": [round(model.aic)],
                         "McFadden_R2": [round(1 - model.llf / model_base.llf, 4)],
                         "AUC_test": [round(roc_auc_score(dat_given[target], pred), 4)]})


for k, m in fits.items():
    print(f"\n {k}\n", eval_lr(m, mod_base, test).to_string(index=False))


# ------ 6. Term-structure: Kaplan-Meier (empirical) vs model-expected (after 6c)

# Empirical f(t) on test customers
cust_te = evt[evt["Sample"] == "test"].copy()
km = SurvfuncRight(cust_te["Time"], cust_te["Event"])
emp = pd.DataFrame({"t": km.surv_times, "AtRisk": km.n_risk, "Events": km.n_events, "S": km.surv_prob})
emp["Hazard"] = emp["Events"] / emp["AtRisk"]
emp["f_emp"] = emp["Hazard"] * emp["S"].shift(fill_value=1)          # f(t) = h(t) S(t-1)

# Expected f(t): predict h(t) for every test customer on the full 4-month grid
grid = cust_te.loc[cust_te.index.repeat(4)].copy()
grid["TimeInPerfSpell"] = np.tile(np.arange(1, 5), len(cust_te))
grid["Time_Binned"] = time_binning(grid["TimeInPerfSpell"])


def term_struct(model):
    g = grid.copy()
    g["h"] = model.predict(g)
    g["S"] = (1 - g["h"]).groupby(g["ID"]).cumprod()
    g["f"] = g.groupby("ID")["S"].shift(fill_value=1) - g["S"]
    return g


res = emp[["t", "f_emp"]].assign(Month=emp["t"] + 3)
grids = {}
for k, m in fits.items():
    grids[k] = term_struct(m)
    res = res.merge(grids[k].groupby("TimeInPerfSpell")["f"].mean().rename(f"f_{k}"),
                    left_on="t", right_index=True)
print("\nTerm-structure, test customers (f = probability of first default in that month):")
print(res.round(4).to_string(index=False))
mae = {k: (res[f"f_{k}"] - res["f_emp"]).abs().mean() for k in fits}
print("MAE vs empirical:", "  ".join(f"{k} {v:.5f}" for k, v in mae.items()))
best = min(mae, key=mae.get)
mod_basic = fits[best]
print("Better calibrated (kept):", best)

# Robust (HC0) standard errors for the kept model, as in 5b(ii)
weight = np.where(train["PerfSpell_Event"] == 1, int(best[1:]), 1)
robust = smf.glm(FORM, data=train, family=sm.families.Binomial(), freq_weights=weight).fit(cov_type="HC0")
print("\nKept model, robust SEs:\n", robust.summary().tables[1])

# Graph
fig, ax = plt.subplots(figsize=(7, 4))
ax.plot(res["Month"], res["f_emp"], "o-", color="#2a78d6", lw=2, label="Empirical (Kaplan-Meier)")
ax.plot(res["Month"], res[f"f_{best}"], "o-", color="#eb6834", lw=2, label=f"Expected, DtH model ({best})")
ax.set_xticks([4, 5, 6, 7], ["Jul", "Aug", "Sep", "Oct"])
ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
ax.set_ylabel("probability of first default in month, f(t)")
ax.set_title("Term-structure of default risk, test customers\n"
             f"Default = {DEF_THRESH}+ months behind (Jul-Sep) or dataset label (Oct)", loc="left", fontsize=10)
ax.spines[["top", "right"]].set_visible(False)
ax.legend(frameon=False, loc="upper left")
fig.tight_layout()
fig.savefig(OUT_FIG / f"hazard-term-structure-py-thresh{DEF_THRESH}.png", dpi=150)


# ------ 7. Time-dependent Brier score and IBS (after 0e; no censoring before Oct, so no IPCW)

g = grids[best][["ID", "TimeInPerfSpell", "S"]].rename(columns={"TimeInPerfSpell": "t"})
g["PD_cum"] = 1 - g["S"]
g = g.merge(cust_te[["ID", "Time", "Event", "DefaultOct"]], on="ID")
g["Y"] = ((g["Event"] == 1) & (g["Time"] <= g["t"])).astype(int)   # defaulted by month t?
tbs = g.groupby(g["t"] + 3)[["Y", "PD_cum"]].apply(lambda d: ((d["Y"] - d["PD_cum"]) ** 2).mean()).rename("tBS")
print("\nTime-dependent Brier score:\n", tbs.rename_axis("Month").round(4).to_string())
print("IBS (uniform weights):", round(tbs.mean(), 4))


# ------ 8. Step 7/8: P(T <= 7 | T > 3, x), scored against the October label (headline metrics)

last = g[g["t"] == 4]
print("\nP(event by Oct)  vs any event by Oct:   AUC", round(roc_auc_score(last["Y"], last["PD_cum"]), 4),
      "  Brier", round(((last["Y"] - last["PD_cum"]) ** 2).mean(), 4))
print("P(event by Oct)  vs October label only: AUC", round(roc_auc_score(last["DefaultOct"], last["PD_cum"]), 4),
      "  Brier", round(((last["DefaultOct"] - last["PD_cum"]) ** 2).mean(), 4))

# Comparison: one-period logistic regression on the October label, same covariates and customers
lr = smf.glm("DefaultOct ~ " + " + ".join(COVARS), data=evt[evt["Sample"] == "train"],
             family=sm.families.Binomial()).fit()
p_lr = lr.predict(cust_te)
print("One-period logistic (Oct label):        AUC", round(roc_auc_score(cust_te["DefaultOct"], p_lr), 4),
      "  Brier", round(((cust_te["DefaultOct"] - p_lr) ** 2).mean(), 4))
