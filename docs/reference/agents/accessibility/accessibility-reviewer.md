---
title: Accessibility Reviewer
description: Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - accessibility
  - accessibility-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                           |
|-------------|-----------------------------------------------------------------|
| Kind        | agent                                                           |
| Source      | `.github/agents/accessibility/accessibility-reviewer.agent.md`  |
| Invocation  | Selected from the chat agent picker as `Accessibility Reviewer` |
| Interactive | Yes                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Accessibility Reviewer for an accessibility audit, a changed-surface review, or an assessment of a proposed plan. It coordinates framework assessments and evidence verification. Use Accessibility Planner first when audiences, regulatory drivers, or target surfaces still need discovery.

## How to use it

1. Select `Accessibility Reviewer` and provide the mode (`audit`, `diff`, or `plan`), target paths, and any prior report or plan.
2. Specify a framework or assessment tier when needed; otherwise the reviewer profiles the codebase and defaults to the standard tier.
3. Review the consolidated findings, scanned-artifact inventory, exclusions, and evidence limitations. Audit and diff findings may need runtime probes or a manual assistive-technology pass; plan mode does not perform runtime verification.
4. Arrange qualified human review of unresolved findings. Missing browser or screen-reader evidence is not a passing result.

## Example usage

Ask: "Review the changed booking form in `src/booking` against WCAG 2.2 at the standard assessment tier. Include keyboard traversal, error announcements, and the expanded date picker. Identify any checks that require manual assistive-technology testing."

Expect a report that separates assessed findings, blocking or advisory dispositions, and unavailable verification. Success means findings name the affected interaction state and supporting evidence rather than assuming static markup proves runtime behavior.
