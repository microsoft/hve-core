---
title: functional-planner
description: "Read-only PRD-to-work-item hierarchy planning. Use to turn a PRD into a validated Azure DevOps, GitHub, or Jira handoff."
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - functional-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/project-planning/functional-planner`                                 |
| Invocation  | Invoked directly as `/functional-planner`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only PRD-to-work-item hierarchy planning. Use to turn a PRD into a validated Azure DevOps, GitHub, or Jira handoff.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a concrete PRD needs decomposition into a reviewable work-item
hierarchy for Azure DevOps, GitHub, or Jira. It validates proposed types, fields,
and relationships through read-only discovery and compares candidates with
existing work. It does not author missing requirements or create tracker items.

Choose the generic, Scrum, or Kanban lens to shape decomposition; the platform's
validated capabilities still govern actual types and parent relationships. Use
`backlog-plan` for general discovery or triage, and Backlog Manager for a separate
reviewed execution pass.

## Example usage

Ask: `/functional-planner Use the attached sample order-service PRD, platform=github,
lens=generic, targeting example-org/sample-service. Produce a hierarchy and handoff
only.` Replace the repository with your intended destination and provide the
actual PRD rather than relying on an unrelated open file.

The skill should analyze requirements, inspect relevant code context, discover
related issues, refine the hierarchy, and produce the plan plus `handoff.md`.
Success means every requirement maps to a planned item or an explicit gap, and
unconfirmed fields or relationships are marked `needs_review` rather than guessed.

For a flow-oriented team, select `lens=kanban` to emphasize right-sizing; it cannot
override supported tracker relationships. Missing PRD evidence or unavailable
dependencies stop the affected step. No issue is created, linked, or commented on
until a separate execution pass follows human review.
