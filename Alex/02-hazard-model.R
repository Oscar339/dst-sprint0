# ================== DISCRETE-TIME HAZARD MODEL: Taiwan credit-card default ==================
# Using only the first 3 observed months (Apr-Jun 2005), predict the probability of first
# default in each later month (Jul-Oct 2005) with a discrete-time hazard (DtH) model.
# Implements steps 0-2, 4, 5, 7 and 8 of 02-survival-analysis.md, section 7.
# ---------------------------------------------------------------------------------------------
# PROJECT: Data Science Toolbox, Sprint 0 (MATHM0029, University of Bristol, 2026-27)
# AUTHOR:  Alex (adapted code; see below). Python translation: 02-hazard-model.py
# ---------------------------------------------------------------------------------------------
# -- ADAPTED FROM (MIT licence, copyright (c) 2023 Dr Arno Botha):
#   Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of default risk
#     under IFRS 9: A tutorial using discrete-time survival analysis [source code], v1.0.
#     https://doi.org/10.5281/zenodo.15856389
#     https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
#   accompanying the paper:
#   Botha, A. & Verster, T. (2025). Approaches for modelling the term-structure of default risk
#     under IFRS 9: A tutorial using discrete-time survival analysis. arXiv:2507.15441.
#
#   Parts used, by original script:
#     3b.Data_Fusion2_PWP_ST.R          timeBinning() -> baseline hazard as time bins (sec 3)
#     5b(ii).CoxDiscreteTime_Basic.R    basic DtH model: weighted logistic regression on
#                                       person-month data, robust (HC0) standard errors (sec 4)
#     0a.CustomFunctions.R              evalLR(): AIC, McFadden R^2, AUC (sec 5)
#     6c.Analytics_TermStructure_...R   Kaplan-Meier empirical vs model-expected term-structure,
#                                       f(t) = S(t-1) - S(t), compared by MAE (sec 6)
#     0e.FunkySurv_tBrierScore.R        time-dependent Brier score and IBS (sec 7, simplified)
#
#   What we changed for our data, and why:
#     * Data: their South African mortgage panel (not public) -> Taiwan credit-card data,
#       as cleaned by report/01 (data/processed/taiwan-clean.csv).
#     * Spells: theirs are recurrent performing spells (PWP). Ours is ONE spell per customer,
#       from month 4 (Jul) to month 7 (Oct), so the recurrency term
#       log(TimeInPerfSpell):PerfSpell_Num_binned is dropped.
#     * Time bins: their bins span years; we only have 4 months, so each month is its own bin.
#     * Covariates: no interest-rate or macroeconomic data (InterestRate_Nom,
#       M_Inflation_Growth_6 dropped). Their time-varying Arrears is replaced by covariates
#       FROZEN at month 3, because our scope only allows information from the first 3 months
#       (step 7 of 02-survival-analysis.md). Static covariates as listed in its step 4.
#     * Default weight: they weight defaults x10, chosen for calibration on their data. We fit
#       x1 and x10 and keep the better-calibrated one (sec 6), as they did.
#     * Term-structure: expected f(t) is averaged over ALL test customers on the full 4-month
#       grid (not only rows still at risk), so it compares like-for-like with Kaplan-Meier.
#     * tBrier: nobody is censored before October, so their IPCW weights are all 1 and the
#       score reduces to a plain mean squared error at each month.
#
# -- DEFINITIONS:
#   * Month t: Apr=1, May=2, Jun=3 | Jul=4, Aug=5, Sep=6, Oct=7.
#   * Event ("default"): first month with repayment status PAY >= sDefThresh months behind
#     (Jul, Aug or Sep), or the dataset's label "default payment next month" = 1 (Oct).
#     Main run: sDefThresh = 2 (step 1 of 02-survival-analysis.md). Check: 3 (90+ days, Basel).
#     Run with another threshold as:  Rscript Alex/02-hazard-model.R 3
#   * At risk from month 4: customers with no event in Apr-Jun (step 2 / step 7).
#   * "First 3 months" = first 3 OBSERVED months; the data has no account-opening date.
#   * Test set: the same 20% of customers as Oscar/07 (IDs in Alex/test-ids-oscar07.csv),
#     restricted to those at risk. Everyone else at risk is used for fitting.
#
#    R packages: data.table, survival, sandwich, lmtest, pROC, ggplot2
# =============================================================================================

suppressPackageStartupMessages({
  library(data.table); library(survival); library(sandwich)
  library(lmtest); library(pROC); library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
sDefThresh <- if (length(args) > 0) as.integer(args[1]) else 2L   # months behind = event

root <- if (basename(getwd()) == "Alex") ".." else "."
outFig <- file.path(root, "Alex", "figures"); dir.create(outFig, showWarnings = FALSE)
cat("Event threshold: PAY >=", sDefThresh, "months behind\n")



# ------ 1. Load the cleaned data and the test split

dat <- fread(file.path(root, "data", "processed", "taiwan-clean.csv"))
setnames(dat, "default payment next month", "DefaultOct")
testIDs <- fread(file.path(root, "Alex", "test-ids-oscar07.csv"))$ID
cat("customers (cleaned):", nrow(dat), "\n")



# ------ 2. Scope: at-risk population and covariates frozen at month 3 (June)

# - Exclude customers with an event in the first 3 months (step 2)
dat <- dat[!(PAY_6 >= sDefThresh | PAY_5 >= sDefThresh | PAY_4 >= sDefThresh)]
cat("at risk from month 4:", nrow(dat), "\n")

# - Covariates known at month 3 (June). PAY codes -2, -1, 0 are categories, not numbers.
dat[, Status_M3      := factor(fifelse(PAY_4 >= 0, "0+", as.character(PAY_4)), levels = c("-2", "-1", "0+"))]
dat[, Utilisation_M3 := BILL_AMT4 / LIMIT_BAL]          # June bill / credit limit
dat[, logPay_M3      := log1p(PAY_AMT4)]                # amount paid in June
dat[, logLimit       := log(LIMIT_BAL)]
dat[, `:=`(SEX = factor(SEX), EDUCATION = factor(EDUCATION), MARRIAGE = factor(MARRIAGE))]
covars <- c("Status_M3", "Utilisation_M3", "logPay_M3", "logLimit", "AGE", "SEX", "EDUCATION", "MARRIAGE")

dat[, Sample := ifelse(ID %in% testIDs, "test", "train")]
print(dat[, .N, by = Sample])



# ------ 3. Person-month data (step 4: one row per customer per month at risk)

# - Event indicator for each month of the prediction window
evt <- dat[, c("ID", "Sample", covars, "DefaultOct"), with = FALSE]
evt[, `:=`(E4 = as.integer(dat$PAY_3 >= sDefThresh),     # Jul
           E5 = as.integer(dat$PAY_2 >= sDefThresh),     # Aug
           E6 = as.integer(dat$PAY_1 >= sDefThresh),     # Sep
           E7 = as.integer(dat$DefaultOct == 1))]        # Oct (dataset label)

# - Time to first event (1..4 months into the window), or 4 with no event (censored at Oct)
evt[, FirstEvent := fifelse(E4 == 1, 1L, fifelse(E5 == 1, 2L, fifelse(E6 == 1, 3L, fifelse(E7 == 1, 4L, NA_integer_))))]
evt[, Time  := fifelse(is.na(FirstEvent), 4L, FirstEvent)]
evt[, Event := as.integer(!is.na(FirstEvent))]

# - Expand: a customer appears in months 1..Time; the event flag is 1 only in the last row if Event
pm <- evt[rep(seq_len(.N), Time)]
pm[, TimeInPerfSpell := seq_len(.N), by = ID]
pm[, PerfSpell_Event := as.integer(Event == 1 & TimeInPerfSpell == Time)]

# - timeBinning(), adapted: with only 4 months, each month is its own bin
binLevels <- sprintf("%02d.M%d", 1:4, 4:7)
pm[, Time_Binned := factor(sprintf("%02d.M%d", TimeInPerfSpell, TimeInPerfSpell + 3), levels = binLevels)]
cat("person-months:", nrow(pm), " events:", sum(pm$PerfSpell_Event), "\n")
print(pm[, .(AtRisk = .N, Events = sum(PerfSpell_Event), Hazard = round(mean(PerfSpell_Event), 4)),
         by = .(Month = TimeInPerfSpell + 3)])

train <- pm[Sample == "train"]; test <- pm[Sample == "test"]



# ------ 4. Basic discrete-time hazard model (after 5b(ii); step 5)

vars_basic <- c("-1", "Time_Binned", covars)
form <- as.formula(paste("PerfSpell_Event ~", paste(vars_basic, collapse = " + ")))

modLR_base <- glm(PerfSpell_Event ~ 1, data = train, family = "binomial")   # empty model
fits <- list()
for (w in c(1, 10)) {                          # their weight was 10; test it against 1
  train[, Weight := ifelse(PerfSpell_Event == 1, w, 1)]
  fits[[paste0("w", w)]] <- glm(form, data = train, family = "binomial", weights = Weight)
}



# ------ 5. evalLR (after 0a): AIC, McFadden R^2 (train), AUC (test person-months)

evalLR <- function(model, model_base, datGiven, targetFld = "PerfSpell_Event") {
  pred <- predict(model, newdata = datGiven, type = "response")
  data.table(AIC = round(AIC(model)),
             McFadden_R2 = round(1 - as.numeric(logLik(model)) / as.numeric(logLik(model_base)), 4),
             AUC_test = round(as.numeric(auc(datGiven[[targetFld]], pred, quiet = TRUE)), 4))
}
for (k in names(fits)) { cat("\n", k, "\n"); print(evalLR(fits[[k]], modLR_base, test)) }



# ------ 6. Term-structure: Kaplan-Meier (empirical) vs model-expected (after 6c)

# - Empirical f(t) on test customers
cust_te <- evt[Sample == "test"]
km <- survfit(Surv(Time, Event) ~ 1, data = cust_te)
emp <- data.table(t = km$time, AtRisk = km$n.risk, Events = km$n.event, S = km$surv)
emp[, Hazard := Events / AtRisk]
emp[, f_emp := Hazard * shift(S, fill = 1)]                # f(t) = h(t) S(t-1)

# - Expected f(t): predict h(t) for every test customer on the full 4-month grid
grid <- cust_te[rep(seq_len(.N), each = 4)]
grid[, TimeInPerfSpell := rep(1:4, times = nrow(cust_te))]
grid[, Time_Binned := factor(sprintf("%02d.M%d", TimeInPerfSpell, TimeInPerfSpell + 3), levels = binLevels)]
termStruct <- function(model) {
  g <- copy(grid)
  g[, h := predict(model, newdata = g, type = "response")]
  g[, S := cumprod(1 - h), by = ID]
  g[, f := shift(S, fill = 1) - S, by = ID]
  g
}
res <- emp[, .(t, Month = t + 3, f_emp)]
grids <- list()
for (k in names(fits)) {
  grids[[k]] <- termStruct(fits[[k]])
  res <- merge(res, grids[[k]][, .(f = mean(f)), by = .(t = TimeInPerfSpell)][, setnames(.SD, "f", paste0("f_", k))], by = "t")
}
cat("\nTerm-structure, test customers (f = probability of first default in that month):\n")
print(res[, lapply(.SD, function(x) round(x, 4))])
mae <- sapply(names(fits), function(k) mean(abs(res[[paste0("f_", k)]] - res$f_emp)))
cat("MAE vs empirical:", paste(names(mae), round(mae, 5), collapse = "  "), "\n")
best <- names(which.min(mae)); modLR_basic <- fits[[best]]
cat("Better calibrated (kept):", best, "\n")

# - Robust (HC0, sandwich) standard errors for the kept model, as in 5b(ii)
cat("\nKept model, robust SEs:\n"); print(coeftest(modLR_basic, vcov. = vcovHC(modLR_basic, type = "HC0")))

# - Graph
gdat <- rbind(res[, .(Month, f = f_emp, Series = "Empirical (Kaplan-Meier)")],
              res[, .(Month, f = get(paste0("f_", best)), Series = paste0("Expected, DtH model (", best, ")"))])
p <- ggplot(gdat, aes(Month, f, colour = Series)) + geom_line(linewidth = 0.9) + geom_point(size = 2) +
  scale_x_continuous(breaks = 4:7, labels = c("Jul", "Aug", "Sep", "Oct")) +
  scale_y_continuous(labels = scales::percent) +
  scale_colour_manual(values = c("#2a78d6", "#eb6834")) +
  labs(x = NULL, y = "probability of first default in month, f(t)",
       title = "Term-structure of default risk, test customers",
       subtitle = paste0("Default = ", sDefThresh, "+ months behind (Jul-Sep) or dataset label (Oct)"), colour = NULL) +
  theme_minimal() + theme(legend.position = "bottom")
ggsave(file.path(outFig, paste0("hazard-term-structure-R-thresh", sDefThresh, ".png")), p, width = 7, height = 4, dpi = 150)



# ------ 7. Time-dependent Brier score and IBS (after 0e; no censoring before Oct, so no IPCW)

g <- grids[[best]][, .(ID, t = TimeInPerfSpell, PD_cum = 1 - S)]
g <- merge(g, cust_te[, .(ID, Time, Event, DefaultOct)], by = "ID")
g[, Y := as.integer(Event == 1 & Time <= t)]               # defaulted by month t?
tBS <- g[, .(tBS = mean((Y - PD_cum)^2)), by = .(Month = t + 3)]
cat("\nTime-dependent Brier score:\n"); print(tBS[, .(Month, tBS = round(tBS, 4))])
cat("IBS (uniform weights):", round(mean(tBS$tBS), 4), "\n")



# ------ 8. Step 7/8: P(T <= 7 | T > 3, x), scored against the October label (headline metrics)

last <- g[t == 4]
cat("\nP(event by Oct)  vs any event by Oct:   AUC", round(as.numeric(auc(last$Y, last$PD_cum, quiet = TRUE)), 4),
    "  Brier", round(mean((last$Y - last$PD_cum)^2), 4), "\n")
cat("P(event by Oct)  vs October label only: AUC", round(as.numeric(auc(last$DefaultOct, last$PD_cum, quiet = TRUE)), 4),
    "  Brier", round(mean((last$DefaultOct - last$PD_cum)^2), 4), "\n")

# - Comparison: one-period logistic regression on the October label, same covariates and customers
lr <- glm(as.formula(paste("DefaultOct ~", paste(covars, collapse = " + "))),
          data = evt[Sample == "train"], family = "binomial")
p_lr <- predict(lr, newdata = cust_te, type = "response")
cat("One-period logistic (Oct label):        AUC", round(as.numeric(auc(cust_te$DefaultOct, p_lr, quiet = TRUE)), 4),
    "  Brier", round(mean((cust_te$DefaultOct - p_lr)^2), 4), "\n")
