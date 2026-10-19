---
title: rpi-research
description: "Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/ or a caller's trusted evidence root, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first."
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-26
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
Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/ or a caller's trusted evidence root, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-research` when a task needs evidence before anyone plans or edits: a codebase pattern is unknown, an external API, library, or standard must be verified, alternatives need comparison, or a decision-critical question is open. Research is read-only. It writes one dated primary artifact under `.copilot-tracking/research/`, and that artifact is the only research artifact.

A helper such as [RPI Researcher](../../agents/hve-core/subagents/rpi-researcher) may be asked for source pointers when isolating a gathering task helps; its return is a suggestion the research verifies at the source.

Each executed cycle runs Wider, Deeper, and Contrarian waves, then synthesizes findings, records Planning Readiness, and resolves material decisions according to the participation mode: `user-owned` when invoked directly, `agent-owned` or `user-retained` inside an automatic [RPI Agent](../../agents/hve-core/rpi-agent) session.

The research posture controls how far it goes: `balanced` by default, `focused` to stay within the named targets, or `expansive` for a broad or materially unknown decision space. Pass `posture=` to change it. The output mode (`convergence`, `analysis`, `audit`, `comparison`, `research-only`, or `no-handoff`) controls whether a planning handoff is offered.

Reach for a different asset when:

* Evidence is already adequate. Start [rpi-plan](rpi-plan), which activates research only for a demonstrated gap.
* You want to understand existing code or an artifact rather than gather new evidence. Use [rpi-walkthrough](rpi-walkthrough).
* You want to test the assumptions behind a decision. Use [rpi-challenger](rpi-challenger).

## Example usage

Invoke the skill with a topic. Add `chat` to let it refine scope from the current conversation, and `posture=focused` or `posture=expansive` to change the default `balanced` depth.

```text
/rpi-research topic="Streaming uploads to Azure Blob Storage from the Python pipeline"
```

The skill sends one opening update with its interpreted goal, posture, starting areas, and boundaries, then researches and updates the artifact as evidence arrives. The final response leads with the result in plain language, which for a topic like this one is the bottom line, then gives the evidence and next step:

```text
## rpi-research: Azure Blob Storage streaming uploads

Research is complete. Use the azure-storage-blob async client behind the existing WriterBase contract: it streams uploads without blocking the pipeline event loop, and the synchronous client would block it (W2). Nothing is waiting on a decision from you, so planning can start now.

| Artifact                                                                                                                         | Description               |
|----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [.copilot-tracking/research/2026-09-04/blob-storage-research.md](.copilot-tracking/research/2026-09-04/blob-storage-research.md) | Primary research artifact |

## Next Steps

Run `/rpi-plan` with this research artifact.
```

When the research cannot support planning, the response says why in plain language instead of advising a command.
