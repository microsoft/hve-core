---
title: ML checklists
description: The ML Fundamentals Checklist and ML Model Production Checklist structures, with their lifecycle scope and applicability caveats
---

## Sources

* Microsoft CSE Code-with-Engineering-Playbook, [ML Fundamentals Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-fundamentals-checklist/), documentation licensed CC BY 4.0.
* Microsoft CSE Code-with-Engineering-Playbook, [ML Model Production Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/), documentation licensed CC BY 4.0.

Section headings and short item labels are preserved as structural identifiers. Item text is paraphrased from the upstream checklists; only the headings, the labels, and the named concepts are carried across as facts. Both pages are licensed CC BY 4.0; see `THIRD-PARTY-NOTICES` for the recorded attribution and usage scope. Explanatory framing, the lifecycle caveat, and the routing table are repository-original.

## ML Fundamentals Checklist

Six sections covering engagement fundamentals.

### Data Quality and Governance

1. Access to the data has been arranged.
2. The dataset in question comes with labels.
3. The quality of that data has been assessed.
4. Lineage can be followed through the data.
5. Where the data came from is known, together with the policy governing access to it.
6. Security and compliance requirements have been collected.

### Feasibility Study

1. A feasibility study established whether the data can support the tasks proposed.
2. Exploratory analysis was thorough and examined how the data is distributed.
3. Hypotheses were tested against enough evidence to accept or rule out an ML approach as feasible.
4. Expected return was estimated and the project's risk was analysed.
5. The outputs and assets ML produces can be taken up by the production system.
6. A documented recommendation on how to proceed exists.

### Evaluation and Metrics

1. There is a clear definition of how performance gets measured.
2. Those metrics trace back to the agreed success criteria.
3. The datasets available are sufficient to compute them.
4. One evaluation flow covers every version of the model.
5. Evaluation code carries unit tests and has been reviewed by peers across the team.
6. The evaluation flow leaves room for later results analysis and error analysis.

### Model Baseline

1. A clearly specified baseline model exists and its performance has been measured.
2. Other ML models can be judged against that baseline.

### Experimentation setup

1. Training and test datasets are clearly specified and labelled.
2. Experiments can be rerun and are logged somewhere every data scientist can reach, so iteration stays quick.
3. The hypotheses to test and the experiments that test them are defined.
4. Results from each experiment are written down.
5. Model hyperparameters are tuned by a systematic method.
6. Candidate models are compared on identical performance metrics and consistent datasets.

### Production

1. The model readiness checklist has been worked through.
2. Model reviews have taken place, spanning model debugging, the training and evaluation approach, and observed model performance.
3. An inferencing data pipeline is in place and covered by end-to-end tests.
4. SLA requirements for the models have been collected and recorded.
5. Both the data feeds and the model output are monitored.
6. One schema holds across the system, with expected input and output stated for every pipeline component, models and data-processing steps alike.
7. A Responsible AI review has been completed.

## ML Model Production Checklist

### Lifecycle scope and caveat

Read this before applying the checklist. Upstream scopes it to teams that have **already built or trained** a model and are now considering putting it into production. Its stated purposes are confirming the model is ready for production before moving to scoring, and preparing a production plan.

Upstream also states that there may be scenarios where it is not possible to check every item, and advises going through all items and making informed decisions based on the specific use case.

Treat it as a structured readiness review with a lifecycle precondition, **not** as an unconditional gate.

### Checklist

Each item states the question it asks.

1. Whether a clearly specified baseline exists and the model performs better than it.
2. Whether ML performance metrics are settled for both training and scoring.
3. Whether the model has been measured against a benchmark.
4. Whether ground truth will be available, or derivable, once the model is live.
5. Whether the spread of data across the training, testing, and validation sets has been examined.
6. Whether targets and hard limits are set for performance, prediction speed, and cost, giving trade-offs something to be judged against.
7. How the model joins up with surrounding systems, and what that integration affects.
8. How the quality of incoming data gets monitored.
9. How shifts in the characteristics of that data get monitored.
10. How model performance gets monitored.
11. Whether ethical implications have been considered.

The same page expands each item under the grouping "Will Your Model Performance be Different in Production than During the Training Phase", using matching subheadings.

## Routing

Some items are owned elsewhere.

| Items                                                                          | Route to                                                                                           |
|--------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Incoming data quality monitoring, drift monitoring, and performance monitoring | `ds-dataops`, which carries the validation-versus-drift distinction and its asymmetric remediation |
| Ethical concerns                                                               | `rai-planner`                                                                                      |
| Experiment setup, tracking, and evaluation flow                                | [model-experimentation.md](model-experimentation.md)                                               |

## A distinction worth preserving

The ML Fundamentals Checklist names reproducible, logged experiments. That is **experiment reproducibility**, which is not the same as **pipeline replayability**. Neither checklist states a pipeline-replayability requirement, and neither names a data-tiering model. Collapsing the two loses technical precision; pipeline replay semantics belong to `ds-dataops`.
