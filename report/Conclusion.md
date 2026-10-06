# Conclusion: Credit Risk

We considered various approaches to modelling probability of default. Firstly, we cleaned the data, we looked for duplicates as well as 

| Notebook | Resource | What it gave us | What we found |
|---|---|---|---|
| 01 | UCI dataset page and Yeh & Lien (2009) | The data and its documentation | The file differs from its documentation in 5 places (e.g. undocumented `PAY_*` codes -2 and 0, which behave as "not behind"). Cleaning came first. |
| 02 | Yeh & Lien (2009) | A published benchmark for six classifiers | The logistic regression reproduces the paper's ranking (area ratio 0.44, mean of 20 splits) but its probabilities are S-shaped, which the paper's straight-line summary hides. |
| 03 | scikit-learn calibration example (Niculescu-Mizil & Caruana, 2005; Platt, 1999; Zadrozny & Elkan, 2002) | Runnable code to fix probabilities | Isotonic calibration fixes the logistic regression's probabilities without changing its ranking. Sigmoid does not, and we could not reproduce the paper's naive Bayes. |
| 04 | Survival analysis literature (Banasik, Crook & Thomas, 1999; Shumway, 2001; Bellotti & Crook, 2013) | The case for modelling *when* customers default, not only *whether* | A discrete-time hazard model fits our monthly data best. A Cox model adds little with only 4 time points, so we did not build one. |
| 05 | Botha & Muller (2025) code, adapted | A working discrete-time hazard model in R | Their code needed our data put into their structure and their defaults changed (e.g. default weight 10 mis-calibrates our data). |

## Themes

- **Ranking is not probability.** The papers and examples we used mostly judge
  models by how well they rank customers. For managing risk the probability
  matters, and it needs its own checks (calibration curves, Brier score).
- **Reproducing a result takes more than its method name.** The paper's naive
  Bayes and the paper's data size could not be matched from the text alone.
  Published code (03, 05) was far easier to reproduce than a paper without code
  (02).
- **Code has to be adapted, not just run.** Every resource needed changes for
  our data, and we marked each one.

## Limits

The data covers only seven months, has no account age and no true default date,
so the survival event is a proxy built from repayment status (04). The Taiwan
file is also from 2005 and a single bank, so conclusions may not carry to other
lenders.

## References

* Banasik, J., Crook, J. N. & Thomas, L. C. (1999). Not if but when will
  borrowers default. *Journal of the Operational Research Society* 50(12),
  1185–1190.
* Bellotti, T. & Crook, J. (2013). Forecasting and stress testing credit card
  default using dynamic models. *International Journal of Forecasting* 29(4),
  563–574.
* Botha, A. & Muller, M. (2025). Approaches for modelling the term-structure of
  default risk under IFRS 9: a tutorial using discrete-time survival analysis.
  https://doi.org/10.5281/zenodo.15856389
* Niculescu-Mizil, A. & Caruana, R. (2005). Predicting good probabilities with
  supervised learning. *Proceedings of the 22nd ICML*, 625–632.
* Platt, J. (1999). Probabilistic outputs for support vector machines and
  comparisons to regularized likelihood methods. In *Advances in Large Margin
  Classifiers*, MIT Press.
* Shumway, T. (2001). Forecasting bankruptcy more accurately: a simple hazard
  model. *Journal of Business* 74(1), 101–124.
* Yeh, I-C. (2009). *Default of Credit Card Clients* [dataset]. UCI Machine
  Learning Repository. https://doi.org/10.24432/C55S3H
* Yeh, I-C. & Lien, C-H. (2009). The comparisons of data mining techniques for
  the predictive accuracy of probability of default of credit card clients.
  *Expert Systems with Applications* 36(2), 2473–2480.
* Zadrozny, B. & Elkan, C. (2002). Transforming classifier scores into accurate
  multiclass probability estimates. *Proceedings of the 8th ACM SIGKDD*,
  694–699.
