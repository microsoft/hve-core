---
title: Data Science and Engineering Job Registry
description: Authoritative job names, lifecycle classes, skill and specialist routes, and durable outputs for Data Science and Engineering Coach sessions
---

# Data Science and Engineering Job Registry

## Purpose

Use this registry before offering or selecting work. A job is a user-confirmed
unit of focus inside one continuing coaching session. The registry routes work;
it does not duplicate the methods owned by a skill.

## Registry

| Job               | Class        | Primary route                                                                                                        | Optional supporting route                                                                              | Durable output or completion evidence                           |
|-------------------|--------------|----------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| `catalog`         | `continuous` | `data-catalog`: durable catalog entities, declared relationships, lineage, and model semantics                       | `analysis-authoring` when a presented dataset profile is the requested output                          | Caller-approved data catalog                                    |
| `model-diagram`   | `episodic`   | `data-catalog`: authoritative declared entities and relationships                                                    | `architecture-diagrams`: render the declared model without becoming semantic authority                 | Mermaid or ASCII diagram                                        |
| `problem-framing` | `episodic`   | `experiment-design`: candidate data-science problem classes for a stated business outcome, with entry-test reasoning | None                                                                                                   | Candidate framing set with reasoning, unknowns, and gaps        |
| `feasibility`     | `bounded`    | `feasibility`: evidence-led feasibility studies with durable traceability                                            | None                                                                                                   | Caller-approved feasibility study                               |
| `pipeline`        | `episodic`   | `dataops`: tier behavior, pipeline invariants, validation, tests, and drift                                          | None                                                                                                   | Transformation, validation, or pipeline code                    |
| `analysis`        | `episodic`   | `analysis-authoring`: EDA notebook and analytical dashboard authoring and validation                                 | `data-catalog` for column semantics; `dataops` for derived-dataset persistence                         | Notebook, dashboard, or analysis deliverable                    |
| `evaluation`      | `episodic`   | `evaluation-design`: AI-system evaluation dataset design, metrics, and tooling                                       | `rpi-research` only for a demonstrated live evaluator-catalog fact gap                                 | Evaluation dataset with curation, metric, and tooling documents |
| `experiment`      | `episodic`   | `experiment-design`: experiment selection, hypotheses, vetting, scope, and evaluation                                | `ml-experimentation`: ML reproducibility, tracking, evaluation, abstractions, and production readiness | Hypothesis, experiment assets, and result disposition           |
| `testing`         | `episodic`   | `dataops`: DataOps and DS/MLOps test techniques                                                                      | `analysis-authoring` for dashboard validation technique                                                | Test code and assertions                                        |
| `observability`   | `episodic`   | `dataops`: data/model signals and validation-versus-drift guidance                                                   | None                                                                                                   | Instrumentation code and signal recommendations                 |

Optional supporting routes in the registry are job-specific skill support and do not limit the separate segment-level Research eligibility defined by the RPI depth matrix.

## RPI depth matrix

RPI is a user-directed depth route inside the confirmed job, not a job or lifecycle. Keep simple or adequately evidenced work on the primary route. No RPI segment auto-activates. Before each eligible segment, state the demonstrated need, purpose, expected artifact, expected interaction cost, limits, and direct path available if the user skips it.

| Job               | Research posture                                                                                                         | Execution-loop eligibility                                 | RPI does not own                                                                       |
|-------------------|--------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------|----------------------------------------------------------------------------------------|
| `catalog`         | None by default                                                                                                          | None by default                                            | Catalog identity, semantics, enrichment, or continuous lifecycle                       |
| `model-diagram`   | None by default                                                                                                          | None by default                                            | Declared relationships, diagram format, or episodic completion                         |
| `problem-framing` | `analysis` mode for a named current-fact or prior-art gap; preserve alternatives and unknowns                            | None by default                                            | Selecting, ranking, or scoring a problem class                                         |
| `feasibility`     | Bounded current-fact evidence that the feasibility study cannot establish locally                                        | None by default                                            | Feasibility verdict, study lifecycle, or recommendation authority                      |
| `pipeline`        | Current platform, compatibility, standard, or prior-art facts identified by `dataops`                                    | Full Plan, Implement, and Review for substantial delivery  | Tier semantics, pipeline invariants, validation placement, or scan authority           |
| `analysis`        | Current library, platform, accessibility, or analytical-method facts identified by `analysis-authoring`                  | Full Plan, Implement, and Review for substantial delivery  | Analytical intent, visualization choice, dashboard validation, or scan authority       |
| `evaluation`      | Current evaluator names, availability, preview state, compatibility, and prerequisites identified by `evaluation-design` | Full Plan, Implement, and Review for substantial delivery  | Metric selection, dataset design, tooling fit, or scan authority                       |
| `experiment`      | Inherit the Experiment Designer convergence Research contract                                                            | Inherit the Experiment Designer post-design execution loop | Hypotheses, criteria, experiment outcome, or partner commitments                       |
| `testing`         | Current tool, framework, compatibility, or prior-art facts identified by the owning skill                                | Full Plan, Implement, and Review for substantial delivery  | Test intent, assertion authority, or scan authority                                    |
| `observability`   | Current platform, telemetry, compatibility, or prior-art facts identified by the owning skill                            | Full Plan, Implement, and Review for substantial delivery  | Signal-selection intent, telemetry vocabulary, drift interpretation, or scan authority |

Substantial delivery means multi-step code or artifact production whose dependencies, validation, or interruption risk make direct episodic execution unreliable. The owning skill first accepts the domain design. RPI then plans and executes delivery and reviews conformance without changing the job, class, owning skill, coach state authority, output root, or durable-write gate.

`RPI Researcher` may run only as an internal helper to an active `rpi-research` phase for one bounded source-gathering lane. Its return is not an independent job, invocation, state record, evidence authority, or recommendation. The active Research phase verifies selected sources and exclusively owns canonical evidence IDs, findings, recommendations, and the primary artifact.

The cross-cutting concerns below are evaluated in addition to the routes in this
table. They are not listed per job, because they apply by trigger rather than by
job name.

## Cross-cutting concerns

Privacy, Responsible AI, and telemetry are evaluated across every job rather
than being optional per-job routes. Evaluate each concern whenever its trigger
is present, name the concern to the user, and route to its owning skill for the
contribution that skill owns.

| Concern        | Trigger to evaluate                                                                                                  | Owning skill                                             | Contribution                                                                                   |
|----------------|----------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------|
| Privacy        | Personal, sensitive, or regulated data is catalogued, moved, transformed, sampled, analyzed, presented, or persisted | `privacy-standards`                                      | Sensitivity classification, citation fields, DPIA thresholds, and data-flow reasoning          |
| Responsible AI | An AI or ML system is designed, evaluated, or experimented on                                                        | `rai-standards`, then `rai-planner` when a risk surfaces | Risk framing and standards mapping, plus a scoped assessment when a surfaced risk warrants one |
| Telemetry      | Signals, metrics, traces, or logs are emitted, named, or instrumented, including drift and pipeline health signals   | `telemetry-foundations`                                  | Metric names, instruments, units, cardinality limits, and PII-safe telemetry conventions       |

A cross-cutting concern always surfaces an observation and offers concrete
choices. It never blocks a durable write, never edits an artifact silently, and
never decides for the user. The durable-write scan gate remains the only
condition that blocks a write.

When a concern triggers, state which concern applies and why, name its owning
skill, offer the contribution that skill can make, and let the user choose
whether to take it. When the owning skill is unavailable in the installed
collection, say so and continue without improvising its authority.

## Skill authority boundaries

The Data Science and Engineering Coach routes to the data science and
engineering skills below, plus the cross-cutting skills above. Keep their
authority separate even when one job loads more than one skill.

| Exact skill name        | Capability description                                                                                                                    | Does not own                                                                                  |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `data-catalog`          | Durable catalog entities, declared relationships, identity, coverage, lineage, and attached dataset profiles                              | Pipeline tier behavior, inferred diagram relationships, or feasibility verdicts               |
| `dataops`               | DataOps tier semantics, pipeline invariants, validation, tests, drift, signals, and derived-dataset persistence                           | Catalog meaning, experiment selection, ML tracking setup, or sensitivity classification       |
| `feasibility`           | Evidence-led feasibility studies, lifecycle, recommendations, and interchange traceability                                                | Functional requirement numbering, downstream writeback, catalog semantics, or implementation  |
| `analysis-authoring`    | EDA notebook and analytical dashboard composition, visualization selection, and dashboard validation                                      | Column semantics, persistence format, accessibility conformance, or evaluation dataset design |
| `evaluation-design`     | AI-system evaluation dataset design, difficulty balance, metric selection, and tooling fit                                                | Trained-model evaluation, Responsible AI approval, or session and durable-write mechanics     |
| `experiment-design`     | Problem-class framing for a stated business outcome, plus experiment selection, hypotheses, vetting, minimum scope, and result evaluation | ML infrastructure, production implementation, or pipeline mechanics                           |
| `ml-experimentation`    | ML environments, reproducibility, tracking, abstractions, evaluation, and readiness                                                       | General hypothesis framing, pipeline replay, or Responsible AI approval                       |
| `privacy-standards`     | Sensitivity classification, data-flow reasoning, standards mapping, and DPIA thresholds                                                   | Catalog semantics, pipeline mechanics, or durable-write authority                             |
| `rai-standards`         | Responsible AI standards, risk framing, and standards mapping                                                                             | Evaluation dataset design, model performance, or approval authority                           |
| `rai-planner`           | Scoped Responsible AI assessment when a surfaced risk warrants one                                                                        | Data science method authority, session mechanics, or approval authority                       |
| `telemetry-foundations` | Metric names, instruments, units, cardinality, and PII-safe telemetry conventions                                                         | Signal selection intent, pipeline behavior, or drift interpretation                           |

The two Responsible AI authorities are sequential, not alternatives.
`rai-standards` provides risk framing and standards alignment and is evaluated
first whenever an AI or ML system is in scope. `rai-planner` provides a scoped
assessment of one surfaced risk and is reached only after that risk is
identified.

`problem-framing` and `experiment` both route to `experiment-design` and stay
distinct. `problem-framing` asks what kind of data-science problem a stated
business outcome is, and completes without choosing one. `experiment` assumes a
direction and selects what to test.

## Problem-framing completion evidence

This job has two completion shapes and neither is an abandonment.

* Normal completion records the candidate problem classes, the grounded-versus-
  original reasoning behind each, unresolved discriminating questions marked
  unknown, and gaps carrying an answer holder and a coordinator. No candidate is
  selected, ranked, or scored.
* An unstated business outcome completes with a single outcome-definition gap,
  its answer holder, its coordinator, and an explicit statement that no candidate
  analysis was performed. Record it as completed work, not `discarded-cleanly`.

Completion returns control to the coach. A feasibility or experiment job starts
only after a separate user-confirmed transition.

The two evaluation authorities are adjacent and must not be blended.
`evaluation-design` covers systems whose output is a response, such as
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

The RPI depth matrix is the only job-specific Research and execution-routing
authority. Every route remains subordinate to the active job's primary skill,
lifecycle class, coach state, transition protocol, and durable-write gate.

## Provenance

This registry is repository-original guidance licensed under CC BY 4.0. It
does not reproduce or summarize an external standard.
