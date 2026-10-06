# Conclusion: Credit Risk

We considered various approaches to modelling probability of default. Firstly, we cleaned the data, we looked for duplicates as well as checking the file's documentation. We then found 3 different types of model that could be used to model this dataset with our goal in mind: a logistic regression model, a hazard model and a Markov model. These various models all have their pros and cons and these have been explored in each area of this project.

| Notebook | What we found |
|---|---|
| 01 | The file differs from its documentation in 5 places (e.g. undocumented `PAY_*` codes -2 and 0, which behave as "not behind"). |
| 02 | The logistic regression reproduces the paper's ranking but its probabilities are S-shaped, which the paper's straight-line summary hides. |
| 03 | Calibration fixes the logistic regression's probabilities without changing its ranking. |
| 04 | A discrete-time hazard model fits our monthly data well.|
| 05 | Actual code relevant and useful to our project, needed changing a little to fit our data and our project goals. |

## Themes

- Ranking is not probability. The papers and examples we used mostly judge
  models by how well they rank customers. For managing risk the probability
  matters, and it needs its own checks (calibration curves, Brier score).
- Reproducing a result takes more than its method name. The paper's naive
  Bayes and the paper's data size could not be matched from the text alone.
  Published code (03, 05) was far easier to reproduce than a paper without code
  (02).
- Code has to be adapted, not just run. Every resource needed changes for
  our data, and we marked each one.

## Limits

The data covers only seven months, has no account age and no true default date,
so the survival event is a proxy built from repayment status (04). The Taiwan
file is also from 2005 and a single bank, so conclusions may not carry to other
lenders. This data limit leads to complications of overfitting etc such that in 
the future we will test various different models with various parameters to try 
and optimise our model

## Outcome

From our initial research, with the data that we have chosen to use, logistic regression and survival modelling seem to be the most appropriate models. Data processing will be something that we have to do before any modelling step and is covered by Oscar. 
