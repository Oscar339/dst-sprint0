# Conclusion: Credit Risk

We considered various approaches to modelling probability of default. Firstly, we cleaned the data, we looked for duplicates as well as checking the file's documentation. We then found 3 different types of model that could be used to model this dataset with our goal in mind: a logistic regression model, a hazard model and a Markov model. These various models all have their pros and cons and these have been explored in each area of this project.

| Notebook | What we found |
|---|---|
| 01 | The file differs from its documentation in 5 places (e.g. undocumented `PAY_*` codes -2 and 0, which behave as "not behind"). |
| 02 | The logistic regression reproduces the paper's ranking but its probabilities are S-shaped, which the paper's straight-line summary hides. |
| 03 | Calibration fixes the logistic regression's probabilities without changing its ranking. |
| 04 | Because our data is monthly, a discrete-time hazard model is the natural fit.|
| 05 | The imported code needed our data put into their structure and their default weight changed from 10 to 1. The model gives P(default by October) for customers with no default by June. |

## What the resources tell us

- How approaches compare. A model can rank customers well and still give poor probabilities, so each needs its own checks. Logistic regression ranked well but its probabilities were S-shaped. Isotonic calibration fixed them without changing the ranking. The hazard model adds the timing of default, which neither of the other approaches gives.
- Whether generic resources apply. Yes, with changes. The scikit-learn example ran exactly as published, but on credit data we had to calibrate with a held-out set and group customers into equal-size bins
- How sharing code helps or limits. Published code was much easier to reproduce than a paper without it. We matched Yeh & Lien's logistic regression from the text, but could not match their naive Bayes, which came out well below logistic regression in scikit-learn's version, so this remains open. Even with code, Botha & Muller's functions only worked after we rebuilt our data into their structure and changed their default settings.

## Limits

The data covers only seven months, has no account age and no true default date,
so the survival event is a proxy built from repayment status (04). The Taiwan
file is also from 2005 and a single dataset, so conclusions may not carry to other
lenders. This data limit leads to complications of overfitting etc such that in 
the future we will test various different models with various parameters to try 
and optimise our model

## Outcome

From our initial research, with the data that we have chosen to use, logistic regression and survival modelling seem to be the most appropriate models. Data processing will be something that we have to do before any modelling step and is covered by Oscar. 
