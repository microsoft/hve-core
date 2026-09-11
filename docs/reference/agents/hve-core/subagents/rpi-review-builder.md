---
title: RPI Review Builder
description: "Compares supplied RPI plan, changes, and validation evidence for one task boundary and returns candidate findings with evidence locations and suggested routes for the review parent to verify. Use during review when isolating the evidence comparison would help."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-11
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
Compares supplied RPI plan, changes, and validation evidence for one task boundary and returns candidate findings with evidence locations and suggested routes for the review parent to verify. Use during review when isolating the evidence comparison would help.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Review Builder` is an optional helper that [rpi-review](../../../skills/rpi/rpi-review) may use, not a required step and not something a user selects. The review parent compares the evidence and writes the record itself; it asks this helper for candidate findings only when isolating the comparison for a large boundary, or gathering the exact evidence locations to read, would help.

The helper compares the plan, changes record, critique dispositions, and validation evidence for the stated task boundary and returns candidate findings: the related marker or requirement, expected behavior, observed evidence with its location, why it may matter, and a suggested severity and route. It also returns coverage notes and the boundaries it could not assess.

The review parent reads each cited location, records an `RV-xxx` finding only when it confirms the candidate, and decides execution status, outcome, and every route in `## Parent Decision Record`. The helper writes no file, runs no validation, and never speaks to the user.

## Example usage

A representative dispatch:

```text
Task: blob-storage. Scope: full task. Depth: standard (default).
Plan, critique, changes record, and research at their dated .copilot-tracking paths.
Acceptance basis: FR-001..FR-004, NFR-001..NFR-002, task Requirements blocks, confirmed decisions, PC-001 disposition.
Return: candidate findings with evidence locations; no RV IDs, no outcome, no record writes.
```

The helper returns candidates for the parent to verify:

```text
* Status: Complete
* Scope compared: blob-storage, full task, standard
* Candidate findings:
  * P02-T01 / FR-003: expected a documented retry contract on upload_stream; observed the changes record cites tests but src/storage/blob_client.py has no docstring on upload_stream; may leave callers unaware partial uploads retry; suggested Medium, rpi-implement, confidence High
  * NFR-002: expected a configurable retry count; observed a constant in blob_client.py; suggested Low, follow-up, confidence Medium
* Coverage notes: FR-001, FR-002, FR-004, PC-001 disposition, and P01 markers consistent with the changes record
* Not assessed: integration suite result (skipped in the changes record)
* Validation evidence seen: pytest passed; integration suite skipped with reason
* Verify before recording: upload_stream in src/storage/blob_client.py; "Add retry tests" heading in the changes record
```
