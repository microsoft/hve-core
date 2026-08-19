---
title: data-workstream-foundation
description: "State, resume, reconstruction, job-lifecycle, transition, and flow-state mechanics for the Data Workstream Coach. Loaded by the coach; not a user entry point."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-14
ms.topic: reference
keywords:
  - skill
  - data-science
  - data-workstream-foundation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | skill                                                    |
| Source      | `.github/skills/data-science/data-workstream-foundation` |
| Invocation  | Loaded on demand by referencing agents                   |
| Interactive | No                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
State, resume, reconstruction, job-lifecycle, transition, and flow-state mechanics for the Data Workstream Coach. Loaded by the coach; not a user entry point.
<!-- END AUTO-GENERATED: overview -->

## When to use it

This internal skill is loaded by Data Workstream Coach at initialization and
resume. Its references govern job selection, lifecycle classes, confirmed
transitions, YAML-in-Markdown session state, artifact-based reconstruction,
and flow-preserving interruption gates.

Do not invoke it as a standalone data-science workflow. Load `ds-catalog`,
`ds-dataops`, `ds-feasibility`, `experiment-design`, or `ml-experimentation`
for job-specific methods and outputs.

## Example usage

A coach resuming a project reads the session-state reference, validates project
identity, restores a paused feasibility phase and active catalog context, then
announces both before asking what to do next. If state is corrupt, the same
reference requires an evidence summary and user confirmation before the state
file is replaced or job work resumes.
