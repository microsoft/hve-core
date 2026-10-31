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

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
