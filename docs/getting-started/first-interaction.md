---
title: Your First Interaction
description: Talk to an HVE Core agent and see it respond in under 60 seconds
sidebar_position: 4
author: Microsoft
ms.date: 2026-07-16
ms.topic: tutorial
keywords:
  - getting started
  - first interaction
   - rpi agent
  - github copilot
estimated_reading_time: 2
---

> [!NOTE]
> Step 1 of 4 in the [Getting Started Journey](./).

Before diving into workflows and methodologies, confirm that everything works.
You need one agent interaction that produces a visible result.

## Talk to RPI Agent

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`).
2. Select **RPI Agent** from the agent picker.
3. Type this prompt:

   > I am learning HVE Core. Explain when I should use the complete RPI
   > lifecycle and when one phase skill is enough. Do not start a task yet.

4. The agent explains the coordinated lifecycle and the direct
   `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` entry
   points.

You just confirmed that HVE Core is installed, custom agents are available,
and natural-language requests reach the intended workflow owner.

## How Workflow Context Persists

HVE Core workflows produce durable artifacts when work needs to span phases
or sessions. RPI uses research, plan, phase-detail, change, and review records.
Backlog, planning, and documentation workflows use their own state and handoff
files. Resume from those workflow-owned artifacts instead of relying on a
generic conversation-memory or checkpoint command.

This artifact-first pattern keeps important context reviewable and lets a new
chat continue from recorded evidence rather than reconstructed chat history.

## Next Step

Now that you know agents work, try using one for real work:
[Your First Research](first-research.md).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
