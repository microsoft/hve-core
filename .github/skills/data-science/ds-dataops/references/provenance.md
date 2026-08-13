---
title: ds-dataops provenance and attribution
description: Source map, reproduction scope, HVE Core derivation labels, and upstream silences for the ds-dataops reference pack
---

## Purpose

This file records where each part of `ds-dataops` comes from, what may be reproduced, and what is not upstream guidance at all. Consult it before treating any statement in this pack as a playbook rule.

## Licensing posture

Microsoft CSE Code With Engineering Playbook documentation is licensed CC BY 4.0, which permits reproduction in whole or in part provided the source is attributed and changes are indicated; `THIRD-PARTY-NOTICES` carries that attribution and states that the content has been changed. The upstream project applies MIT through a separate `LICENSE-CODE` file to code samples only, which this pack does not reproduce.

This repository's licensing posture is stricter than the license itself: it limits reproduction to the minimum text necessary for a specific technical point. This pack paraphrases upstream guidance and reproduces only identifiers and structural names as facts, which keeps it within that limit. The scope column below states what each area actually reproduces. Standards identifiers and structural names are facts rather than licensed prose and are preserved exactly.

## Source map

| Content area                                                     | Upstream source                                                                                                                                                                                                             | Reproduction scope                                                                                                                                                  |
|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Tier names and definitions; additional storage areas             | [Data and DataOps Fundamentals, Data Tiering](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#data-tiering-data-quality)                                      | Tier and storage-area names as identifiers; definitions paraphrased                                                                                                 |
| Validation placement, malformed routing, replay rationale        | [Data and DataOps Fundamentals, Data Validation](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#data-validation)                                             | Boundary and store names as identifiers; placement rule and replay rationale paraphrased                                                                            |
| Replayability and idempotency                                    | [Data and DataOps Fundamentals, Idempotent Data Pipelines](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#idempotent-data-pipelines)                         | Paraphrase only                                                                                                                                                     |
| Transformation and data-access separation; notebooks to packages | [Data and DataOps Fundamentals, Testing](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#testing)                                                             | Paraphrase only                                                                                                                                                     |
| Source-control scope                                             | [Data and DataOps Fundamentals, CI/CD and Source Control](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#cicd-source-control-and-code-reviews)               | Artifact-class names as identifiers; the artifact list reproduces upstream scope                                                                                    |
| Secure configuration                                             | [Data and DataOps Fundamentals, Security and Configuration](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#security-and-configuration)                       | Paraphrase only                                                                                                                                                     |
| Observability includes data; malformed store monitoring          | [Data and DataOps Fundamentals, Observability](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#observability)                                                 | Paraphrase only                                                                                                                                                     |
| Five testing categories, technique, and mocking boundaries       | [Testing Data Science and MLOps Code](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/testing-data-science-and-mlops-code/)                                                                   | Category names and pytest API identifiers as facts; category descriptions and mocking-boundary guidance paraphrased; the code examples described rather than copied |
| ML unit test scope guard                                         | [Testing Data Science and MLOps Code, Basic Unit Tests for ML Models](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/testing-data-science-and-mlops-code/#basic-unit-tests-for-ml-models)    | Scope guard paraphrased; no upstream sentence reproduced                                                                                                            |
| Validation versus drift and remediation asymmetry                | [ML Model Production Checklist, How Will Incoming Data Quality be Monitored](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/#how-will-incoming-data-quality-be-monitored) | Term names as identifiers; the distinction and the remediation pair paraphrased                                                                                     |
| ML observability lifecycle framing                               | [Observability in Machine Learning](https://microsoft.github.io/code-with-engineering-playbook/observability/ml-observability/)                                                                                             | Paraphrase only                                                                                                                                                     |

## Correction to a common misattribution

The validation-versus-drift distinction is frequently attributed to the DataOps or testing pages. It is not on either. It appears on the **ML Model Production Checklist** under "How Will Incoming Data Quality be Monitored?". Cite that page when using the distinction.

The upstream passage is prose, not a two-sentence rule. Any short rendering of it is a condensation and must be presented as attributed paraphrase, never formatted as a quotation.

## Paraphrases where precision is fragile

These points lose technical meaning if compressed carelessly.

* Bronze exists for **two** distinct replay purposes: replay to test validation logic, and replay to recover from a transformation-code bug. A single "replayability" summary removes the reason a team cannot simply re-ingest.
* ML model tests deliberately leave some external calls unstubbed. Dropping that clause turns a deliberate upstream trade-off into an apparent inconsistency.
* Validation and drift have **different** remediation. Validation triggers re-routing and rectification; drift triggers adaptation or retraining. Collapsing both into "investigate" destroys the distinction's usefulness.
* Experiment reproducibility is **not** pipeline replayability. Upstream keeps them separate; the checklists supply the former and the DataOps page supplies the latter.

## HVE Core derivations

The following are reasoned consequences authored for this repository. They are consistent with upstream definitions but are not stated upstream.

| Item                                                       | Upstream basis                                                              | What is derived                                                                                                                                                                       |
|------------------------------------------------------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Per-tier permitted and forbidden behavior                  | Tier definitions and the single validation-placement rule                   | Upstream defines the tiers and one placement rule. It does not enumerate per-tier consequences. Only the Bronze validation refusal is directly upstream-backed.                       |
| Notebook-to-package extraction trigger                     | The invariant that transformation code moves out of notebooks into packages | Upstream states the invariant with no line threshold, duplication heuristic, or execution-count signal. Any threshold is a repository convention.                                     |
| Treating malformed and sandbox as tier-like catalog values | Upstream names them as additional storage areas                             | Upstream's quality model has three tiers. Promoting two storage areas to catalog values is a design choice, and a third named area, libraries and binaries, is intentionally omitted. |

## Upstream silences

Do not present guidance in these areas as playbook-backed.

* No metric names, instrument types, units, thresholds, or dimensions are prescribed anywhere in the source set.
* Observability in Machine Learning is silent on data validation entirely, on the validation-versus-drift comparison, and on drift thresholds, alerting, ownership, and automatic remediation.
* Neither ML checklist names a data-tiering model or states a pipeline-replayability requirement.
* Isolation levels and concurrency control are covered upstream but are peripheral to this pack; use them only when the engagement touches transactional stores.
