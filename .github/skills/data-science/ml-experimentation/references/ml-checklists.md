---
title: ML checklists
description: Topic-level summaries of the ML Fundamentals Checklist and ML Model Production Checklist, with their lifecycle scope and applicability caveats
---

## Sources

* Microsoft CSE Code-with-Engineering-Playbook, [ML Fundamentals Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-fundamentals-checklist/), documentation licensed CC BY 4.0.
* Microsoft CSE Code-with-Engineering-Playbook, [ML Model Production Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/), documentation licensed CC BY 4.0.

Section headings are preserved as structural identifiers. Item content is not reproduced: each section carries a repository-original summary of what it covers and when it applies, and readers follow the upstream links for the item wording. Both pages are licensed CC BY 4.0; see `THIRD-PARTY-NOTICES` for the recorded attribution and usage scope. Explanatory framing, the lifecycle caveat, the readiness-domain grouping, and the routing table are repository-original.

## ML Fundamentals Checklist

Six sections covering engagement fundamentals. Each summary below states what the section is for and when it applies. Read the upstream page for the item wording: <https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-fundamentals-checklist/>

### Data Quality and Governance

Establishes that the data underpinning the engagement is obtainable, understood, and lawful to use. Work here before modelling begins, because an unresolved access, labelling, provenance, or compliance gap invalidates everything downstream.

### Feasibility Study

Establishes whether the data can support the proposed task at all, and whether the expected return justifies the risk. Its conclusion is a documented recommendation on how to proceed. `ds-feasibility` owns this workflow.

### Evaluation and Metrics

Establishes how performance is measured, that the measure traces to agreed success criteria, and that one evaluation flow spans every model version. Treat evaluation code as production code: tested and peer-reviewed, and structured to support later results and error analysis.

### Model Baseline

Establishes a specified, measured baseline so later models have something to be judged against. Without it, a performance claim has no reference point.

### Experimentation setup

Establishes that experiments are comparable and repeatable: specified datasets, recorded hypotheses and results, systematic hyperparameter tuning, and consistent metrics across candidates. See [model-experimentation.md](model-experimentation.md) for the tracking and reproducibility conventions.

### Production

Establishes readiness to operate: reviewed models, a tested inferencing pipeline, agreed SLAs, monitoring of both data feeds and model output, consistent schemas across pipeline components, and a completed Responsible AI review. The production checklist below covers this ground in more depth.

## ML Model Production Checklist

### Lifecycle scope and caveat

Read this before applying the checklist. Upstream scopes it to teams that have **already built or trained** a model and are now considering putting it into production. Its stated purposes are confirming the model is ready for production before moving to scoring, and preparing a production plan.

Upstream also states that there may be scenarios where it is not possible to check every item, and advises going through all items and making informed decisions based on the specific use case.

Treat it as a structured readiness review with a lifecycle precondition, **not** as an unconditional gate.

### Readiness domains

The upstream checklist works through the question of whether a model will behave in production as it did in training. Its items group into five domains. Read the upstream page for the item wording: <https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/>

**Baseline and metric definition.** Whether a specified baseline exists, whether the model beats it, whether performance metrics are settled for training and scoring, and whether the model has been measured against a benchmark.

**Offline-to-online representativeness.** Whether ground truth will be available or derivable once the model is live, and whether the distribution of data across training, testing, and validation sets has been examined. This is where a model that looks strong offline turns out not to be.

**Integration and operating budgets.** How the model joins the systems around it and what that integration affects, plus the targets and hard limits set for performance, prediction speed, and cost that give trade-offs something to be judged against.

**Monitoring.** How incoming data quality, shifts in data characteristics, and model performance are each monitored. `ds-dataops` owns these.

**Ethical review.** Whether ethical implications have been considered. `rai-planner` owns this.

## Routing

Some items are owned elsewhere.

| Items                                                                          | Route to                                                                                           |
|--------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Incoming data quality monitoring, drift monitoring, and performance monitoring | `ds-dataops`, which carries the validation-versus-drift distinction and its asymmetric remediation |
| Ethical concerns                                                               | `rai-planner`                                                                                      |
| Experiment setup, tracking, and evaluation flow                                | [model-experimentation.md](model-experimentation.md)                                               |

## A distinction worth preserving

The ML Fundamentals Checklist names reproducible, logged experiments. That is **experiment reproducibility**, which is not the same as **pipeline replayability**. Neither checklist states a pipeline-replayability requirement, and neither names a data-tiering model. Collapsing the two loses technical precision; pipeline replay semantics belong to `ds-dataops`.
