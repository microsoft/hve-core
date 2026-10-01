---
title: Accessibility Framework Assessor
description: Assesses accessibility framework scopes through the consolidated Accessibility skill and returns structured findings
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - accessibility
  - accessibility-framework-assessor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                              |
|-------------|------------------------------------------------------------------------------------|
| Kind        | agent                                                                              |
| Source      | `.github/agents/accessibility/subagents/accessibility-framework-assessor.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)           |
| Interactive | No                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assesses accessibility framework scopes through the consolidated Accessibility skill and returns structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Accessibility Reviewer dispatches this worker for one accessibility framework or reference scope. It reads the relevant criteria and assesses the codebase or plan with mode-appropriate statuses. Users select the parent reviewer; this worker does not independently expand the assessment or certify conformance.

## Example usage

The parent supplies a WCAG framework scope, codebase profile, `diff` mode, and changed booking-form files. The assessor returns `SKILL_FINDINGS_V1` with criterion-level evidence and coverage. For a supplied plan it returns `PLAN_FINDINGS_V1` instead, keeping proposed risk coverage separate from implemented behavior. Missing evidence remains unassessed or qualified for downstream verification.
