---
title: data-science-engineering-foundation
description: "State, resume, reconstruction, job-lifecycle, transition, and flow-state mechanics for the Data Science and Engineering Coach. Loaded by the coach; not a user entry point."
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - data-science-engineering-foundation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/skills/data-science-engineering/data-science-engineering-foundation` |
| Invocation  | Loaded on demand by referencing agents                                        |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
State, resume, reconstruction, job-lifecycle, transition, and flow-state mechanics for the Data Science and Engineering Coach. Loaded by the coach; not a user entry point.
<!-- END AUTO-GENERATED: overview -->

## When to use it

This internal skill is loaded by Data Science and Engineering Coach at initialization and
resume. Its references govern job selection, lifecycle classes, confirmed
transitions, YAML-in-Markdown session state, artifact-based reconstruction,
and flow-preserving interruption gates.

Do not invoke it as a standalone data science and engineering workflow. Load `data-catalog`,
`dataops`, `feasibility`, `experiment-design`, or `ml-experimentation`
for job-specific methods and outputs.

## RPI depth matrix

RPI is a user-directed depth route inside the confirmed job, not a job or lifecycle. Keep simple or adequately evidenced work on the primary route. No RPI segment auto-activates. Before each eligible segment, state the demonstrated need, purpose, expected artifact, expected interaction cost, limits, and direct path available if the user skips it.

Substantial delivery means multi-step code or artifact production whose dependencies, validation, or interruption risk make direct episodic execution unreliable. The owning skill first accepts the domain design. RPI then plans and executes delivery and reviews conformance without changing the job, class, owning skill, coach state authority, output root, or durable-write gate.

## Execution-loop eligibility

For jobs such as `pipeline`, `analysis`, `evaluation`, `testing`, and `observability`, the RPI depth matrix allows a full Plan, Implement, and Review loop for substantial delivery. For `problem-framing` and `feasibility`, it allows bounded rpi-research for current-fact evidence gaps. This execution loop does not select jobs, change lifecycle class, replace the owning skill, close the session, or write customer artifacts directly.

## Example usage

A coach resuming a project reads the session-state reference, validates project
identity, restores a paused feasibility phase and active catalog context, then
announces both before asking what to do next. If state is corrupt, the same
reference requires an evidence summary and user confirmation before the state
file is replaced or job work resumes.
