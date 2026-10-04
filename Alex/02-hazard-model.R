# ================== DISCRETE-TIME HAZARD MODEL: Taiwan credit-card default ==================
# Using only the first 3 observed months (Apr-Jun 2005), predict the probability of first
# default in each later month (Jul-Oct 2005) with a discrete-time hazard (DtH) model.
# Implements steps 0-2, 4, 5, 7 and 8 of 02-survival-analysis.md, section 7.
# ---------------------------------------------------------------------------------------------
# PROJECT: Data Science Toolbox, Sprint 0 (MATHM0029, University of Bristol, 2026-27)
# AUTHOR:  Alex. Python translation: 02-hazard-model.py
# ---------------------------------------------------------------------------------------------
# ADAPTED FROM (MIT licence, copyright (c) 2023 Dr Arno Botha):
#   Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of default risk
#     under IFRS 9: A tutorial using discrete-time survival analysis [source code], v1.0.
#     https://doi.org/10.5281/zenodo.15856389
#     https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
#   accompanying: Botha, A. & Verster, T. (2025). arXiv:2507.15441.
#
#   How this script maps onto theirs:
#     Sec 0  <- 0.Setup.R (only the packages used here) + their functions, copied unchanged into
#               02-hazard-functions-BothaMuller.R (0a evalLR/coefDeter_glm, 0b aicTable/concTable,
#               0e tBrierScore)
#     Sec 1  <- OURS: Taiwan data prepared into their data structure and column names (their
#               scripts 1-3b prepare a private mortgage dataset and can't be reused). Ends with
#               their timeBinning() and Start lines from 3b.
#     Sec 2  <- 5b(ii).CoxDiscreteTime_Basic.R, line for line
#     Sec 3  <- 6c.Analytics_TermStructure_CoxDiscreteTime.R, line for line (basic model only)
#     Sec 4  <- 6d.Analytics_tBrierScore.R (basic discrete-time model only)
#     Sec 5  <- OURS: score P(default by Oct) against the October label on the test set
#
#   Lines changed inside sections 2-4 are marked "# CHANGED:" with the reason. In short:
#     * vars_basic: their arrears, interest-rate, inflation and recurrency terms don't exist in
#       our data; ours are frozen at June (our scope: first 3 months only).
#     * Default weight: theirs is 10; on our data 10 mis-calibrates badly (run with 2nd argument
#       10 to see), so the default here is 1.
#     * Advanced model, spline smoothing, axis ranges and labels: removed or resized for 4 months.
#
# -- DEFINITIONS:
#   * Month t: Apr=1, May=2, Jun=3 | Jul=4, Aug=5, Sep=6, Oct=7. Spell time TimeInPerfSpell = t-3.
#   * Event (default): first month with repayment status PAY >= sDefThresh months behind
#     (Jul, Aug or Sep), or the dataset's label "default payment next month" = 1 (Oct).
#     Main run sDefThresh = 2 (02-survival-analysis.md, step 1); check with 3 (90+ days).
#   * At risk from month 4: customers with no event in Apr-Jun. One performing spell each.
#   * "First 3 months" = first 3 OBSERVED months; the data has no account-opening date.
#   * Their "validation" set = Oscar/07's 20% test set (IDs in Alex/test-ids-oscar07.csv).
#
#      Rscript Alex/02-hazard-model.R            # threshold 2, default weight 1
#      Rscript Alex/02-hazard-model.R 3          # threshold 3 (90+ days)
#      Rscript Alex/02-hazard-model.R 2 10       # their default weight of 10
# =============================================================================================




# 0. Setup (after 0.Setup.R)

require(dplyr)
require(data.table)
require(foreach)
require(doParallel)
require(survival) # for survival modelling
require(pROC) # for cross-sectional ROC-analysis
require(sandwich) # for robust variance estimators when using weights in glm()
require(lmtest) # for coeftest() "summary" given robust variance estimators
require(scales)
require(survminer)
require(ggplot2)
require(RColorBrewer)

args <- commandArgs(trailingOnly = TRUE)
sDefThresh  <- if (length(args) > 0) as.integer(args[1]) else 2L   # months behind = event
sWeightDflt <- if (length(args) > 1) as.numeric(args[2]) else 1    # theirs: 10

root <- if (basename(getwd()) == "Alex") ".." else "."
genPath <- paste0(tempdir(), "/"); genObjPath <- genPath            # log files of aicTable()/concTable()
genFigPath <- paste0(root, "/Alex/figures/"); dir.create(genFigPath, showWarnings = FALSE)
if (.Platform$OS.type == "windows") windowsFonts(Cambria = windowsFont("Cambria"))   # their extrafont setup
if (!interactive()) png(tempfile(fileext = ".png"))   # Rscript: print plots to a font-aware device, not Rplots.pdf
source(file.path(root, "Alex", "02-hazard-functions-BothaMuller.R"))
cat("Event threshold: PAY >=", sDefThresh, "months behind | default weight:", sWeightDflt, "\n")




# 1. Data preparation (OURS): Taiwan data into their person-month structure

# - Cleaned data (report/01) and Oscar/07's test IDs
dat <- fread(file.path(root, "data", "processed", "taiwan-clean.csv"))
setnames(dat, "default payment next month", "DefaultOct")
testIDs <- fread(file.path(root, "Alex", "test-ids-oscar07.csv"))$ID

# - At risk from month 4: no event in the first 3 months (Apr-Jun)
dat <- dat[!(PAY_6 >= sDefThresh | PAY_5 >= sDefThresh | PAY_4 >= sDefThresh)]
cat("customers at risk from month 4:", nrow(dat), "\n")

# - Covariates known at month 3 (June). PAY codes -2, -1, 0 are categories, not numbers.
dat[, Status_M3      := factor(fifelse(PAY_4 >= 0, "0+", as.character(PAY_4)), levels = c("-2", "-1", "0+"))]
dat[, Utilisation_M3 := BILL_AMT4 / LIMIT_BAL]          # June bill / credit limit
dat[, logPay_M3      := log1p(PAY_AMT4)]                # amount paid in June
dat[, logLimit       := log(LIMIT_BAL)]
dat[, `:=`(SEX = factor(SEX), EDUCATION = factor(EDUCATION), MARRIAGE = factor(MARRIAGE))]

# - Time to first event within the window (spell time 1..4 = Jul..Oct); 4 = censored at Oct
dat[, E4 := PAY_3 >= sDefThresh]; dat[, E5 := PAY_2 >= sDefThresh]
dat[, E6 := PAY_1 >= sDefThresh]; dat[, E7 := DefaultOct == 1]
dat[, PerfSpell_Age := fifelse(E4, 1L, fifelse(E5, 2L, fifelse(E6, 3L, 4L)))]
dat[, Event := as.integer(E4 | E5 | E6 | E7)]

# - Expand to one row per customer per month at risk, with their field names
datCredit_smp <- dat[rep(seq_len(.N), PerfSpell_Age)]
setnames(datCredit_smp, "ID", "LoanID")
datCredit_smp[, TimeInPerfSpell := seq_len(.N), by = LoanID]
datCredit_smp[, Counter := TimeInPerfSpell]                       # loan-level row counter
datCredit_smp[, PerfSpell_Num := 1L]                              # one performing spell each
datCredit_smp[, PerfSpell_Key := paste0(LoanID, "_", PerfSpell_Num)]
datCredit_smp[, PerfSpell_Event := as.integer(Event == 1 & TimeInPerfSpell == PerfSpell_Age)]
datCredit_smp[, PerfSpell_Censored := as.integer(Event == 0 & TimeInPerfSpell == PerfSpell_Age)]
datCredit_smp[, PerfSpellResol_Type_Hist := fifelse(Event == 1, "Defaulted", "Censored")]
datCredit_smp[, DefaultStatus1 := PerfSpell_Event]

# - Create binned version of TimeInPerfSpell for discrete-time hazard models (from 3b)
# CHANGED: their 20 bins span 1-193+ months; we have 4 months, so each month is its own bin
timeBinning <- function(x) {
  case_when(
    x == 1 ~ "01.[1,1]", x == 2 ~ "02.(1,2]",
    x == 3 ~ "03.(2,3]", TRUE ~ "04.4+"
  )
}
datCredit_smp[, Time_Binned := timeBinning(TimeInPerfSpell)]
print(table(datCredit_smp$Time_Binned) %>% prop.table())

# - Create start point variable (from 3b)
datCredit_smp[, Start := TimeInPerfSpell - 1]

# - Training / "validation" sets; validation = Oscar/07's test customers
datCredit_train_PWPST <- datCredit_smp[!(LoanID %in% testIDs)]
datCredit_valid_PWPST <- datCredit_smp[LoanID %in% testIDs]
cat("person-months: train", nrow(datCredit_train_PWPST), "| valid", nrow(datCredit_valid_PWPST),
    "| events", sum(datCredit_smp$PerfSpell_Event), "\n")




# 2. Final model (from 5b(ii).CoxDiscreteTime_Basic.R)

# - Use only performance spells
datCredit_train <- datCredit_train_PWPST[!is.na(PerfSpell_Num),]
datCredit_valid <- datCredit_valid_PWPST[!is.na(PerfSpell_Num),]
# remove previous objects from memory
rm(datCredit_train_PWPST, datCredit_valid_PWPST); invisible(gc())

# - Weigh default cases heavier. as determined interactively based on calibration success (script 6e)
# CHANGED: their weight 10 -> sWeightDflt (1); 10 mis-calibrates our data (see 02-hazard-model.md)
datCredit_train[, Weight := ifelse(DefaultStatus1==1,sWeightDflt,1)]
datCredit_valid[, Weight := ifelse(DefaultStatus1==1,sWeightDflt,1)] # for merging purposes

# - Fit an "empty" model as a performance gain, used within some diagnostic functions
modLR_base <- glm(PerfSpell_Event ~ 1, data=datCredit_train, family="binomial")

# - Final variables
# CHANGED: their "log(TimeInPerfSpell):PerfSpell_Num_binned", "Arrears", "InterestRate_Nom",
#          "M_Inflation_Growth_6" don't exist here; ours are frozen at June (step 7 of the plan)
vars_basic <- c("-1", "Time_Binned", "Status_M3", "Utilisation_M3", "logPay_M3", "logLimit",
                "AGE", "SEX", "EDUCATION", "MARRIAGE")
modLR_basic <- glm( as.formula(paste("PerfSpell_Event ~", paste(vars_basic, collapse = " + "))),
              data=datCredit_train, family="binomial", weights = Weight)
#summary(modLR);
# Robust (sandwich) standard errors
robust_se <- vcovHC(modLR_basic, type="HC0")
# Summary with robust SEs
print(coeftest(modLR_basic, vcov.=robust_se))

# - Other diagnostics
print(evalLR(modLR_basic, modLR_base, datCredit_train, targetFld="PerfSpell_Event", predClass=1))
# ADDED: the same on the validation (test) set
print(evalLR(modLR_basic, modLR_base, datCredit_valid, targetFld="PerfSpell_Event", predClass=1))

# - Test goodness-of-fit using AIC-measure over single-factor models
aicTable_CoxDisc_basic <- aicTable(datCredit_train, vars_basic, TimeDef=c("Cox_Discrete","PerfSpell_Event"), genPath=genObjPath, modelType="Cox_Discrete")

# Test accuracy using c-statistic over single-factor models
concTable_CoxDisc_basic <- concTable(datCredit_train, datCredit_valid, vars_basic, TimeDef=c("Cox_Discrete","PerfSpell_Event"), genPath=genObjPath, modelType="Cox_Discrete")

# - Combine results into a single object
Table_CoxDisc_basic <- concTable_CoxDisc_basic[,1:2] %>% left_join(aicTable_CoxDisc_basic, by ="Variable")
print(Table_CoxDisc_basic)




# 3. Term-structure (from 6c.Analytics_TermStructure_CoxDiscreteTime.R)

# ------ 2. Kaplan-Meier estimation towards constructing empirical term-structure of default risk

# --- Preliminaries
# - Create pointer to the appropriate data object
datCredit <- rbind(datCredit_train, datCredit_valid)


# --- Estimate survival rate of the main event S(t) = P(T >=t) for time-to-event variable T
# Compute Kaplan-Meier survival estimates (product-limit) for main-event | Spell-level with right-censoring & left-truncation
km_Default <- survfit(Surv(time=TimeInPerfSpell-1, time2=TimeInPerfSpell, event=PerfSpell_Event==1, type="counting") ~ 1,
                      id=PerfSpell_Key, data=datCredit)

# - Create survival table using surv_summary(), from the subsampled set
(datSurv_sub <- surv_summary(km_Default)) # Survival table
datSurv_sub <- datSurv_sub %>% rename(Time=time, AtRisk_n=`n.risk`, Event_n=`n.event`, Censored_n=`n.censor`, SurvivalProb_KM=`surv`) %>%
  mutate(Hazard_Actual = Event_n/AtRisk_n) %>%
  mutate(CHaz = cumsum(Hazard_Actual)) %>% # Created as a sanity check
  mutate(EventRate = Hazard_Actual*shift(SurvivalProb_KM, n=1, fill=1)) %>%  # probability mass function f(t)=h(t).S(t-1)
  filter(Event_n > 0 | Censored_n >0) %>% as.data.table()
setorder(datSurv_sub, Time)
datSurv_sub[,AtRisk_perc := AtRisk_n / max(AtRisk_n, na.rm=T)]



# --- Estimate survival rate of the censoring event G(t) = P(C >= t) for time-to-censoring variable C
# This prepares for implementing the Inverse Probability of Censoring Weighting (IPCW) scheme,
# as an adjustment to event rates (discrete density), as well as for the time-dependent Brier score

# - Compute Kaplan-Meier survival estimates (product-limit) for censoring-event | Spell-level with right-censoring & left-truncation
km_Censoring <- survfit(Surv(time=TimeInPerfSpell-1, time2=TimeInPerfSpell, event=PerfSpell_Censored==1, type="counting") ~ 1,
                        id=PerfSpell_Key, data=datCredit)
summary(km_Censoring)$table # overall summary statistics
# plot(km_Censoring, conf.int = T) # survival curve

# - Extract quantities of interest
datSurv_censoring <- data.table(TimeInPerfSpell=summary(km_Censoring)$time,
                                Survival_censoring = summary(km_Censoring)$surv)

# - Merge Censoring survival probability back to main dataset
datCredit <- merge(datCredit, datSurv_censoring, by="TimeInPerfSpell", all.x=T)
# CHANGED (added): everyone is censored at month 4 only, so G(t) is missing before then; fill
# with 1 (no censoring yet), as their tBrierScore() does for the same quantity
datCredit[is.na(Survival_censoring), Survival_censoring := 1]





# ------ 3. Constructing expected term-structure of default risk

# --- Handle left-truncated spells by adding a starting record
# This is necessary for calculating certain survival quantities later
datAdd <- subset(datCredit, Counter == 1 & TimeInPerfSpell > 1)
datAdd[, Start := Start-1]
datAdd[, TimeInPerfSpell := TimeInPerfSpell-1]
datAdd[, Counter := 0]
datCredit <- rbind(datCredit, datAdd); setorder(datCredit, PerfSpell_Key, TimeInPerfSpell)


# --- Calculate survival quantities of interest
# Compute IPCW-scheme weight
datCredit[, Weight := 1/Survival_censoring]
# Predict hazard h(t) = P(T=t | T>= t) in discrete-time
# CHANGED: basic model only (no advanced model)
datCredit[, Hazard_bas := predict(modLR_basic, newdata=datCredit, type = "response")]
# Derive survival probability S(t) = \prod ( 1- hazard)
datCredit[, Survival_bas := cumprod(1-Hazard_bas), by=list(PerfSpell_Key)]
# Derive discrete density, or event probability f(t) = S(t-1) . h(t)
datCredit[, EventRate_bas := shift(Survival_bas, type="lag", n=1, fill=1) - Survival_bas, by=list(PerfSpell_Key)]

# - Remove added rows
datCredit <- subset(datCredit, Counter > 0)


# --- Period-level aggregation

# - Aggregate to period-level towards plotting key survival quantities
datSurv_exp <- datCredit[,.(EventRate_bas = mean(EventRate_bas, na.rm=T),
  EventRate_Emp = sum(PerfSpell_Event)/.N,
  EventRate_IPCW = sum(Weight*PerfSpell_Event)/sum(Weight)),
  by=list(TimeInPerfSpell)]
setorder(datSurv_exp, TimeInPerfSpell)
datSurv_exp[, Survival_bas := 1 - cumsum(coalesce(EventRate_bas,0))]
datSurv_exp[, Survival_IPCW := 1 - cumsum(coalesce(EventRate_IPCW,0))]




# ------ 4. Graphing the event density / probability mass function f(t)

# - General parameters
# CHANGED: their spells run to 300 months; ours to 4
sMaxSpellAge <- 4 # max for [PerfSpell_Age]
sMaxSpellAge_graph <- 4 # max for [PerfSpell_Age] for graphing purposes

# - Fitting natural cubic regression splines
# CHANGED: removed. Their natural cubic splines (df=12) smooth 300 monthly points; with our 4
#          points a spline has nothing to smooth and drew curves that miss the data, so the
#          actual and expected event rates are plotted directly instead.

# - Create graphing data object
datGraph <- rbind(datSurv_sub[,list(Time, EventRate, Type="a_Actual")],
                  datSurv_exp[, list(Time=TimeInPerfSpell, EventRate=EventRate_bas, Type="c_Expected_bas")]
)

# - Create different groupings for graphing purposes
datGraph[Type %in% c("a_Actual","c_Expected_bas"), EventRatePoint := EventRate ]
# CHANGED: facet label (one performing spell per customer, not PWP recurrent spells)
datGraph[, FacetLabel := "Single spell, Jul-Oct 2005"]

# - Aesthetic engineering
chosenFont <- "Cambria"
mainEventName <- "Default"

# - Calculate MAE between event rates
datFusion <- merge(datSurv_sub[Time <= sMaxSpellAge],
                   datSurv_exp[TimeInPerfSpell <= sMaxSpellAge,list(Time=TimeInPerfSpell, EventRate_bas)], by="Time")
MAE_eventProb_bas <- mean(abs(datFusion$EventRate - datFusion$EventRate_bas), na.rm=T)
print(datFusion[, .(Time, Month = Time + 3, EventRate_Actual = round(EventRate, 4), EventRate_bas = round(EventRate_bas, 4))])
cat("MAE (basic):", percent(MAE_eventProb_bas, accuracy=0.0001), "\n")

# - Graphing parameters
# CHANGED: spline series removed, so two series (their darker "Paired" colours, solid lines)
vCol <- brewer.pal(10, "Paired")[c(4,6)]
vLabel2 <- c("a_Actual"="Actual", "c_Expected_bas"="Exp: Basic")
vSize <- c(0.5,0.5)
vLineType <- c("solid", "solid")

# - Create main graph
(gsurv_ft <- ggplot(datGraph[Time <= sMaxSpellAge_graph,], aes(x=Time, y=EventRate, group=Type)) + theme_minimal() +
    labs(y=bquote(plain(Event~probability~~italic(f(t))*" ["*.(mainEventName)*"]"*"")),
         x=bquote("Performing spell age (months)"*~italic(t))
         #subtitle="Term-structures of default risk: Discrete-time hazard models"
         ) +
    theme(text=element_text(family=chosenFont),legend.position = "bottom",
          strip.background=element_rect(fill="snow2", colour="snow2"),
          strip.text=element_text(size=8, colour="gray50"), strip.text.y.right=element_text(angle=90)) +
    # Main graph
    geom_point(aes(y=EventRatePoint, colour=Type, shape=Type), size=0.6) +
    geom_line(aes(y=EventRate, colour=Type, linetype=Type, linewidth=Type)) +
    # Annotations
    # CHANGED: annotation position for our axis ranges
    annotate("text", y=0.10,x=2, label=paste0("MAE (basic): ", percent(MAE_eventProb_bas, accuracy=0.0001)), family=chosenFont,
             size = 3) +
    # Scales and options
    facet_grid(FacetLabel ~ .) +
    scale_colour_manual(name="", values=vCol, labels=vLabel2) +
    scale_linewidth_manual(name="", values=vSize, labels=vLabel2) +
    scale_linetype_manual(name="", values=vLineType, labels=vLabel2) +
    scale_shape_discrete(name="", labels=vLabel2) +
    scale_y_continuous(breaks=breaks_pretty(), label=percent) +
    scale_x_continuous(breaks=breaks_pretty(n=8), label=comma) +
    guides(color=guide_legend(nrow=2))
)

# - Save plot
dpi <- 280 # reset
ggsave(gsurv_ft, file=paste0(genFigPath, "EventProb_", mainEventName,"_ActVsExp_CoxDisc_thresh", sDefThresh, "_w", sWeightDflt, ".png"),
       width=1200/dpi, height=1000/dpi,dpi=dpi, bg="white")




# 4. Time-dependent Brier scores (from 6d.Analytics_tBrierScore.R)

# - Create pointer to the appropriate data object
datCredit <- rbind(datCredit_train, datCredit_valid)

# --- Prentice-Williams-Peterson (PWP) Spell-time definition | Basic discrete-time hazard model

# CHANGED: spellPeriodMax 300 -> 3. Everyone still at risk is censored at month 4 (the data ends),
#          so the censoring weight 1/G(4) blows up and tBS(4) exceeds 1. Month 4 (Oct) is scored
#          directly against the October label in section 5 instead.
objCoxDisc_bas <- tBrierScore(datCredit, modGiven=modLR_basic, predType="response", spellPeriodMax=3, fldKey="PerfSpell_Key",
                              fldStart="Start", fldStop="TimeInPerfSpell",fldCensored="PerfSpell_Censored",
                              fldSpellAge="PerfSpell_Age", fldSpellOutcome="PerfSpellResol_Type_Hist")
print(objCoxDisc_bas$tBS)
cat("IBS (basic):", round(objCoxDisc_bas$IBS, 4), "\n")




# 5. OURS: P(default by Oct | no default by June) on the test set, vs the October label

# - Predict all 4 months for every test customer, including months after an early default
datTest <- dat[ID %in% testIDs][rep(seq_len(.N), each = 4)]
datTest[, TimeInPerfSpell := rep(1:4, times = .N / 4)]
datTest[, Time_Binned := timeBinning(TimeInPerfSpell)]
datTest[, Hazard := predict(modLR_basic, newdata = datTest, type = "response")]
datPD <- datTest[, .(PD_Oct = 1 - prod(1 - Hazard)), by = .(ID, Event, DefaultOct)]

cat("\nP(default by Oct) vs any default by Oct:  AUC", round(as.numeric(auc(datPD$Event, datPD$PD_Oct, quiet = TRUE)), 4),
    "  Brier", round(mean((datPD$Event - datPD$PD_Oct)^2), 4), "\n")
cat("P(default by Oct) vs October label only:  AUC", round(as.numeric(auc(datPD$DefaultOct, datPD$PD_Oct, quiet = TRUE)), 4),
    "  Brier", round(mean((datPD$DefaultOct - datPD$PD_Oct)^2), 4), "\n")

# - Comparison: one-period logistic regression on the October label, same covariates and customers
covars <- vars_basic[!vars_basic %in% c("-1", "Time_Binned")]
modLR_oct <- glm(as.formula(paste("DefaultOct ~", paste(covars, collapse = " + "))),
                 data = dat[!(ID %in% testIDs)], family = "binomial")
datPD[, PD_LR := predict(modLR_oct, newdata = dat[match(datPD$ID, dat$ID)], type = "response")]
cat("One-period logistic (Oct label):          AUC", round(as.numeric(auc(datPD$DefaultOct, datPD$PD_LR, quiet = TRUE)), 4),
    "  Brier", round(mean((datPD$DefaultOct - datPD$PD_LR)^2), 4), "\n")
