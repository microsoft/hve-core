---
title: ml-experimentation
description: "Machine learning experimentation reference for model-experimentation conventions, experiment tracking and reproducibility, dataset and model abstractions, ML engagement fundamentals, and model-production readiness. Use when standing up ML experimentation infrastructure or assessing whether a trained model is ready for production."
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - ml-experimentation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | skill                                                        |
| Source      | `.github/skills/data-science-engineering/ml-experimentation` |
| Invocation  | Loaded on demand by referencing agents                       |
| Interactive | No                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Machine learning experimentation reference for model-experimentation conventions, experiment tracking and reproducibility, dataset and model abstractions, ML engagement fundamentals, and model-production readiness. Use when standing up ML experimentation infrastructure or assessing whether a trained model is ready for production.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reach for this skill when machine learning experimentation needs structure, or when a trained model is being assessed for production:

* Standing up ML experimentation: virtual environments, repository and notebook structure, and the decision about how notebooks are stored and versioned.
* Choosing and configuring an experiment tracking framework, and deciding what must be tracked for a run to be reproducible.
* Designing dataset, model, and evaluator abstractions so new logic can enter the pipeline without breaking the agreed experimentation flow.
* Working through the ML Fundamentals Checklist on an engagement, or the ML Model Production Checklist once a model has been trained.

Choose a different asset when:

* The question is whether an experiment is worth running at all, or how to turn an unknown into a falsifiable hypothesis. Use the `experiment-design` skill.
* The question is about data tiering, pipeline invariants, replay semantics, or data test suites. Use the `dataops` skill.
* The question is about data validation versus drift detection and their remediation paths. That distinction lives in `dataops`.
* The question is about ethical or Responsible AI review. Use the `rai-planner` skill.

## Example usage

Ask an agent that loads this skill to review an experimentation setup:

```text
We're tracking experiment runs in MLflow but our results still aren't
comparable between team members. What are we missing?
```

The skill supplies the four elements reproducibility requires (dataset names and versions, parameters, code, and environment), and the distinction that a tracking framework alone does not deliver comparability: datasets and evaluation have to be defined consistently first. It names the common failure directly, that tracking a dataset name without its version is a labelling practice rather than reproducibility.
