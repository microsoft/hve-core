---
title: RAI Planner
description: "Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - rai-planning
  - rai-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                |
|-------------|------------------------------------------------------|
| Kind        | agent                                                |
| Source      | `.github/agents/rai-planning/rai-planner.agent.md`   |
| Invocation  | Selected from the chat agent picker as `RAI Planner` |
| Interactive | Yes                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use RAI Planner to scope an AI system's intended use, affected people, risk classification, controls, and impact assessment. It supports capture from conversation, a PRD, or a security plan. Use RAI Reviewer to assess existing evidence rather than build a plan through guided discovery.

## How to use it

1. Select `RAI Planner` and provide the system purpose, users, model interactions, data flows, and available requirements.
2. Review the disclaimer and confirm scope and risk decisions through the six planning phases.
3. Examine standards mappings, the RAI security model, control surfaces, and impact evidence. Supply missing facts rather than treating assumptions as assessed controls.
4. Review the final assessment and backlog handoff with qualified professionals. Planning evidence does not certify legal compliance or eliminate the need for human acceptance.

## Example usage

Ask: "Plan responsible-AI controls for an internal document assistant from `requirements/assistant.md`. Identify affected users, model failure modes, oversight boundaries, and evidence gaps before drafting a backlog."

Expect a scoped risk assessment, control catalog, impact analysis, and reviewable handoff. Success means claims about mitigation are distinguished from proposed controls and untested assumptions.
