---
title: Privacy Planner
description: "Phase-based privacy planner producing data maps, DPIA assessments, controls, and backlog handoffs for processing activities"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - privacy
  - privacy-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | agent                                                    |
| Source      | `.github/agents/privacy/privacy-planner.agent.md`        |
| Invocation  | Selected from the chat agent picker as `Privacy Planner` |
| Interactive | Yes                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Phase-based privacy planner producing data maps, DPIA assessments, controls, and backlog handoffs for processing activities
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Privacy Planner when a new or changing processing activity needs a data inventory, lifecycle mapping, DPIA threshold assessment, and control plan. Start from conversation or a PRD. Use Privacy Reviewer to assess an existing plan for gaps rather than build it through discovery.

## How to use it

1. Select `Privacy Planner` and describe the processing purpose, data subjects, data categories, jurisdictions, and existing requirements.
2. Review the disclaimer and clarify the data flows through capture, mapping, risk and DPIA, controls, impact, and handoff phases.
3. Confirm the phase decisions and supply missing evidence when requested. Unresolved jurisdictional or legal questions are researched or explicitly blocked, not guessed.
4. Have qualified reviewers assess the resulting privacy plan and backlog handoff before using them as implementation or compliance guidance.

## Example usage

Ask: "Plan privacy for a support portal described in `requirements/support.md`. Map collection, retention, deletion, and third-party processing. Record unknowns and evaluate whether a DPIA is needed using the jurisdictions we confirm."

Expect a data map, documented risk and DPIA decisions, proposed controls, and prioritized handoff actions. Success means each decision is tied to known processing facts and unresolved obligations remain visible for professional review.
