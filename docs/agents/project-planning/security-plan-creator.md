---
title: Security Planner (Moved)
description: This page has moved to the Security Planning documentation
sidebar_position: 5
author: Microsoft
ms.date: 2026-06-29
ms.topic: tutorial
---

This page has moved. The former Security Plan Creator agent is now the **Security Planner**, documented under the Security agents section.

> [!IMPORTANT]
> The Security Planner uses a six-phase conversational workflow and a seven-bucket operational analysis overlay. It stores state under `.copilot-tracking/security-plans/{project-slug}/` and recommends an RAI Planner follow-up when AI/ML components are detected.

## Where to Go

* [Security Planning](../security/README.md): Overview, six-phase workflow, operational buckets, and invocation details.
* [Entry Modes](../security/entry-modes): From-PRD and capture entry modes.
* [Phase Reference](../security/phase-reference): Phase-by-phase inputs, outputs, and state transitions.
* [Handoff Pipeline](../security/handoff-pipeline): Backlog generation and RAI Planner recommendation.

## Next Steps

1. Feed security findings into an [ADR](adr-creation) to document security architecture decisions
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Run the Security Planner after completing your [BRD or PRD](brd-prd-builders) to align threat analysis with documented requirements and system boundaries.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
