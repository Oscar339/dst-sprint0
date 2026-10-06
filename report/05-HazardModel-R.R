# ======================================================================================
# 05 - HAZARD MODEL (R): Botha & Muller (2025) functions + our Taiwan discrete-time hazard model
#   PART 1: functions copied unchanged from Botha & Muller (was Alex/02-hazard-functions-BothaMuller.R)
#   PART 2: the Taiwan model script (was Alex/02-hazard-model.R)
# ======================================================================================


# ################################ PART 1: BOTHA & MULLER FUNCTIONS ################################

# ============================ FUNCTIONS COPIED FROM BOTHA & MULLER (2025) ============================
# Every function below is copied UNCHANGED from:
#   Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of default risk
#     under IFRS 9: A tutorial using discrete-time survival analysis [source code], v1.0.
#     https://doi.org/10.5281/zenodo.15856389
#     https://github.com/arnobotha/Term-Structure-Modelling-RetailMortgages
# Sourced by 02-hazard-model.R. Extracted line ranges (tag v1.0):
#   Scripts/0a.CustomFunctions.R     lines 535-654   coefDeter_glm(), evalLR()
#   Scripts/0b.FunkySurv.R           lines  68-252   TimeDef_Form(), calc_AIC(), aicTable(), calc_conc(), concTable()
#   Scripts/0e.FunkySurv_tBrierScore.R  whole file   tBrierScore()
# -----------------------------------------------------------------------------------------------------
# MIT License
#
# Copyright (c) 2023 Dr Arno Botha
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# =====================================================================================================



# ======================== From Scripts/0a.CustomFunctions.R (lines 535-654) ========================

# --- Pseudo R^2 measures for classifiers
# Calculate a pseudo coefficient of determination (R^2) \in [0,1] for glm assuming binary
# logistic regression as default, based on the "null deviance" in likelihoods
# between the candidate model and the intercept-only (or "empty/worst/null") model.
# NOTE: This generic R^2 is NOT equal to the typical R^2 used in linear regression, i.e., it does
# NOT explain the % of variance explained by the model; but rather it denotes the %-valued degree
# to which the candidate's fit can be deemed as "perfect".
# Implements McFadden's pseudo R^2, Cox-Snell generalised R^2, Nagelkerke's improvement upon Cox-Snell's R^2
# see https://bookdown.org/egarpor/SSS2-UC3M/logreg-deviance.html ; https://web.pdx.edu/~newsomj/cdaclass/ho_logistic.pdf; 
# https://statisticalhorizons.com/r2logistic/
# https://stats.stackexchange.com/questions/8511/how-to-calculate-pseudo-r2-from-rs-logistic-regression
coefDeter_glm <- function(model, model_base = NA) {
  # Testing conditions:
  # model <- modLR; model_base <- modLR_base
  
  # - Safety check
  if (!any(class(model) %in% c("glm","multinom"))) stop("Specified model object is not of class 'glm' or 'lm'. Exiting .. ")
  
  # model <- modMLR
  
  # -- Preliminaries
  require(scales) # for formatting of results
  L_full <- logLik(model) # log-likelihood of fitted model, ln(L_M)
  nobs <- attr(L_full, "nobs") # sample size, same as NROW(model$model)
  
  # Fit a base/empty model if not available
  if (any(is.na(model_base))) {
    orig_formula <- deparse(unlist(list(model$formula, formula(model), model$call$formula))[[1]]) # model formula
    orig_call <- model$call; calltype.char <- as.character(orig_call[1]) # original model fitting call specification, used merely for "plumbing"
    data <- model.frame(model) # data matrix used in fitting the model (model$model)
    # get weight matrix corresponding to each observation, if applicable/specified, otherwise, this defaults to just the 0/1-valued observations (Y)
    if (!is.null(model$prior.weights) & length(model$prior.weights) > 0) {
      weights <- model$prior.weights
    } else if (!is.null(data$`(weights)`) & length(data$`(weights)` > 0)) {
      weights <- data$`(weights)`
    } else weights <- NULL
    data <- data[, 1, drop=F]; names(data) <- "y"
    nullCall <- call(calltype.char, formula = as.formula("y ~ 1"), data = data, weights = weights, family = model$family, 
                     method = model$method, control = model$control, offset = model$offset)
    model_base <- eval(nullCall) # fit base/null model
  } 
  L_base <- logLik(model_base) # log-likelihood of the null model, ln(L_0)
  
  # -- Implement the McFadden pseudo R^2 measure from McFadden1974, R^2 = 1 - log(L_M)/log(L_0)
  # NOTE: null deviance L_0 plays an analogous role to the residual sum of squares in linear regression, therefore
  # McFadden's R^2 corresponds to a proportional reduction in "error variance", according to Allison2013 (https://statisticalhorizons.com/r2logistic/)
  # NOTE2: deviance (L_M) and null deviance (L_0) within a GLM-object is already the log-likelihood since deviance = -2*ln(L_M) by definition
  # https://stats.stackexchange.com/questions/8511/how-to-calculate-pseudo-r2-from-rs-logistic-regression
  if (any(class(model) == "multinom") ) {
    coef_McFadden <- 1 - (as.numeric(L_full) / as.numeric(L_base))
  } else coef_McFadden <- 1 - model$deviance / model$null.deviance
  
  # The following check will fail if the given model does not contain an intercept
  if ( abs(coef_McFadden - as.numeric(1 - (-2*L_full)/(-2*L_base))) > 0.000001 ) {
    if (attr(terms(model), "intercept") == 1) {
      stop("ERROR: Internal function error in calculating & verifying McFadden's pseudo R^2-measure")
    } else{
      cat("NOTE: Provided model contains no intercept term.\n")
      coef_McFadden <- as.numeric(1 - (-2*L_full)/(-2*L_base))
    }
  }
  
  
  # -- Implement Cox-Snell R^2 measure from Cox1983, which according to Allison2013 is more a "generalized" R^2 measure than pseudo,
  # given that its definition is an "identity" in normal-theory linear regression. Can therefore be used to other regression settings using MLE,
  # E.g., negative binomial regression for count data or Weibull regression for survival data
  # Definition: R^2 = 1 - (L_0/L_F)^(2/nobs), but equivalent to below given that L_base = ln(L0) and L_full = ln(L_full)
  # Why? Since (L_0/L_F)^(2/nobs) can be rewritten as exp[ ln( (L_0/L_F)^(2/nobs) )] which simplifies to exp[ (2/nobs) . ln( L_0/L_F )] given property ln(a^b) = b.ln(a),
  # finally becoming exp[ (2/nobs) . ( ln( L_0 ) - ln( L_F)) ]  given property ln(a/b) = ln(a) - ln(b).
  # The below is numerically expedient in avoiding "underflow" memory issues when dealing with large negative log-likelihood values that should rather not be exponentiated.
  # Source: DescTools::PseudoR2 function in DescTools package
  coef_CoxSnell <- as.numeric( 1 - exp(2/nobs * (L_base - L_full)) )
  
  
  # -- Implement Nagelkerke R^2 from Nagelkerke1991, which according to Allison2013 improves upon Cox-Snell R^2 by ensuring an upper bound of 1
  # NOTE: Cox-Snell R^2 has an upper bound of 1 - (L_0)^(2/n), which can be considerably less than 1.
  # This comes at the cost of reducing the attractive theoretical properties of the Cox-Snell R^2 
  if (any(class(model) == "multinom") ) {
    coef_Nagelkerke <- (1 - exp((model$deviance - model_base$deviance)/nobs))/(1 - exp(-model_base$deviance/nobs))
  } else {
    coef_Nagelkerke <- (1 - exp((model$deviance - model$null.deviance)/nobs))/(1 - exp(-model$null.deviance/nobs))
  }
  
  
  # -- Report results
  return( data.frame(McFadden=percent(coef_McFadden, accuracy=0.01), CoxSnell=percent(coef_CoxSnell, accuracy=0.01), Nagelkerke=percent(coef_Nagelkerke, accuracy=0.01)) )
  
  ### NOTE: All of the above were tested and confirmed to equal the results produced below:
  # DescTools::PseudoR2(model, c("McFadden", "CoxSnell", "Nagelkerke"))
  
  # - cleanup (only relevant whilst debugging this function)
  rm(model, L_full, L_base, nobs, data, nullCall, orig_formula, orig_call, weights, coef_McFadden, coef_CoxSnell, coef_Nagelkerke)
}
# - Unit test
# install.packages("ISLR"); require(ISLR)
# datTrain_simp <- data.table(ISLR::Default); datTrain_simp[, `:=`(default=as.factor(default), student=as.factor(student))]
# logit_model <- glm(default ~ student + balance + income, data=datTrain_simp, family="binomial")
# coefDeter_glm(logit_model)
### RESULTS: candidate is 46% (McFadden) better than null-model in terms of its deviance




# --- Evaluation function for glm-based objects
evalLR <- function(model, model_base, datGiven, targetFld, predClass) {
  require(data.table); require(scales)
  # - Test conditions
  # model <- modLR; model_base <- modLR_base; datGiven <- datCredit_train
  # targetFld = "PerfSpell_Event"; predClass <- 1
  result1 <- AIC(model) # 1164537 
  result2 <- coefDeter_glm(model, model_base) # 0.29%
  matPred <- predict(model, newdata=datGiven, type="response")
  actuals <- ifelse(datGiven[[targetFld]] == predClass, 1,0)
  result3 <- roc(response=actuals, predictor = matPred)
  objResults <- data.table(AIC=comma(result1), result2, AUC=percent(result3$auc,accuracy=0.01))
  return(objResults)
  # - Cleanup, if run interactively
  rm(result1, result2, matPred, actuals, result3, objResults, model, model_base, datGiven, targetFld, predClass)
}




# ======================== From Scripts/0b.FunkySurv.R (lines 68-252) ========================
# --- Function to return the appropriate formula object based on the time definition.
#         [TimeDef]: Time definition incorporated;
#         [variables]: List of variables used to build single-factor models;
TimeDef_Form <- function(TimeDef, variables, strataVar=""){
  # Create formula based on time definition of the dataset.
  if(TimeDef[1]=="TFD"){# Formula for time to first default time definition (containing only the fist performance spell).
    formula <- as.formula(paste0("Surv(TimeInPerfSpell-1,TimeInPerfSpell,DefaultStatus1) ~ ",
                                 paste(variables,collapse=" + ")))
    
  } else if(TimeDef[1]=="AG"){# Formula for Andersen-Gill (AG) time definition
    formula <- as.formula(paste0("Surv(TimeInPerfSpell-1,TimeInPerfSpell,DefaultStatus1) ~ PerfSpell_Num + ",
                                 paste(variables,collapse=" + ")))
    
  } else if(TimeDef[1]=="PWPST"){# Formula for Prentice-Williams-Peterson (PWP) Spell time definition
    formula <- as.formula(paste0("Surv(TimeInPerfSpell-1,TimeInPerfSpell,DefaultStatus1) ~ strata(", strataVar, ") + ",
                                 paste(variables,collapse=" + ")))
  } else if(TimeDef[1]=="Cox_Discrete") { # Formula for a discrete-time Cox model (for use in glm())
      formula <- as.formula(paste0(TimeDef[2], " ~ ",
                                   paste(variables,collapse=" + ")))
  } else {stop("Unkown time definition")}
  
  return(formula)
}



# --- Function to fit a given formula within a Cox regression model towards extracting Akaike Information Criterion (AIC) and related quantities
#         [formula]: Cox regression formula object; [data_train]: Training data;
#         [data_valid]: Validation data; [variables]: List of variables used to build single-factor models;
#         [it]: Number of variables being compared; [logPath], Optional path for log file for logging purposes;
#         [fldSpellID]: Field name of spell-level ID.
#         [modelType]: Specifying either a coxph object to be fit, or glm
calc_AIC <- function(formula, data_train, variables="", it=NA, logPath="", 
                     fldSpellID="PerfSpell_Key", modelType="Cox") {
  # - Testing conditions
  # j <- 1; formula=TimeDef_Form(TimeDef,variables[j], strataVar=strataVar); 
  
  tryCatch({
    if (modelType=="Cox") {
      model <- coxph(formula,id=get(fldSpellID), data = data_train) # Fit Cox model 
    } else if (modelType=="Cox_Discrete") {
      model <- glm(formula,data = data_train, family="binomial") # Fit discrete-time Cox model 
    } else stop("Unknown model type in calc_AIC().")
    
    if (!is.na(it)) {# Output the number of models built, where the log is stored in a text file afterwards.
      cat(paste0("\n\t ", it,") Single-factor survival model built. "),
          file=paste0(logPath,"AIC_log.txt"), append=T)
    }
    
    AIC <- AIC(model) # Calculate AIC of the model.
    
    # Return results as a data.table
    if (modelType=="Cox") {
      return(data.table(Variable = variables, AIC = AIC, pValue=summary(model)$coefficients[5]))
    } else if (modelType=="Cox_Discrete") {
      return(data.table(Variable = variables, AIC = AIC, pValue=summary(model)$coefficients[1,4]))
    }
    
    
  }, error=function(e) {
    AIC <- Inf
    if (!is.na(it)) {
      cat(paste0("\n\t ", it,") Single-factor survival model failed. "),
          file=paste0(logPath,"AIC_log.txt"), append=T)
    }
    return(data.table(Variable = variables, AIC = AIC, pValue=NA)) 
  })
}



# --- Function to extract the Akaike Information Criterion (AIC) from single-factor models
# Input:  [data_train]: Training data; [data_valid]: [variables]: List of variables used to build single-factor models;
#         [fldSpellID]: Field name of spell-level ID; [TimeDef]: Time definition incorporated.
#         [numThreads]: Number of threads used; [genPath]: Optional path for log file. 
# Output: [matResults]: Result matrix.
aicTable <- function(data_train, variables, fldSpellID="PerfSpell_Key",
                      TimeDef, numThreads=6, genPath, strataVar="", modelType="Cox") {
  # - Testing conditions
   # data_train <- datCredit_train; TimeDef="PWPST"; numThreads=6
   # fldSpellID<-"PerfSpell_Key"; variables<-"g0_Delinq_SD_4"; strataVar="PerfSpell_Num_binned"
  
  # - Iterate across loan space using a multi-threaded setup
  ptm <- proc.time() #IGNORE: for computation time calculation
  cl.port <- makeCluster(round(numThreads)); registerDoParallel(cl.port) # multi-threading setup
  cat("New Job: Estimating AIC for each variable as a single-factor survival model ..",
      file=paste0(genPath,"AIC_log.txt"), append=F)
  
  results <- foreach(j=1:length(variables), .combine='rbind', .verbose=F, .inorder=T,
                     .packages=c('data.table', 'survival'), .export=c('calc_AIC', 'TimeDef_Form')) %dopar%
    { # ----------------- Start of Inner Loop -----------------
      # - Testing conditions
      # j <- 1
      calc_AIC(formula=TimeDef_Form(TimeDef,variables[j], strataVar=strataVar), variables=variables[j],
                    data_train=data_train, it=j, logPath=genPath,  fldSpellID=fldSpellID, modelType=modelType)
      } # ----------------- End of Inner Loop -----------------
  stopCluster(cl.port); proc.time() - ptm  
  
  # Sort by concordance in ascending order.
  setorder(results, AIC)
  
  # Return resulting table.
  return(results)
}



# --- Function to fit a given formula within a Cox regression model towards extracting Harrell's C-statistic and related quantities
#         [formula]: Cox regression formula object; [data_train]: Training data;
#         [data_valid]: Validation data; [variables]: List of variables used to build single-factor models;
#         [it]: Number of variables being compared; [logPath], Optional path for log file for logging purposes;
#         [fldSpellID]: Field name of spell-level ID.
calc_conc <- function(formula, data_train, data_valid, variables="", it=NA, logPath="", 
                      fldSpellID="PerfSpell_Key", modelType="Cox") {
  # formula <- TimeDef_Form(TimeDef,variables[j], strataVar=strataVar)
  
  tryCatch({
    if (modelType=="Cox") {
      model <- coxph(formula,id=get(fldSpellID), data = data_train) # Fit Cox model 
    } else if (modelType=="Cox_Discrete"){
      model <- glm(formula,data = data_train, family="binomial") # Fit discrete-time Cox model 
    } else stop("Unknown model type in calc_AIC().")
    
    if (!is.na(it)) {# Output the number of models built, where the log is stored in a text file afterwards.
      cat(paste0("\n\t ", it,") Single-factor survival model built. "),
          file=paste0(logPath,"HarrelsC_log.txt"), append=T)
    }
    
    c <- concordance(model, newdata=data_valid) # Calculate concordance of the model based on the validation set.
    conc <- as.numeric(c[1])# Extract concordance
    sd <- sqrt(c$var)# Extract concordance variability as a standard deviation
    if (modelType=="Cox") {
      lr_stat <- round(2 * (model$loglik[2] - model$loglik[1]),0)# Extract LRT from the model's log-likelihood 
    } else lr_stat <- NA
    
    # Return results as a data.table
    return(data.table(Variable = variables, Concordance = conc, SD = sd, LR_Statistic = lr_stat))
  }, error=function(e) {
    conc <- 0
    sd <- NA
    lr_stat <- NA
    if (!is.na(it)) {
      cat(paste0("\n\t ", it,") Single-factor survival model failed. "),
          file=paste0(logPath,"Concordance_log.txt"), append=T)
    }
    return(data.table(Variable = variables, Concordance = conc, SD = sd, LR_Statistic = lr_stat)) 
  })
}



# --- Function to extract the concordances (Harrell's C for Cox PH) from single-factor models
# Input:  [data_train]: Training data; [data_valid]: Validation data;
#         [variables]: List of variables used to build single-factor models;
#         [fldSpellID]: Field name of spell-level ID; [TimeDef]: Time definition incorporated.
# Output: [matResults]: Result matrix.
concTable <- function(data_train, data_valid, variables, fldSpellID="PerfSpell_Key",
                      TimeDef, numThreads=6, genPath, strataVar="", modelType="Cox") {
  # - Testing conditions
  # data_valid <- datCredit_train_PWPST; TimeDef="PWPST"; numThreads=6
  # fldEventInd<-"Default_Ind"
  
  # - Iterate across loan space using a multi-threaded setup
  ptm <- proc.time() #IGNORE: for computation time calculation
  cl.port <- makeCluster(round(numThreads)); registerDoParallel(cl.port) # multi-threading setup
  cat("New Job: Estimating B-statistic (1-KS) for each variable as a single-factor survival model ..",
      file=paste0(genPath,"Concordance_log.txt"), append=F)
  
  results <- foreach(j=1:length(variables), .combine='rbind', .verbose=F, .inorder=T,
                                 .packages=c('data.table', 'survival'), .export=c('calc_conc', 'TimeDef_Form')) %dopar%
    { # ----------------- Start of Inner Loop -----------------
      # - Testing conditions
      # j <- 1
      calc_conc(formula=TimeDef_Form(TimeDef,variables[j], strataVar=strataVar), variable=variables[j],
                    data_train=data_train, data_valid=data_valid, it=j, logPath=genPath, 
                fldSpellID=fldSpellID, modelType=modelType)
    } # ----------------- End of Inner Loop -----------------
  stopCluster(cl.port); proc.time() - ptm  
  
  # Sort by concordance in descending order.
  setorder(results, -Concordance)
  
  # Return resulting table.
  return(results)
}




# ======================== From Scripts/0e.FunkySurv_tBrierScore.R (whole file) ========================
# ============================== SURVIVAL FUNCTIONS ==============================
# Defining bespoke time-dependent Brier score function, capable of working with
# time-to-event left-truncated data in the counting process style
# --------------------------------------------------------------------------------
# PROJECT TITLE: Default Survival Modelling
# SCRIPT AUTHOR(S): Dr Arno Botha
# VERSION: 1.0 (Jul-2025)
# ================================================================================



# --- Function to calculate time-dependent Brier Score (tBS) for a given object's predictions
# Crafted using Graff1999 (DOI: 10.1002/(sici)1097-0258(19990915/30)18:17/18<2529::aid-sim274>3.0.co;2-5)
# Input:    [datGiven]: given loan history; [modGiven]: fitted cox PH or discrete-time hazard model;
#           [predType]: option to pass to predict(); [spellPeriodMax]: maximum period to impose upon spell ages
#           <fldNames>: Various field names for quantities of interest
# Output:   Vector of tBS-values; Integrated Brier Score (IBS)
tBrierScore <- function(datGiven, modGiven, predType="response", spellPeriodMax=300,
                        fldKey="PerfSpell_Key", fldStart = "Start", fldStop="TimeInPerfSpell",
                        fldEvent="PerfSpell_Event", fldCensored="PerfSpell_Censored", fldSpellAge="PerfSpell_Age",
                        fldSpellOutcome="PerfSpellResol_Type_Hist") {
  # Testing conditions
  # datGiven <- datCredit; modGiven <- cox_PWPST_basic ; predType <- "exp"; spellPeriodMax <- 300
  # fldKey <- "PerfSpell_Key"; fldStart <- "Start"; fldStop<-"TimeInPerfSpell";
  # fldCensored<-"PerfSpell_Censored"; fldSpellAge<-"PerfSpell_Age"; fldSpellOutcome<-"PerfSpellResol_Type_Hist"
  # fldEvent="PerfSpell_Event"
  
  
  # --- Estimate survival rate of the censoring event G(t) = P(C >= t) for time-to-censoring variable C
  # This prepares for implementing the Inverse Probability of Censoring Weighting (IPCW) scheme,
  # as an adjustment to event rates (discrete density), as well as for the time-dependent Brier score
  
  # - Compute Kaplan-Meier survival estimates (product-limit) for censoring-event | Spell-level with right-censoring & left-truncation
  km_Censoring <- survfit(
    as.formula(paste0("Surv(time=",fldStart,", time2=", fldStop, ", event=", fldCensored, "==1, type='counting') ~ 1")), 
    id=get(fldKey), data=datGiven)
  # summary(km_Censoring)$table # overall summary statistics
  # plot(km_Censoring, conf.int = T) # survival curve
  datG <- data.table(summary(km_Censoring)$time, summary(km_Censoring)$surv)
  setnames(datG, c(fldStop, "G_t"))
  datG_ti <- data.table(EventTime = summary(km_Censoring)$time, G_Ti = summary(km_Censoring)$surv)
  
  
  # --- Estimate survival rate of the main event S(t) = P(T >= t) for time-to-event variable T
  # This serves as a baseline model towards calculating the pseudo R^2-measure
  
  # - Compute Kaplan-Meier survival estimates (product-limit) for censoring-event | Spell-level with right-censoring & left-truncation
  km_main <- survfit(
    as.formula(paste0("Surv(time=",fldStart,", time2=", fldStop, ", event=", fldEvent, "==1, type='counting') ~ 1")), 
    id=get(fldKey), data=datGiven)
  # summary(km_main)$table # overall summary statistics
  # plot(km_main, conf.int = T) # survival curve
  datT <- data.table(summary(km_main)$time, summary(km_main)$surv)
  setnames(datT, c(fldStop, "Survival_0"))
  
  
  # --- Calculate survival quantities of interest
  # Predict hazard h(t) = P(T=t | T>= t) in discrete-time
  datGiven[, Hazard := predict(modGiven, newdata=datGiven, type = predType)]
  if (predType=="response") {
    # Derive survival probability S(t) = \prod ( 1- hazard), based on output of predict()
    datGiven[, Survival := cumprod(1-Hazard), by=list(get(fldKey))] 
  } else if (predType=="exp") {
    # Calculate survival probability S(t,x)=exp(-H(t,x)), based on output of predict()
    # NOTE: Hazard is actually the cumulative hazard in this context
    datGiven[, Survival := exp(-Hazard), by=list(get(fldKey))] 
  }
  # - Merge censoring survival probability unto main set
  datGiven <- merge(datGiven, datG, by=fldStop, all.x=T)
  datGiven[is.na(G_t), G_t := 1] # Fill any missing G_t with 1 (no censoring information)
  # - Merge event survival probability unto main set
  datGiven <- merge(datGiven, datT, by=fldStop, all.x=T)
  datGiven[is.na(Survival_0), Survival_0 := 1] # Fill any missing G_t with 1 (no censoring information)
  
  
  # --- Compute Censoring survival probability at age T_i for each subject (i,j), i..e, G_hat(T_i)
  # This requires mapping each subject's observed event time (Spell age) to g_hat(T_i)
  datGiven <- merge(datGiven, datG_ti, by.x=fldSpellAge, by.y="EventTime", all.x=T)
  datGiven[is.na(G_Ti), G_Ti := 1]
  
  
  # --- Compute constituent quantities of time-dependent Brier score (tBS)
  # - Compute binary event indicator at time t: y(t) = I(T>t)
  datGiven[, y_t := as.integer(get(fldSpellAge) > get(fldStop))]
  # - Compute weight/contribution to the Brier score at each time point, according to the 3 categories of Graff1999
  datGiven[, Weight_w := fifelse( 
    # Category 1: T_i <= t^* & \delta_i =1; should get weight 1/G(T_i) since subject experienced the event
    get(fldSpellAge) <= get(fldStop) & get(fldSpellOutcome)=="Defaulted", 1/G_Ti,
    # Category 2: T_i > t^*; should get weight 1/G(t) since subject has survived  (still at-risk)
    fifelse( get(fldSpellAge) > get(fldStop), 1/G_t, 
             # Category 3: T_i <= t^* & \delta_i=0; should get weight 0 for censored subject
             0)), by=list(get(fldKey))]  
  
  # -- Compute squared error loss per row ---
  datGiven[, SquaredError := (y_t - Survival)^2]
  datGiven[, SquaredError_0 := (y_t - Survival_0)^2]
  
  
  # --- Aggregate and compute weighted Brier score per time point
  datTBS <- datGiven[Weight_w > 0 & get(fldStop)<=spellPeriodMax, .(
    mean(Weight_w * SquaredError, na.rm = TRUE),
    mean(Weight_w * SquaredError_0, na.rm = TRUE)
  ), by=list(get(fldStop))]
  setnames(datTBS, c(fldStop, "Brier", "Brier_0"))
  
  # --- Calculate pseudo R^2
  datTBS[, RSquared := 1 - Brier/Brier_0]
  #plot(datTBS$RSquared)
  
  # --- Calculate Integrated Brier Score assuming uniform weights
  IBS <- mean(datTBS$Brier, na.rm=T)
  
  return(list(tBS=datTBS, IBS=IBS))
  
  # - Cleanup (useful during interactive debugging of function)
  rm(datGiven, modGiven, fldKey, fldStart, fldStop, fldCensored, fldSpellAge, predType,
     km_Censoring, datTBS,datG, datG_ti)
}



# ################################ PART 2: TAIWAN HAZARD MODEL ################################

# ================== DISCRETE-TIME HAZARD MODEL: Taiwan credit-card default ==================
# Using only the first 3 observed months (Apr-Jun 2005), predict the probability of first
# default in each later month (Jul-Oct 2005) with a discrete-time hazard (DtH) model.
# Implements steps 0-2, 4, 5, 7 and 8 of 02-survival-analysis.md, section 7. Claude used to help transfer code from literature review to applicable code.
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
#      Rscript report/05-HazardModel-R.R            # threshold 2, default weight 1
#      Rscript report/05-HazardModel-R.R 3          # threshold 3 (90+ days)
#      Rscript report/05-HazardModel-R.R 2 10       # their default weight of 10
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

root <- if (basename(getwd()) %in% c("Alex", "report")) ".." else "."
genPath <- paste0(tempdir(), "/"); genObjPath <- genPath            # log files of aicTable()/concTable()
genFigPath <- paste0(root, "/Alex/figures/"); dir.create(genFigPath, showWarnings = FALSE)
if (.Platform$OS.type == "windows") windowsFonts(Cambria = windowsFont("Cambria"))   # their extrafont setup
if (!interactive()) png(tempfile(fileext = ".png"))   # Rscript: print plots to a font-aware device, not Rplots.pdf
# (functions from Botha & Muller are defined in PART 1 of this file, so no source() is needed)
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
