---
title: Accessibility Planner
description: "Phase-based accessibility planner that guides users through structured planning for WCAG 2.2, ARIA APG, Cognitive Accessibility, Section 508, and EN 301 549, producing framework selections, control mappings, evidence-register entries, plan-risk classifications, and dual-format backlog handoff."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - accessibility
  - accessibility-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| Kind        | agent                                                          |
| Source      | `.github/agents/accessibility/accessibility-planner.agent.md`  |
| Invocation  | Selected from the chat agent picker as `Accessibility Planner` |
| Interactive | Yes                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Phase-based accessibility planner that guides users through structured planning for WCAG 2.2, ARIA APG, Cognitive Accessibility, Section 508, and EN 301 549, producing framework selections, control mappings, evidence-register entries, plan-risk classifications, and dual-format backlog handoff.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Accessibility Planner to scope accessibility work for a new product or an existing requirements document. It connects audiences and interaction surfaces to selected frameworks, evidence gaps, controls, and backlog handoff. Choose Accessibility Reviewer when you need findings about an implementation rather than a guided planning session.

## How to use it

1. Select `Accessibility Planner` from the chat agent picker and describe the project, affected audiences, and surfaces. Supply a PRD, BRD, security plan, or RAI plan if available.
2. Review the planning disclaimer and answer the focused discovery questions. Confirm framework selections and conformance targets instead of treating defaults as a compliance conclusion.
3. Confirm each phase transition as the planner maps standards, assesses risk, and records evidence and tradeoffs.
4. Review the resulting controls and backlog drafts with a qualified reviewer before external submission. The planner does not modify application code or certify conformance.

## Example usage

Ask: "Plan accessibility for our appointment portal from `requirements/portal.md`. Include booking, validation errors, and mobile layouts. Help us choose frameworks and identify evidence we still need; do not change application code or submit work items."

Expect a confirmed surface inventory, framework mappings, risk and evidence records, and reviewable backlog drafts. Success means exclusions and untested interactions are visible alongside the planned controls, not that an automated assessment proves compliance.
