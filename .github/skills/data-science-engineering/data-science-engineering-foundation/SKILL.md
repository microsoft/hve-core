---
name: data-science-engineering-foundation
description: "State, resume, reconstruction, job-lifecycle, transition, and flow-state mechanics for the Data Science and Engineering Coach. Loaded by the coach; not a user entry point."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-03"
---

# Data Science and Engineering Foundation

## Goal

Keep Data Science and Engineering Coach orchestration consistent across job changes and
sessions without duplicating job-specific guidance. The coach loads this index
at initialization and resume, then reads the reference for the current
coaching moment.

## Reference index

| Reference                                                   | When to read                                                                                        |
|-------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| [job-registry.md](references/job-registry.md)               | Before offering or selecting a job, routing to a skill or specialist, or naming a durable output    |
| [lifecycle-classes.md](references/lifecycle-classes.md)     | When starting, pausing, resuming, completing, or re-invoking a job                                  |
| [transition-protocol.md](references/transition-protocol.md) | When a topic shift, explicit request, or completion suggests moving between jobs                    |
| [session-state.md](references/session-state.md)             | Before initialization, validation, mutation, resume, recovery, or reconstruction of coaching state  |
| [flow-state.md](references/flow-state.md)                   | Before interrupting work, crossing a gate, writing a durable artifact, or offering post-job choices |

## Success criteria

* Each orchestration rule has one owner in this package.
* State and lifecycle mechanics remain independent of job-specific methods.
* The coach reads the applicable reference before acting on its contract.

## Constraints

* Keep catalog guidance in `data-catalog`, the durable data-catalog workflow for
  entities, declared relationships, lineage, and ERD-ready model semantics.
* Keep feasibility guidance in `feasibility`, the evidence-led data and ML
  feasibility-study workflow with lifecycle and interchange traceability.
* Keep pipeline and testing guidance in `dataops`, the DataOps reference for
  tier behavior, pipeline invariants, validation placement, tests, drift, and
  operational signals.
* Keep general experiment guidance in `experiment-design`, the reusable
  workflow for candidate selection, hypotheses, vetting, minimum scope, and
  result evaluation.
* Keep ML-specific experiment guidance in `ml-experimentation`, the reference
  for ML environments, reproducibility, tracking, evaluation, abstractions,
  and production readiness.
* Keep notebook and dashboard guidance in `analysis-authoring`, the
  reference for EDA notebook and analytical dashboard composition,
  visualization selection, and dashboard validation.
* Keep AI-system evaluation guidance in `evaluation-design`, the reference
  for evaluation dataset design, difficulty balance, metric selection, and
  tooling fit.
* Treat this package as internal foundation knowledge, not a user-selectable
  workflow.
* Preserve the skill authority boundaries and cross-cutting concerns defined in
  the job registry.

## Stop rules

* Stop before a state mutation when the session-state protocol has not been
  loaded or project identity is uncertain.
* Stop before a job switch when the user has not confirmed the transition.
* Stop and report the missing owner when requested behavior belongs to neither
  this foundation nor a registered job capability.

## Attribution

This package is repository-original orchestration guidance licensed under
CC BY 4.0. It does not reproduce or summarize an external standard.
