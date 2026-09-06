---
title: RPI Researcher
description: "Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads."
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-researcher
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-researcher.agent.md`              |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Researcher` is dispatched by [rpi-research](../../../skills/rpi/rpi-research), not selected by a user. The parent delegates one bounded lane for one research cycle and wave (`Wider`, `Deeper`, or `Contrarian`) when isolating that investigation improves evidence quality, parallelism, or context control.

The worker investigates only that lane, writes its evidence progressively to the exact lane path the parent approved under `.copilot-tracking/research/subagents/`, and returns compact evidence relationships.

The parent keeps every decision: it assigns canonical `C#` and `W#` IDs, accepts or rejects material, records readiness, and talks to the user. The worker never edits the primary research artifact, source files, or configuration, and never speaks to the user.

`rpi-research` selects this subagent because its name contains `research`; when it is unavailable, the skill dispatches an unnamed general-purpose subagent with the same lane contract, or investigates inline and records the fallback.

## Example usage

A representative parent dispatch supplies the cycle, wave, lane, and paths:

```text
Cycle 1, wave Deeper, external lane.
Topic: azure-storage-blob async upload behavior for files over 1 GB.
Questions: Q2 chunk size and concurrency defaults; Q3 retry semantics on partial upload.
Criteria: current official documentation or SDK source with retrieval dates.
Posture: balanced. Limit: none.
Lane path: .copilot-tracking/research/subagents/2026-09-04/blob-async-upload-subagent-research.md
Primary artifact (do not edit): .copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The worker returns a pointer summary rather than the evidence body:

```text
* Execution status: Complete
* Cycle / wave: 1 / Deeper
* Evidence confidence: High
* Synthesis readiness: Ready
* Evidence artifact: .copilot-tracking/research/subagents/2026-09-04/blob-async-upload-subagent-research.md
* Evidence relationships: Q2 -> upload_blob chunks at max_block_size with max_concurrency workers (SDK reference, retrieved 2026-09-04) supports; Q3 -> partial uploads are not retried by default (SDK source) weakens the earlier claim
* Missing evidence or clarification: None
* Stop reason: lane criteria met
```
