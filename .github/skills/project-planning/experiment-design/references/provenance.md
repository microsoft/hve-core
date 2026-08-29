---
title: experiment-design provenance and attribution
description: Source map, reproduction scope, HVE Core derivations, and boundaries for the experiment-design reference pack
---

## Purpose

This file records where each part of `experiment-design` comes from and what is repository convention rather than upstream guidance.

## Licensing posture

This pack holds repository-original content and HVE Core guidance informed by upstream sources, both licensed CC BY 4.0. It reproduces no upstream reference text.

The pack previously carried two Microsoft CSE Code With Engineering Playbook references. Those moved to `ml-experimentation` when the ML-only material was separated from general experiment coaching. Their source map, reproduction scope, and licensing statements travelled with them and are recorded in that pack's provenance.

Microsoft CSE Code With Engineering Playbook documentation is licensed CC BY 4.0, which requires attribution and an indication that changes were made; `THIRD-PARTY-NOTICES` carries both. This repository's licensing posture is stricter than the license and limits reproduction to the minimum text necessary for a specific technical point. [experiment-readiness.md](experiment-readiness.md) satisfies that limit: it paraphrases throughout and reproduces no upstream passage.

Google for Developers machine-learning documentation is licensed CC BY 4.0 under the same requirements, and `THIRD-PARTY-NOTICES` carries its attribution and change statement. The NEOS Guide reserves rights and is therefore cited only: no NEOS text, taxonomy, diagram, or derivative of them appears in this pack, and no content claims derivation from it.

## Source map

| Content area                                                                                                                                    | Source                                                                                                                                                     | Reproduction scope                                                                       |
|-------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------|
| MVE methodology, hypothesis format, vetting criteria, red flags, experiment types, design practices, results evaluation, and the backlog bridge | HVE Core original material                                                                                                                                 | Not derived from any upstream source                                                     |
| Machine-learning versus non-machine-learning comparison, and the supervised entry conditions of labelled outcomes and prediction-time features  | [Understand the problem](https://developers.google.com/machine-learning/problem-framing/problem)                                                           | Paraphrased and reorganized into per-paradigm entry tests; no passage reproduced         |
| Beginning with a heuristic and moving to machine learning once the heuristic becomes hard to maintain                                           | [Rules of Machine Learning](https://developers.google.com/machine-learning/guides/rules-of-ml)                                                             | Paraphrased; no passage reproduced                                                       |
| Optimization problem types, as further reading only                                                                                             | [NEOS Guide](https://neos-guide.org/guide/types/)                                                                                                          | Cited only; nothing reproduced, paraphrased, classified, or derived                      |
| Cross-paradigm routing, the broader analytical-fit judgement, and the gap and output contracts                                                  | HVE Core original material                                                                                                                                 | Not derived from any upstream source                                                     |
| Candidate generation from a failure exercise, and the mid-flight share that re-prioritizes the next experiment                                  | [Engineering Feasibility Spikes](https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/recipes/engineering-feasibility-spikes/) | Paraphrased and generalized; upstream terms named for findability; no passage reproduced |
| Evidence-based comparison of competing options, and when not to run one                                                                         | [Trade Studies](https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/trade-studies/)                                           | Paraphrased and generalized; upstream terms named for findability; no passage reproduced |

MVE coaching content in this pack is HVE Core original material. It was consolidated here from a repository instruction file so that on-demand methodology has a single authoritative home.

## Precision worth preserving

* An identifier recorded without its version is a label, not a reproducible reference. Whether it names a dataset, a firmware build, a model endpoint, a container image, or a hardware revision, dropping the version turns a reproducibility requirement into a labelling suggestion.
* Consistency across inputs and evaluation is what makes experiments comparable. A tracking tool alone does not deliver comparability.

## HVE Core derivations

| Item                                                              | Position                                                                                                            |
|-------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| MVE methodology, vetting criteria, red flags, and backlog bridge  | HVE Core original coaching material, consolidated into this pack                                                    |
| Cross-paradigm routing among candidate problem classes            | HVE Core original. No external standard adjudicates across paradigms; the cited source is machine-learning scoped.  |
| The broader not-a-modelling-problem judgement                     | HVE Core original. The cited source decides machine learning versus not machine learning only.                      |
| Optimization problem-type classification                          | Not stated by this pack. The framing procedure records the structural question and cites NEOS as further reading.   |
| The gap contract with an answer holder and a separate coordinator | HVE Core original, established by prototype testing rather than upstream guidance                                   |
| Prioritization signals for choosing among candidate experiments   | HVE Core guidance. Upstream describes re-prioritizing after each share but does not enumerate selection signals.    |
| Generalizing spikes and trade studies beyond engagement work      | HVE Core framing. Upstream scopes both practices to customer engagements with named ceremonies and meeting lengths. |

## Where this pack is silent

* Whether a proposed outcome is achievable with the available data and evidence belongs to `feasibility`. This pack exposes candidate problem classes; it does not assess them.
* ML experimentation setup, experiment tracking frameworks, dataset and model abstractions, model evaluation flow, and ML checklists belong to `ml-experimentation`.
* Pipeline mechanics, data tiering, replay semantics, and DS/MLOps test technique belong to `dataops`.
* This pack does not select a universal framework, tool, metric, or threshold. It requires that a team decide, document, and apply one consistently, and that decision depends on project context.
