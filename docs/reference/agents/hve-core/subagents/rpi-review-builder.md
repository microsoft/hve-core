---
title: RPI Review Builder
description: Builds one complete RPI review record from a bounded planning and implementation evidence set. Use when rpi-review needs its canonical review document.
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-03
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-review-builder
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-review-builder.agent.md`          |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Builds one complete RPI review record from a bounded planning and implementation evidence set. Use when rpi-review needs its canonical review document.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Review Builder` is dispatched once by [rpi-review](../../../skills/rpi/rpi-review), not selected by a user. After the review parent initializes the record under `.copilot-tracking/reviews/logs/` and persists builder execution `started`, this worker compares the plan, critique, changes record, and validation evidence for the exact task boundary.

It writes the evidence body: acceptance coverage, one complete set of severity-graded `RV-xxx` findings, proposed execution status and outcome, and a proposed route for each finding.

It never edits `## Parent Decision Record`, asks the user a question, runs validation, changes source, or dispatches another worker. Its findings are advisory; the parent records the final outcome and every route. Any returned status (`Complete`, `Partial`, or `Blocked`) consumes the task's single builder invocation.

`rpi-review` selects this subagent because its name contains `review`; when it is unavailable, the skill uses an unnamed general-purpose subagent with the same write boundary, or stops Blocked if no subagent can be dispatched.

## Example usage

A representative parent dispatch:

```text
Task: blob-storage. Scope: full task. Depth: standard (default).
Review record (write only here, leave Parent Decision Record unchanged):
  .copilot-tracking/reviews/logs/2026-09-04/blob-storage-review.md
Evidence: plan, critique, changes record, and research at their dated paths; validation results from the changes record.
Acceptance basis: FR-001..FR-004, NFR-001..NFR-002, task Requirements blocks, confirmed decisions, PC-001 disposition.
Return: compact pointer summary; no user questions, routing decisions, or destination invocation.
```

The worker returns:

```text
* Builder execution: Complete
* Review depth and provenance: standard, default
* Review record: .copilot-tracking/reviews/logs/2026-09-04/blob-storage-review.md
* Proposed execution status and outcome: Complete; Defects found
* Findings: 1 Medium (RV-001 upload_stream retry contract undocumented), 1 Low (RV-002 retry count not configurable)
* Validation coverage: pytest passed; integration suite skipped with reason
* Proposed routes: RV-001 -> rpi-implement; RV-002 -> follow-up
* Parent decisions needed: accept or reroute RV-001 and RV-002
* Boundary confirmation: review record was the only written artifact
```
