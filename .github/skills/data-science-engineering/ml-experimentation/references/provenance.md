---
title: ml-experimentation provenance and attribution
description: Source map, reproduction scope, HVE Core substitutions, and upstream silences for the ml-experimentation reference pack
---

## Purpose

This file records where each part of `ml-experimentation` comes from, what may be reproduced, and what is repository convention rather than upstream guidance.

## Licensing posture

Microsoft CSE Code With Engineering Playbook documentation is licensed CC BY 4.0, which permits reproduction in whole or in part provided the source is attributed and changes are indicated; `THIRD-PARTY-NOTICES` carries that attribution and states that the content has been changed. The upstream project applies MIT through a separate `LICENSE-CODE` file to code samples only, which this pack does not reproduce.

This repository's licensing posture is stricter than the license itself: it limits reproduction to the minimum text necessary for a specific technical point, and it treats reproducing a whole upstream page or section as out of bounds even where the license would permit it. The references in this pack summarize upstream guidance and reproduce only identifiers and structural names as facts, which keeps them within that limit. The scope column below states what each area actually reproduces. Checklist section headings are structural identifiers; the checklist item lists themselves are not reproduced.

## Source map

| Content area                                                            | Upstream source                                                                                                                       | Reproduction scope                                                                                                           |
|-------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| Model experimentation goals, five practice areas, and expected outcomes | [Model Experimentation](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/model-experimentation/)         | Area names, goal names, and tool and file identifiers as facts; goals, guidance, and expected outcomes paraphrased           |
| ML Fundamentals Checklist structure                                     | [ML Fundamentals Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-fundamentals-checklist/) | Section headings as structural identifiers; item lists not reproduced, replaced by repository-original per-section summaries |
| ML Model Production Checklist structure, scope, and caveat              | [ML Model Production Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/)    | Purpose and caveat paraphrased; item list not reproduced, regrouped into repository-original readiness domains               |

## Paraphrases where precision is fragile

* Full reproducibility requires tracking dataset names **and versions**, parameters, code, and environment. Dropping "and versions" turns a reproducibility requirement into a labelling suggestion.
* The ML Model Production Checklist is scoped to teams that have already built or trained a model and are considering production. It explicitly allows that some scenarios cannot satisfy every item and directs teams to make informed, use-case-specific decisions. It is not a universal completion gate.
* Consistency across datasets and evaluation is what makes experiments comparable. A tracking framework alone does not deliver comparability.

## HVE Core substitutions and derivations

| Item                        | Upstream position                                                                                                             | Repository position                                                                                                                                                    |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Virtual environment tooling | Upstream names `venv`, `Conda`, and `Poetry`, and gives a selection rationale based on environment complexity and ease of use | HVE Core uses `uv`. This is a repository substitution. `uv` does not appear upstream; preserve upstream's selection rationale when advising a team that is choosing.   |
| Checklist routing table     | Not upstream                                                                                                                  | HVE Core routing that assigns monitoring items to `dataops` and ethical concerns to `rai-planner`                                                                      |
| Readiness-domain grouping   | Not upstream                                                                                                                  | HVE Core grouping of the production checklist into baseline and metrics, offline-to-online representativeness, integration and budgets, monitoring, and ethical review |
| Lifecycle caveat framing    | Upstream states the precondition and the informed-decision allowance                                                          | HVE Core presents them together as a structured readiness review rather than an unconditional gate                                                                     |

## Where upstream is silent

* Upstream does not state a pipeline-replayability requirement and does not name a data-tiering model. Experiment reproducibility and pipeline replayability are distinct; replay semantics belong to `dataops`.
* Upstream does not prescribe a universal tracking framework, metric, or threshold. It names commonly used options and directs teams to decide from project context.
