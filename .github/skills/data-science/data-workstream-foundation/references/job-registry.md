---
title: Data Workstream Job Registry
description: Authoritative job names, lifecycle classes, skill and specialist routes, and durable outputs for Data Workstream Coach sessions
---

# Data Workstream Job Registry

## Purpose

Use this registry before offering or selecting work. A job is a user-confirmed
unit of focus inside one continuing coaching session. The registry routes work;
it does not duplicate the methods owned by a skill.

## Registry

| Job             | Class        | Primary route                                                                                | Optional supporting route                                                                                                                | Durable output or completion evidence                           |
|-----------------|--------------|----------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| `catalog`       | `continuous` | `ds-catalog`: durable catalog entities, declared relationships, lineage, and model semantics | `ds-analysis-authoring` when a presented dataset profile is the requested output; `privacy-standards` for classification citation fields | Caller-approved data catalog                                    |
| `model-diagram` | `episodic`   | `ds-catalog`: authoritative declared entities and relationships                              | `architecture-diagrams`: render the declared model without becoming semantic authority                                                   | Mermaid or ASCII diagram                                        |
| `feasibility`   | `bounded`    | `ds-feasibility`: evidence-led feasibility studies with durable traceability                 | None                                                                                                                                     | Caller-approved feasibility study                               |
| `pipeline`      | `episodic`   | `ds-dataops`: tier behavior, pipeline invariants, validation, tests, and drift               | `privacy-standards` for sensitivity classification and DPIA thresholds                                                                   | Transformation, validation, or pipeline code                    |
| `analysis`      | `episodic`   | `ds-analysis-authoring`: EDA notebook and analytical dashboard authoring and validation      | `ds-catalog` for column semantics; `ds-dataops` for derived-dataset persistence                                                          | Notebook, dashboard, or analysis deliverable                    |
| `evaluation`    | `episodic`   | `ds-evaluation-design`: AI-system evaluation dataset design, metrics, and tooling            | `rai-planner` when a surfaced risk needs assessment rather than a test case                                                              | Evaluation dataset with curation, metric, and tooling documents |
| `experiment`    | `episodic`   | `experiment-design`: experiment selection, hypotheses, vetting, scope, and evaluation        | `ml-experimentation`: ML reproducibility, tracking, evaluation, abstractions, and production readiness                                   | Hypothesis, experiment assets, and result disposition           |
| `testing`       | `episodic`   | `ds-dataops`: DataOps and DS/MLOps test techniques                                           | `ds-analysis-authoring` for dashboard validation technique                                                                               | Test code and assertions                                        |
| `observability` | `episodic`   | `ds-dataops`: data/model signals and validation-versus-drift guidance                        | `telemetry-foundations`: metric names, instruments, units, cardinality, and PII-safe telemetry conventions                               | Instrumentation code and signal recommendations                 |

## Seven-skill boundaries

The Data Workstream Coach routes to seven Data Science skills. Keep their
authority separate even when one job loads more than one skill.

| Exact skill name        | Capability description                                                                                          | Does not own                                                                                  |
|-------------------------|-----------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `ds-catalog`            | Durable catalog entities, declared relationships, identity, coverage, lineage, and attached dataset profiles    | Pipeline tier behavior, inferred diagram relationships, or feasibility verdicts               |
| `ds-dataops`            | DataOps tier semantics, pipeline invariants, validation, tests, drift, signals, and derived-dataset persistence | Catalog meaning, experiment selection, ML tracking setup, or sensitivity classification       |
| `ds-feasibility`        | Evidence-led feasibility studies, lifecycle, recommendations, and interchange traceability                      | Functional requirement numbering, downstream writeback, catalog semantics, or implementation  |
| `ds-analysis-authoring` | EDA notebook and analytical dashboard composition, visualization selection, and dashboard validation            | Column semantics, persistence format, accessibility conformance, or evaluation dataset design |
| `ds-evaluation-design`  | AI-system evaluation dataset design, difficulty balance, metric selection, and tooling fit                      | Trained-model evaluation, Responsible AI approval, or session and durable-write mechanics     |
| `experiment-design`     | Experiment selection, hypotheses, vetting, minimum scope, and result evaluation                                 | ML infrastructure, production implementation, or pipeline mechanics                           |
| `ml-experimentation`    | ML environments, reproducibility, tracking, abstractions, evaluation, and readiness                             | General hypothesis framing, pipeline replay, or Responsible AI approval                       |

The two evaluation authorities are adjacent and must not be blended.
`ds-evaluation-design` covers systems whose output is a response, such as
assistants and agents. `ml-experimentation` covers a trained model's predictive
performance.

## Selection rules

1. Present the relevant jobs with their class and expected output.
2. Ask the user to choose; do not infer or activate a job silently.
3. Record the confirmed job and its class using the session-state protocol.
4. Load the primary skill before job-specific guidance.
5. Load a supporting route only for the concern it owns, then reconcile the
   result into the session artifact list without transferring authority to it.
6. When a capability is unavailable in the installed collection, state the gap
   and offer an available route. Do not improvise a missing capability.

## Routing boundary

A supporting route contributes within its own authority. The coach retains
session identity, job selection, transition decisions, state mutation, pause and
resume, durable-write gates, and completion choices. Loading a supporting skill
never changes the active job without user confirmation.

## Provenance

This registry is repository-original guidance licensed under CC BY 4.0. It
does not reproduce or summarize an external standard.
