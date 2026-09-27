# AI use log — Alex

An audit trail of how I directed AI tools in this project: what I asked, what
the tool did, and what I checked. It follows the same format as
`Oscar/AI-LOG.md`, which also has instructions for getting ChatGPT to produce
entries.

**Rules for this log**
* One entry per session, newest at the bottom. Never edit or delete old entries;
  add a correction as a new entry instead.
* Prompts are copied **word for word**, typos included.
* "What it did" names the files it changed. "What I checked" is my own note:
  did I run it, read it, understand it, change it?

---

## 2026-09-27 — Claude Code — review of Oscar's work and next steps

| # | My prompt (verbatim) | What it did | Files |
|---|---|---|---|
| 1 | are u able to upload stuff to my github? | Checked that the GitHub CLI is logged in to my account (`alexrobbo`) with repo access. Said it can create repos, commit and push. Advised keeping lecture notes out of public repos. | none |
| 2 | can u read the files in the folder oscar in github? | Found this repo through my collaborator access, cloned it, and read everything in `Oscar/`. Summarised each notebook and the AI log. | none |
| 3 | ok so i want to start a file in my folder that is effectively a review of what oscar has done and next steps. i want this to be very concise. a big thing im worried about is the data analysis and defining our scope of the project. as we're using the loaners data of their loans as the main information used, i think it would be appropriate to define our scope to be predicting default from 3 months in. he mentions that some columns overlap a lot, i think a way of calculating this would be to calculate vif for each things. i then think some next steps would be to define scoring (f1, confusion matrix, brier, etc), think about data smoothing where there arent many points (laplacian or otherwise) and maybe turn the model into more of a survival model, please turn this into a document including anything that u think is relevant that i havent covered and upload to the github folder alex | Read `PLAN.md` and `data/README.md`. Downloaded the Taiwan data (checksum matches `data/README.md`). Computed VIFs (`BILL_AMT*` 14–26, `PAY_*` 1.9–4.7). Refitted Oscar's baseline logistic regression on three feature sets (all 6 months AUC 0.720; Apr–Jun 0.652; Jul–Sep 0.720). Wrote the review: Oscar's findings, scope, VIF, scoring, smoothing (m-estimate rather than Laplace), discrete-time survival model, open decisions. Committed and pushed (`d4dd3b8`). | `Alex/01-review-and-next-steps.md` |
| 4 | first three months of the loan term, yes put an ai log afterwards | Pointed out that the Taiwan data has no loan start date, so Apr–Jun is the first 3 months of the *observation window*, not of the loan term (the review already says this). Created this log. | `Alex/AI-LOG.md` |

What I checked / changed myself:
