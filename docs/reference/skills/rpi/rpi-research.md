---
title: rpi-research
description: "Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first."
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-research
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/rpi/rpi-research`                                              |
| Invocation  | Invoked directly as `/rpi-research`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-research` when a task needs evidence before anyone plans or edits: a codebase pattern is unknown, an external API, library, or standard must be verified, alternatives need comparison, or a decision-critical question is open. Research is read-only. It writes one dated primary artifact under `.copilot-tracking/research/` and, when it delegates a lane, one evidence file per lane under `.copilot-tracking/research/subagents/`.

Each executed cycle runs Wider, Deeper, and Contrarian waves, then synthesizes findings, records Planning Readiness, and resolves material decisions according to the participation mode: `user-owned` when invoked directly, `agent-owned` or `user-retained` inside an automatic [RPI Agent](../../agents/hve-core/rpi-agent) session.

The research posture (`expansive`, `balanced`, or `focused`) controls how far it goes, and the output mode (`convergence`, `analysis`, `audit`, `comparison`, `research-only`, or `no-handoff`) controls whether a planning handoff is offered.

Reach for a different asset when:

* Evidence is already adequate. Start [rpi-plan](rpi-plan), which activates research only for a demonstrated gap.
* You want to understand existing code or an artifact rather than gather new evidence. Use [rpi-walkthrough](rpi-walkthrough).
* You want to test the assumptions behind a decision. Use [rpi-challenger](rpi-challenger).

## Example usage

Invoke the skill with a topic. Add `chat` to let it refine scope from the current conversation.

```text
/rpi-research topic="Streaming uploads to Azure Blob Storage from the Python pipeline"
```

The skill sends one opening update with its interpreted goal, posture, starting areas, and boundaries, then researches and updates the artifact as evidence arrives. The final response separates execution status from readiness:

```text
## rpi-research: Azure Blob Storage streaming uploads

* Research execution: Complete; disposition `executed`
* Output mode: convergence; Planning Readiness: Ready (C1-C4, W1-W3)
* Recommendation: azure-storage-blob async client behind the existing WriterBase contract
* Rejected alternative: synchronous SDK client (blocks the pipeline event loop, W2)
* Unresolved decisions: none

| Artifact                                                                                                                         | Description               |
|----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [.copilot-tracking/research/2026-09-04/blob-storage-research.md](.copilot-tracking/research/2026-09-04/blob-storage-research.md) | Primary research artifact |

## Next Steps

Run `/rpi-plan` with this research artifact.
```

When readiness is `Not ready` or the output mode does not support planning, the response states the no-handoff reason instead of advising a command.
