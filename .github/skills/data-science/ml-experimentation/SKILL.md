---
name: ml-experimentation
description: "Machine learning experimentation reference for model-experimentation conventions, experiment tracking and reproducibility, dataset and model abstractions, ML engagement fundamentals, and model-production readiness. Use when standing up ML experimentation infrastructure or assessing whether a trained model is ready for production."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (Code With Engineering Playbook)"
  spec_version: "1.0"
  last_updated: "2026-08-02"
  content_based_on: "https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/model-experimentation/; https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-fundamentals-checklist/; https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/"
---

# ML Experimentation Reference Pack

## Goal

Ground machine learning experimentation in the Microsoft CSE engineering playbook so that environment setup, repository structure, experiment tracking, dataset and model abstractions, evaluation flow, and production-readiness review are applied consistently and attributed accurately.

This pack is machine learning specific. It assumes a model is being trained, tracked, evaluated, or assessed for production. General experiment framing, hypothesis formation, and vetting belong to `experiment-design`.

## Inputs

* The ML experimentation setup under discussion: environments, repository layout, tracking framework, or evaluation flow
* The model under assessment and its training and evaluation history, when readiness is the question
* Existing dataset versioning, parameter tracking, and environment capture practice
* The engagement stage, since the production checklist has a lifecycle precondition

## Reference index

Read only the reference that matches the active concern.

| Reference                                                       | Read this when                                                                                                                                                   |
|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [model-experimentation.md](references/model-experimentation.md) | Standing up virtual environments, repository and notebook structure, experiment tracking and reproducibility, dataset and model abstractions, or evaluation flow |
| [ml-checklists.md](references/ml-checklists.md)                 | Checking ML engagement fundamentals or assessing whether a trained model is ready to move toward production                                                      |
| [provenance.md](references/provenance.md)                       | Confirming what is upstream guidance, what is HVE Core derivation or repository convention, and where upstream is silent                                         |

## Success criteria

* Reproducibility keeps all four elements: dataset names and versions, parameters, code, and environment. Tracking a dataset name without its version is a labelling practice, not reproducibility.
* Datasets and evaluation are defined consistently enough that experiments are comparable. A tracking framework alone does not deliver comparability.
* Checklist section headings and readiness domains are preserved, and applicability caveats travel with them.
* Experiment reproducibility stays distinct from pipeline replayability, which
  belongs to `ds-dataops`, the DataOps skill for tier behavior, pipeline
  invariants, validation placement, tests, drift, and operational signals.

## Constraints

* Reproduce only the minimum text necessary for a specific technical point, and paraphrase everything else. Attribute every reference and describe accurately what each reference reproduces.
* Preserve checklist section headings as structural identifiers and summarize what each section covers. Do not restore the upstream item lists or reconstruct either checklist locally; link readers to the upstream page for item wording.
* Label repository conventions as substitutions rather than upstream recommendations. The `uv` environment convention is a repository substitution, not a playbook recommendation.
* Do not convert a checklist into an unconditional gate. Upstream scopes the production checklist to teams that have already trained a model and permits use-case-specific decisions.

## Ownership boundaries

| Concern                                                                         | Owner                                           |
|---------------------------------------------------------------------------------|-------------------------------------------------|
| Experiment framing, hypothesis formation, vetting criteria, and red flags       | `experiment-design`                             |
| Pipeline mechanics, data tiering, replay semantics, and DS/MLOps test technique | `ds-dataops`                                    |
| Data validation, drift detection, and their asymmetric remediation              | `ds-dataops`                                    |
| Ethical and Responsible AI review                                               | `rai-planner`                                   |
| Telemetry naming and data sensitivity classification                            | `telemetry-foundations` and `privacy-standards` |

## Stop rules

* Stop and route to `experiment-design`, the general experiment selection,
  hypothesis, vetting, scope, and evaluation skill, when the request is about
  whether an experiment is worth running rather than how to run it.
* Stop and state the lifecycle precondition when the production checklist is invoked for a model that has not been built or trained.
* Stop and state the gap when upstream does not cover the request, such as a universal framework, tool, or metric choice made without project context.

## Attribution

This pack declares `CC-BY-4.0`.

Both references derive from Microsoft CSE Code With Engineering Playbook documentation pages, which are licensed CC BY 4.0. Upstream guidance is summarized rather than reproduced; section headings and tool and file names are carried across as identifiers. The upstream project applies MIT through a separate `LICENSE-CODE` file to code samples only, which this pack does not reproduce. Each reference cites its own upstream URL, states that changes were made, and describes what it reproduces.

Explanatory framing, the lifecycle caveat, the readiness-domain grouping, the routing table, and the `uv` substitution are repository-original.

See [provenance.md](references/provenance.md) for the consolidated source map and derivation labels.
