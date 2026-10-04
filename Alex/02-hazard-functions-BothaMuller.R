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