---
title: RPI Planner
description: Revise one assigned phase within an RPI implementation plan. Use when a parent needs bounded phase authoring during planning.
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-planner.agent.md`                 |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Revise one assigned phase within an RPI implementation plan. Use when a parent needs bounded phase authoring during planning.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Planner` is dispatched by [rpi-plan](../../../skills/rpi/rpi-plan), not selected by a user. Under `delegation=adaptive` the planner uses it for phases large and independent enough to benefit from isolated context; under `delegation=always` every phase is assigned this way; under `delegation=never` it is not used. The worker revises exactly one assigned `Pxx` phase in the shared plan and preserves every other phase.

It fills the phase's `Goals:` and `Dependencies:` blocks and each task's `Goals:`, `Requirements:`, `Details:`, `References:`, and `Dependencies:` blocks from supplied evidence. It does not research beyond that evidence, edit source, critique the plan, or add status blocks; decision gaps and risks return to the parent, which owns the plan's decision and risk tables and the Phase Checklist diagrams.

## Example usage

A representative parent dispatch:

```text
Plan: .copilot-tracking/plans/2026-09-04/blob-storage-plan.md
Assigned phase: P02 (Writer implementation). Write boundary: the P02 section only.
Overall outline: P01 storage client, P02 writer, P03 factory integration.
Requirements: FR-002, FR-003, NFR-002. Confirmed direction: extend WriterBase; no new base class.
Evidence: research Q1 and Q3 under ## Findings; src/pipeline/writers/base.py.
Return: phase status, files changed, local choices, assumptions or questions, boundary confirmation.
```

The worker returns a structured summary:

```text
* Phase status: Complete
* Assigned phase: P02
* Files changed: .copilot-tracking/plans/2026-09-04/blob-storage-plan.md
* Local choices resolved: P02-T01 reuses the queue integration's async client pattern (research Q3)
* Assumptions or questions: the retry ceiling for NFR-002 is not stated in the evidence; recorded as an assumption in P02-T02 Details for the parent to confirm
* Boundary confirmation: P01 and P03 unchanged
```
