---
title: planner-identity
description: "Shared identity scaffold for phase-based planning agents (SSSC, RAI, Security, Accessibility, Privacy): state-file convention, six-phase orchestration template, state protocol, resume protocol, question cadence, disclaimer cadence, and error handling. Activate at session start, before the planner applies its own identity rules."
sidebar_position: 3
author: Microsoft
ms.date: 2026-10-31
ms.topic: reference
keywords:
  - skill
  - shared
  - planner-identity
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                    |
|-------------|------------------------------------------|
| Kind        | skill                                    |
| Source      | `.github/skills/shared/planner-identity` |
| Invocation  | Loaded on demand by referencing agents   |
| Interactive | No                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Shared identity scaffold for phase-based planning agents (SSSC, RAI, Security, Accessibility, Privacy): state-file convention, six-phase orchestration template, state protocol, resume protocol, question cadence, disclaimer cadence, and error handling. Activate at session start, before the planner applies its own identity rules.
<!-- END AUTO-GENERATED: overview -->

## When to use it

The SSSC, RAI, Security, Accessibility, and Privacy planners activate this skill
at session start, before phase work. It supplies the shared state, phase,
cadence, disclaimer, and error mechanics. Each planner's own identity protocol
stays authoritative for its phases, schemas, gates, and handoffs to other
planners.

## Example usage

Say you started an RAI assessment in one chat and pick it up in a new one the
next day. Select the RAI Planner and ask it to continue the assessment for your
project. The planner activates this skill by name and follows its recovery
steps:

1. It reads `.copilot-tracking/rai-plans/<project>/state.json` for the project
   slug and current phase.
2. If `disclaimerShownAt` is `null`, it shows the RAI disclaimer again and
   records the time.
3. It reads the artifacts in the project folder and rebuilds context from them,
   since the earlier chat is not available.
4. It resumes with a short summary of the recovered state and the next task.

You know recovery worked when that summary names the phase recorded in
`state.json` and the next unfinished task in it.
