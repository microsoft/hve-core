---
title: ADR Creator
description: "ADR Creator: phase-gated creator producing standards-aligned Architecture Decision Records with state recovery, rpi-research activation, and backlog handoff"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - adr-creation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | agent                                                   |
| Source      | `.github/agents/project-planning/adr-creation.agent.md` |
| Invocation  | Selected from the chat agent picker as `ADR Creator`    |
| Interactive | Yes                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
ADR Creator: phase-gated creator producing standards-aligned Architecture Decision Records with state recovery, rpi-research activation, and backlog handoff
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use ADR Creator to capture an architectural decision and its rationale, turn a planner handoff into an ADR, or adopt an organization-specific template. Choose System Architecture Reviewer when you first need a broader evaluation of the design and its tradeoffs.

## How to use it

1. Select `ADR Creator` and describe the decision, alternatives, constraints, and existing evidence.
2. Choose the entry mode and output form separately: capture or planner handoff with MADR or Y-Statement output, or template adoption with your supplied template.
3. Confirm framing, diagram format, decision drivers, and the selected option as the agent progresses through the phase gates.
4. Review consequences and the Govern-phase handoff. Choose the autonomy tier there; drafting an ADR does not itself authorize every downstream external action.

## Example usage

Ask: "Capture an ADR for synchronous versus queued report generation using `design/reporting-options.md`. Use MADR and Mermaid, record the evidence gaps, and keep external handoffs manual."

Expect a decision record with alternatives, drivers, consequences, and a reviewable handoff. Success means the chosen approach is traceable to confirmed constraints rather than an unsupported architectural preference.
