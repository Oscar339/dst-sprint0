"""Discrete-time hazard model: Taiwan credit-card default (Python translation of 02-hazard-model.R - translated by Claude for the sake of the project all being in python.).

Using only the first 3 observed months (Apr-Jun 2005), predict the probability of first default in
each later month (Jul-Oct 2005). This is a line-by-line translation of `02-hazard-model.R`, which in
turn follows Botha & Muller's scripts 5b(ii), 6c and 6d. Section numbers, object names and printed
results match the R script.

ADAPTED FROM (MIT licence, copyright (c) 2023 Dr Arno Botha):
  Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of default risk under
    IFRS 9: A tutorial using discrete-time survival analysis [source code], v1.0.
    https://doi.org/10.5281/zenodo.15856389
    https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
  accompanying Botha, A. & Verster, T. (2025), arXiv:2507.15441.
  Their R functions (copied unchanged in 02-hazard-functions-BothaMuller.R) are translated here
  under the same names: coefDeter_glm, evalLR, TimeDef_Form, calc_AIC, aicTable, calc_conc,
  concTable, tBrierScore. The R header lists every change made for our data and why.

R -> Python equivalents used here:
  glm(..., family="binomial", weights=)    -> statsmodels GLM(Binomial, freq_weights=)
  sandwich::vcovHC(type="HC0") + coeftest  -> .fit(cov_type="HC0")
  survival::survfit / survminer::surv_summary -> statsmodels SurvfuncRight (Kaplan-Meier)
  survival::concordance (binary outcome)   -> sklearn roc_auc_score on the linear predictor
  pROC::roc / auc                          -> sklearn roc_auc_score

  foreach / doParallel                     -> a plain loop (only 10 single-factor models)

Run from the repository root or Alex/, after report/01 has made the cleaned data:
    python Alex/02-hazard-model.py           # threshold 2, default weight 1
    python Alex/02-hazard-model.py 3         # threshold 3 (90+ days)
    python Alex/02-hazard-model.py 2 10      # their default weight of 10
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
from statsmodels.duration.survfunc import SurvfuncRight

pd.set_option("display.width", 120)


# 0. Setup (after 0.Setup.R)

sDefThresh = int(sys.argv[1]) if len(sys.argv) > 1 else 2        # months behind = event
sWeightDflt = float(sys.argv[2]) if len(sys.argv) > 2 else 1     # theirs: 10
sWeightDflt = int(sWeightDflt) if sWeightDflt == int(sWeightDflt) else sWeightDflt

root = Path.cwd().parent if Path.cwd().name == "Alex" else Path.cwd()
genFigPath = root / "Alex" / "figures"
genFigPath.mkdir(exist_ok=True)
print("Event threshold: PAY >=", sDefThresh, "months behind | default weight:", sWeightDflt)


def percent(x, accuracy=0.01):
    """scales::percent()"""
    decimals = max(0, -int(np.floor(np.log10(accuracy))))
    return f"{100 * x:.{decimals}f}%"


# --- Translations of Botha & Muller's functions (originals in 02-hazard-functions-BothaMuller.R)

def coefDeter_glm(model, model_base=None):
    """0a: McFadden, Cox-Snell and Nagelkerke pseudo R^2 for a binary glm."""
    L_full = model.llf                                    # log-likelihood of fitted model, ln(L_M)
    nobs = model.nobs
    L_base = model_base.llf                               # log-likelihood of the null model, ln(L_0)
    # R's null.deviance: intercept-only model, or (no intercept) the model with eta = 0, i.e. p = 1/2
    w = model.model.freq_weights
    has_intercept = "Intercept" in model.params.index
    null_deviance = model.null_deviance if has_intercept else 2 * np.sum(w) * np.log(2)
    coef_McFadden = 1 - model.deviance / null_deviance
    # The following check will fail if the given model does not contain an intercept
    if abs(coef_McFadden - (1 - (-2 * L_full) / (-2 * L_base))) > 0.000001:
        if has_intercept:
            raise RuntimeError("Internal function error in calculating & verifying McFadden's pseudo R^2-measure")
        print("NOTE: Provided model contains no intercept term.")
        coef_McFadden = 1 - (-2 * L_full) / (-2 * L_base)
    coef_CoxSnell = 1 - np.exp(2 / nobs * (L_base - L_full))
    coef_Nagelkerke = (1 - np.exp((model.deviance - null_deviance) / nobs)) / (1 - np.exp(-null_deviance / nobs))
    return pd.DataFrame({"McFadden": [percent(coef_McFadden)], "CoxSnell": [percent(coef_CoxSnell)],
                         "Nagelkerke": [percent(coef_Nagelkerke)]})


def evalLR(model, model_base, datGiven, targetFld, predClass):
    """0a: evaluation function for glm-based objects."""
    result1 = model.aic
    result2 = coefDeter_glm(model, model_base)
    matPred = model.predict(datGiven)
    actuals = np.where(datGiven[targetFld] == predClass, 1, 0)
    result3 = roc_auc_score(actuals, matPred)
    return pd.concat([pd.DataFrame({"AIC": [f"{result1:,.0f}"]}), result2,
                      pd.DataFrame({"AUC": [percent(result3)]})], axis=1)


def TimeDef_Form(TimeDef, variables, strataVar=""):
    """0b: formula object based on the time definition (only "Cox_Discrete" is used here)."""
    if TimeDef[0] == "Cox_Discrete":
        return TimeDef[1] + " ~ " + " + ".join(variables)
    raise ValueError("Unkown time definition")


def calc_AIC(formula, data_train, variables="", modelType="Cox_Discrete"):
    """0b: AIC and p-value of a single-factor model."""
    try:
        model = smf.glm(formula, data=data_train, family=sm.families.Binomial()).fit()
        if len(model.params) == 0:
            raise ValueError("empty model")
        return pd.DataFrame({"Variable": [variables], "AIC": [model.aic], "pValue": [model.pvalues.iloc[0]]})
    except Exception:
        return pd.DataFrame({"Variable": [variables], "AIC": [np.inf], "pValue": [np.nan]})


def aicTable(data_train, variables, TimeDef, modelType="Cox_Discrete"):
    """0b: AIC from single-factor models, sorted ascending."""
    results = pd.concat([calc_AIC(TimeDef_Form(TimeDef, [v]), data_train, v, modelType) for v in variables])
    return results.sort_values("AIC", kind="stable").reset_index(drop=True)


def calc_conc(formula, data_train, data_valid, variables="", modelType="Cox_Discrete"):
    """0b: concordance of a single-factor model on the validation set."""
    try:
        model = smf.glm(formula, data=data_train, family=sm.families.Binomial()).fit()
        if len(model.params) == 0:
            raise ValueError("empty model")
        lp = model.predict(data_valid, which="linear")
        conc = roc_auc_score(data_valid[formula.split(" ~ ")[0]], lp)
    except Exception:
        conc = 0.5   # R's concordance() of an empty model: all predictions tied
    return pd.DataFrame({"Variable": [variables], "Concordance": [conc]})


def concTable(data_train, data_valid, variables, TimeDef, modelType="Cox_Discrete"):
    """0b: concordance from single-factor models, sorted descending."""
    results = pd.concat([calc_conc(TimeDef_Form(TimeDef, [v]), data_train, data_valid, v, modelType) for v in variables])
    return results.sort_values("Concordance", ascending=False, kind="stable").reset_index(drop=True)


def km_table(durations, events):
    """survfit() + surv_summary(): Kaplan-Meier table at each observed time."""
    km = SurvfuncRight(durations, events)
    times = np.sort(np.unique(durations))
    n_risk = np.array([(durations >= t).sum() for t in times])
    n_event = np.array([((durations == t) & (events == 1)).sum() for t in times])
    n_censor = np.array([((durations == t) & (events == 0)).sum() for t in times])
    surv = np.cumprod(1 - n_event / n_risk)
    assert np.allclose(surv[n_event > 0], km.surv_prob)   # same product-limit estimate as statsmodels
    return pd.DataFrame({"time": times, "n.risk": n_risk, "n.event": n_event, "n.censor": n_censor, "surv": surv})


def tBrierScore(datGiven, modGiven, predType="response", spellPeriodMax=300, fldKey="PerfSpell_Key",
                fldStart="Start", fldStop="TimeInPerfSpell", fldEvent="PerfSpell_Event",
                fldCensored="PerfSpell_Censored", fldSpellAge="PerfSpell_Age",
                fldSpellOutcome="PerfSpellResol_Type_Hist"):
    """0e: time-dependent Brier score (Graf et al., 1999) with IPCW, and the IBS."""
    datGiven = datGiven.copy()
    spells = datGiven.groupby(fldKey).agg(age=(fldSpellAge, "first"), cens=(fldCensored, "max"),
                                          evt=(fldEvent, "max"))
    # --- Censoring survival G(t) (Kaplan-Meier, at times where censoring occurs)
    kmC = km_table(spells["age"].to_numpy(), spells["cens"].to_numpy())
    kmC = kmC[kmC["n.event"] > 0]
    datG = pd.DataFrame({fldStop: kmC["time"], "G_t": kmC["surv"]})
    datG_ti = pd.DataFrame({"EventTime": kmC["time"], "G_Ti": kmC["surv"]})
    # --- Main-event survival S_0(t), the baseline for the pseudo R^2
    kmT = km_table(spells["age"].to_numpy(), spells["evt"].to_numpy())
    kmT = kmT[kmT["n.event"] > 0]
    datT = pd.DataFrame({fldStop: kmT["time"], "Survival_0": kmT["surv"]})
    # --- Predicted hazard and survival
    datGiven["Hazard"] = modGiven.predict(datGiven)
    datGiven["Survival"] = (1 - datGiven["Hazard"]).groupby(datGiven[fldKey]).cumprod()
    datGiven = datGiven.merge(datG, on=fldStop, how="left")
    datGiven["G_t"] = datGiven["G_t"].fillna(1)
    datGiven = datGiven.merge(datT, on=fldStop, how="left")
    datGiven["Survival_0"] = datGiven["Survival_0"].fillna(1)
    datGiven = datGiven.merge(datG_ti, left_on=fldSpellAge, right_on="EventTime", how="left")
    datGiven["G_Ti"] = datGiven["G_Ti"].fillna(1)
    # --- tBS components
    datGiven["y_t"] = (datGiven[fldSpellAge] > datGiven[fldStop]).astype(int)
    datGiven["Weight_w"] = np.where(
        (datGiven[fldSpellAge] <= datGiven[fldStop]) & (datGiven[fldSpellOutcome] == "Defaulted"), 1 / datGiven["G_Ti"],
        np.where(datGiven[fldSpellAge] > datGiven[fldStop], 1 / datGiven["G_t"], 0))
    datGiven["SquaredError"] = (datGiven["y_t"] - datGiven["Survival"]) ** 2
    datGiven["SquaredError_0"] = (datGiven["y_t"] - datGiven["Survival_0"]) ** 2
    d = datGiven[(datGiven["Weight_w"] > 0) & (datGiven[fldStop] <= spellPeriodMax)]
    datTBS = d.groupby(fldStop).apply(lambda g: pd.Series({
        "Brier": (g["Weight_w"] * g["SquaredError"]).mean(),
        "Brier_0": (g["Weight_w"] * g["SquaredError_0"]).mean()}), include_groups=False).reset_index()
    datTBS["RSquared"] = 1 - datTBS["Brier"] / datTBS["Brier_0"]
    IBS = datTBS["Brier"].mean()
    return {"tBS": datTBS, "IBS": IBS}




# 1. Data preparation (OURS): Taiwan data into their person-month structure

# - Cleaned data (report/01) and Oscar/07's test IDs
dat = pd.read_csv(root / "data" / "processed" / "taiwan-clean.csv")
dat = dat.rename(columns={"default payment next month": "DefaultOct"})
testIDs = pd.read_csv(root / "Alex" / "test-ids-oscar07.csv")["ID"]

# - At risk from month 4: no event in the first 3 months (Apr-Jun)
dat = dat[~((dat["PAY_6"] >= sDefThresh) | (dat["PAY_5"] >= sDefThresh) | (dat["PAY_4"] >= sDefThresh))].copy()
print("customers at risk from month 4:", len(dat))

# - Covariates known at month 3 (June). PAY codes -2, -1, 0 are categories, not numbers.
dat["Status_M3"] = pd.Categorical(np.where(dat["PAY_4"] >= 0, "0+", dat["PAY_4"].astype(str)),
                                  categories=["-2", "-1", "0+"])
dat["Utilisation_M3"] = dat["BILL_AMT4"] / dat["LIMIT_BAL"]     # June bill / credit limit
dat["logPay_M3"] = np.log1p(dat["PAY_AMT4"])                    # amount paid in June
dat["logLimit"] = np.log(dat["LIMIT_BAL"])
for c in ("SEX", "EDUCATION", "MARRIAGE"):
    dat[c] = pd.Categorical(dat[c].astype(str), categories=sorted(dat[c].astype(str).unique()))

# - Time to first event within the window (spell time 1..4 = Jul..Oct); 4 = censored at Oct
E4, E5 = dat["PAY_3"] >= sDefThresh, dat["PAY_2"] >= sDefThresh
E6, E7 = dat["PAY_1"] >= sDefThresh, dat["DefaultOct"] == 1
dat["PerfSpell_Age"] = np.select([E4, E5, E6], [1, 2, 3], default=4)
dat["Event"] = (E4 | E5 | E6 | E7).astype(int)

# - Expand to one row per customer per month at risk, with their field names
datCredit_smp = dat.loc[dat.index.repeat(dat["PerfSpell_Age"])].rename(columns={"ID": "LoanID"}).reset_index(drop=True)
datCredit_smp["TimeInPerfSpell"] = datCredit_smp.groupby("LoanID").cumcount() + 1
datCredit_smp["Counter"] = datCredit_smp["TimeInPerfSpell"]                  # loan-level row counter
datCredit_smp["PerfSpell_Num"] = 1                                           # one performing spell each
datCredit_smp["PerfSpell_Key"] = datCredit_smp["LoanID"].astype(str) + "_" + datCredit_smp["PerfSpell_Num"].astype(str)
last_row = datCredit_smp["TimeInPerfSpell"] == datCredit_smp["PerfSpell_Age"]
datCredit_smp["PerfSpell_Event"] = ((datCredit_smp["Event"] == 1) & last_row).astype(int)
datCredit_smp["PerfSpell_Censored"] = ((datCredit_smp["Event"] == 0) & last_row).astype(int)
datCredit_smp["PerfSpellResol_Type_Hist"] = np.where(datCredit_smp["Event"] == 1, "Defaulted", "Censored")
datCredit_smp["DefaultStatus1"] = datCredit_smp["PerfSpell_Event"]

# - Create binned version of TimeInPerfSpell for discrete-time hazard models (from 3b)
# CHANGED: their 20 bins span 1-193+ months; we have 4 months, so each month is its own bin
BIN_LEVELS = ["01.[1,1]", "02.(1,2]", "03.(2,3]", "04.4+"]


def timeBinning(x):
    return pd.Categorical(np.select([x == 1, x == 2, x == 3], BIN_LEVELS[:3], default=BIN_LEVELS[3]),
                          categories=BIN_LEVELS)


datCredit_smp["Time_Binned"] = timeBinning(datCredit_smp["TimeInPerfSpell"])
print(datCredit_smp["Time_Binned"].value_counts(normalize=True, sort=False).to_string())

# - Create start point variable (from 3b)
datCredit_smp["Start"] = datCredit_smp["TimeInPerfSpell"] - 1

# - Training / "validation" sets; validation = Oscar/07's test customers
datCredit_train_PWPST = datCredit_smp[~datCredit_smp["LoanID"].isin(testIDs)].copy()
datCredit_valid_PWPST = datCredit_smp[datCredit_smp["LoanID"].isin(testIDs)].copy()
print("person-months: train", len(datCredit_train_PWPST), "| valid", len(datCredit_valid_PWPST),
      "| events", datCredit_smp["PerfSpell_Event"].sum())




# 2. Final model (from 5b(ii).CoxDiscreteTime_Basic.R)

# - Use only performance spells
datCredit_train = datCredit_train_PWPST[datCredit_train_PWPST["PerfSpell_Num"].notna()].copy()
datCredit_valid = datCredit_valid_PWPST[datCredit_valid_PWPST["PerfSpell_Num"].notna()].copy()
del datCredit_train_PWPST, datCredit_valid_PWPST

# - Weigh default cases heavier. as determined interactively based on calibration success (script 6e)
# CHANGED: their weight 10 -> sWeightDflt (1); 10 mis-calibrates our data (see 02-hazard-model.md)
datCredit_train["Weight"] = np.where(datCredit_train["DefaultStatus1"] == 1, sWeightDflt, 1)
datCredit_valid["Weight"] = np.where(datCredit_valid["DefaultStatus1"] == 1, sWeightDflt, 1)   # for merging purposes

# - Fit an "empty" model as a performance gain, used within some diagnostic functions
modLR_base = smf.glm("PerfSpell_Event ~ 1", data=datCredit_train, family=sm.families.Binomial()).fit()

# - Final variables
# CHANGED: their arrears, interest-rate, inflation and recurrency terms don't exist here
vars_basic = ["-1", "Time_Binned", "Status_M3", "Utilisation_M3", "logPay_M3", "logLimit",
              "AGE", "SEX", "EDUCATION", "MARRIAGE"]
formula_basic = "PerfSpell_Event ~ " + " + ".join(vars_basic)
modLR_basic = smf.glm(formula_basic, data=datCredit_train, family=sm.families.Binomial(),
                      freq_weights=datCredit_train["Weight"]).fit()
# Robust (sandwich) standard errors
modLR_basic_robust = smf.glm(formula_basic, data=datCredit_train, family=sm.families.Binomial(),
                             freq_weights=datCredit_train["Weight"]).fit(cov_type="HC0")
# Summary with robust SEs
print(modLR_basic_robust.summary().tables[1])

# - Other diagnostics
print(evalLR(modLR_basic, modLR_base, datCredit_train, targetFld="PerfSpell_Event", predClass=1).to_string(index=False))
# ADDED: the same on the validation (test) set
print(evalLR(modLR_basic, modLR_base, datCredit_valid, targetFld="PerfSpell_Event", predClass=1).to_string(index=False))

# - Test goodness-of-fit using AIC-measure over single-factor models
aicTable_CoxDisc_basic = aicTable(datCredit_train, vars_basic, TimeDef=["Cox_Discrete", "PerfSpell_Event"])

# Test accuracy using c-statistic over single-factor models
concTable_CoxDisc_basic = concTable(datCredit_train, datCredit_valid, vars_basic, TimeDef=["Cox_Discrete", "PerfSpell_Event"])

# - Combine results into a single object
Table_CoxDisc_basic = concTable_CoxDisc_basic.iloc[:, :2].merge(aicTable_CoxDisc_basic, on="Variable", how="left")
print(Table_CoxDisc_basic.to_string())




# 3. Term-structure (from 6c.Analytics_TermStructure_CoxDiscreteTime.R)

# --- Preliminaries
# - Create pointer to the appropriate data object
datCredit = pd.concat([datCredit_train, datCredit_valid], ignore_index=True)
spells = datCredit.groupby("PerfSpell_Key").agg(age=("PerfSpell_Age", "first"), evt=("PerfSpell_Event", "max"),
                                                cens=("PerfSpell_Censored", "max"))

# --- Estimate survival rate of the main event S(t) = P(T >=t) for time-to-event variable T
# - Create survival table (survfit + surv_summary)
datSurv_sub = km_table(spells["age"].to_numpy(), spells["evt"].to_numpy())
print(datSurv_sub.to_string())
datSurv_sub = datSurv_sub.rename(columns={"time": "Time", "n.risk": "AtRisk_n", "n.event": "Event_n",
                                          "n.censor": "Censored_n", "surv": "SurvivalProb_KM"})
datSurv_sub["Hazard_Actual"] = datSurv_sub["Event_n"] / datSurv_sub["AtRisk_n"]
datSurv_sub["CHaz"] = datSurv_sub["Hazard_Actual"].cumsum()   # Created as a sanity check
datSurv_sub["EventRate"] = datSurv_sub["Hazard_Actual"] * datSurv_sub["SurvivalProb_KM"].shift(1, fill_value=1)  # f(t)=h(t).S(t-1)
datSurv_sub = datSurv_sub[(datSurv_sub["Event_n"] > 0) | (datSurv_sub["Censored_n"] > 0)].sort_values("Time")
datSurv_sub["AtRisk_perc"] = datSurv_sub["AtRisk_n"] / datSurv_sub["AtRisk_n"].max()

# --- Estimate survival rate of the censoring event G(t) = P(C >= t) for time-to-censoring variable C
km_Censoring = km_table(spells["age"].to_numpy(), spells["cens"].to_numpy())
print(f"censoring KM: records {len(datCredit)}  n.id {len(spells)}  events {int(km_Censoring['n.event'].sum())}")
# - Extract quantities of interest (summary() only reports times where censoring occurs)
datSurv_censoring = km_Censoring.loc[km_Censoring["n.event"] > 0, ["time", "surv"]].set_axis(
    ["TimeInPerfSpell", "Survival_censoring"], axis=1)
# - Merge Censoring survival probability back to main dataset
datCredit = datCredit.merge(datSurv_censoring, on="TimeInPerfSpell", how="left")
# CHANGED (added): G(t) is missing before month 4 (no censoring yet); fill with 1, as tBrierScore() does
datCredit["Survival_censoring"] = datCredit["Survival_censoring"].fillna(1)

# ------ 3. Constructing expected term-structure of default risk

# --- Handle left-truncated spells by adding a starting record
datAdd = datCredit[(datCredit["Counter"] == 1) & (datCredit["TimeInPerfSpell"] > 1)].copy()
datAdd["Start"] = datAdd["Start"] - 1
datAdd["TimeInPerfSpell"] = datAdd["TimeInPerfSpell"] - 1
datAdd["Counter"] = 0
datCredit = pd.concat([datCredit, datAdd]).sort_values(["PerfSpell_Key", "TimeInPerfSpell"], kind="stable")

# --- Calculate survival quantities of interest
# Compute IPCW-scheme weight
datCredit["Weight"] = 1 / datCredit["Survival_censoring"]
# Predict hazard h(t) = P(T=t | T>= t) in discrete-time
# CHANGED: basic model only (no advanced model)
datCredit["Hazard_bas"] = modLR_basic.predict(datCredit)
# Derive survival probability S(t) = \prod ( 1- hazard)
datCredit["Survival_bas"] = (1 - datCredit["Hazard_bas"]).groupby(datCredit["PerfSpell_Key"]).cumprod()
# Derive discrete density, or event probability f(t) = S(t-1) . h(t)
datCredit["EventRate_bas"] = (datCredit.groupby("PerfSpell_Key")["Survival_bas"].shift(1, fill_value=1)
                              - datCredit["Survival_bas"])

# - Remove added rows
datCredit = datCredit[datCredit["Counter"] > 0]

# --- Period-level aggregation
datSurv_exp = datCredit.groupby("TimeInPerfSpell").apply(lambda g: pd.Series({
    "EventRate_bas": g["EventRate_bas"].mean(),
    "EventRate_Emp": g["PerfSpell_Event"].sum() / len(g),
    "EventRate_IPCW": (g["Weight"] * g["PerfSpell_Event"]).sum() / g["Weight"].sum()}),
    include_groups=False).reset_index().sort_values("TimeInPerfSpell")
datSurv_exp["Survival_bas"] = 1 - datSurv_exp["EventRate_bas"].fillna(0).cumsum()
datSurv_exp["Survival_IPCW"] = 1 - datSurv_exp["EventRate_IPCW"].fillna(0).cumsum()

# ------ 4. Graphing the event density / probability mass function f(t)

# - General parameters
# CHANGED: their spells run to 300 months; ours to 4
sMaxSpellAge = 4
sMaxSpellAge_graph = 4

# - Fitting natural cubic regression splines
# CHANGED: removed (see the R script): with 4 time points a spline has nothing to smooth

# - Calculate MAE between event rates
datFusion = datSurv_sub[datSurv_sub["Time"] <= sMaxSpellAge].merge(
    datSurv_exp.loc[datSurv_exp["TimeInPerfSpell"] <= sMaxSpellAge, ["TimeInPerfSpell", "EventRate_bas"]]
    .rename(columns={"TimeInPerfSpell": "Time"}), on="Time")
MAE_eventProb_bas = (datFusion["EventRate"] - datFusion["EventRate_bas"]).abs().mean()
print(datFusion.assign(Month=datFusion["Time"] + 3)[["Time", "Month", "EventRate", "EventRate_bas"]]
      .rename(columns={"EventRate": "EventRate_Actual"}).round(4).to_string(index=False))
print("MAE (basic):", percent(MAE_eventProb_bas, accuracy=0.0001))

# - Graphing parameters: RColorBrewer "Paired" colours 4 and 6, as in the R script
vCol = {"Actual": "#33A02C", "Exp: Basic": "#E31A1C"}
fig, ax = plt.subplots(figsize=(1200 / 280 * 1.4, 1000 / 280 * 1.4))
ax.plot(datSurv_sub["Time"], datSurv_sub["EventRate"], "o-", color=vCol["Actual"], lw=1.2, ms=3, label="Actual")
ax.plot(datSurv_exp["TimeInPerfSpell"], datSurv_exp["EventRate_bas"], "^-", color=vCol["Exp: Basic"], lw=1.2, ms=3, label="Exp: Basic")
ax.text(2, 0.10, "MAE (basic): " + percent(MAE_eventProb_bas, accuracy=0.0001), family="serif", ha="center", fontsize=9)
ax.yaxis.set_major_formatter(lambda v, _: f"{v:.0%}")
ax.set_xlabel("Performing spell age (months) $t$", family="serif")
ax.set_ylabel("Event probability $f(t)$ [Default]", family="serif")
ax.set_title("Single spell, Jul-Oct 2005", fontsize=8, color="gray", loc="right")
ax.grid(color="0.92"); ax.spines[:].set_visible(False)
ax.legend(frameon=False, ncol=2, loc="upper center", bbox_to_anchor=(0.5, -0.15), prop={"family": "serif"})
fig.tight_layout()
fig.savefig(genFigPath / f"EventProb_Default_ActVsExp_CoxDisc_thresh{sDefThresh}_w{sWeightDflt}_py.png", dpi=280)




# 4. Time-dependent Brier scores (from 6d.Analytics_tBrierScore.R)

# - Create pointer to the appropriate data object
datCredit = pd.concat([datCredit_train, datCredit_valid], ignore_index=True)

# CHANGED: spellPeriodMax 300 -> 3 (everyone still at risk is censored at month 4; see the R script)
objCoxDisc_bas = tBrierScore(datCredit, modGiven=modLR_basic, predType="response", spellPeriodMax=3,
                             fldKey="PerfSpell_Key", fldStart="Start", fldStop="TimeInPerfSpell",
                             fldCensored="PerfSpell_Censored", fldSpellAge="PerfSpell_Age",
                             fldSpellOutcome="PerfSpellResol_Type_Hist")
print(objCoxDisc_bas["tBS"].to_string(index=False))
print("IBS (basic):", round(objCoxDisc_bas["IBS"], 4))




# 5. OURS: P(default by Oct | no default by June) on the test set, vs the October label

# - Predict all 4 months for every test customer, including months after an early default
datTest = dat[dat["ID"].isin(testIDs)]
datTest = datTest.loc[datTest.index.repeat(4)].copy()
datTest["TimeInPerfSpell"] = np.tile(np.arange(1, 5), len(datTest) // 4)
datTest["Time_Binned"] = timeBinning(datTest["TimeInPerfSpell"])
datTest["Hazard"] = modLR_basic.predict(datTest)
datPD = datTest.groupby(["ID", "Event", "DefaultOct"])["Hazard"].apply(lambda h: 1 - np.prod(1 - h)).rename("PD_Oct").reset_index()

print("\nP(default by Oct) vs any default by Oct:  AUC", round(roc_auc_score(datPD["Event"], datPD["PD_Oct"]), 4),
      "  Brier", round(((datPD["Event"] - datPD["PD_Oct"]) ** 2).mean(), 4))
print("P(default by Oct) vs October label only:  AUC", round(roc_auc_score(datPD["DefaultOct"], datPD["PD_Oct"]), 4),
      "  Brier", round(((datPD["DefaultOct"] - datPD["PD_Oct"]) ** 2).mean(), 4))

# - Comparison: one-period logistic regression on the October label, same covariates and customers
covars = [v for v in vars_basic if v not in ("-1", "Time_Binned")]
modLR_oct = smf.glm("DefaultOct ~ " + " + ".join(covars), data=dat[~dat["ID"].isin(testIDs)],
                    family=sm.families.Binomial()).fit()
datPD["PD_LR"] = modLR_oct.predict(dat.set_index("ID").loc[datPD["ID"]].reset_index())
print("One-period logistic (Oct label):          AUC", round(roc_auc_score(datPD["DefaultOct"], datPD["PD_LR"]), 4),
      "  Brier", round(((datPD["DefaultOct"] - datPD["PD_LR"]) ** 2).mean(), 4))
