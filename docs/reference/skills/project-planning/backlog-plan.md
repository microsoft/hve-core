---
title: backlog-plan
description: "Read-only backlog planning for Azure DevOps, GitHub, and Jira. Use to discover, triage, sprint-plan, or resume without mutating a tracker."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - backlog-plan
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/project-planning/backlog-plan`                                 |
| Invocation  | Invoked directly as `/backlog-plan`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only backlog planning for Azure DevOps, GitHub, and Jira. Use to discover, triage, sprint-plan, or resume without mutating a tracker.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to discover candidate work, retrieve assigned items, prepare an
implementation handoff, triage issues, plan a delivery window, or resume planning.
It reads one resolved tracker and writes local planning artifacts, but never
creates, updates, comments on, or closes tracker items.

Choose `functional-planner` for PRD-to-hierarchy conversion and `backlog-execute`
for approved tracker changes. Read access and the shared `backlog-management`
contract must be available; failure does not justify choosing another tracker.

## Example usage

Ask: `/backlog-plan triage open documentation issues in example-org/sample-service
on GitHub; recommend priorities and duplicates without changing anything.` Use
your actual authorized repository in place of the example. Expect hydrated issue
evidence, similarity assessments, a planning log, and a handoff of proposed actions.
Success means recommendations are tied to acceptance criteria and ambiguous
duplicates remain questions for human review.

For a delivery window, use `sprint` with its milestone or iteration and supplied
capacity to get coverage, dependency, and gap analysis rather than item mutations.
Use `my-work` to retrieve assigned items, then `task-plan` to enrich selected work
for implementation. `resume` reads durable planning records and proposes the next
step; missing logs or unresolved identifiers are blockers, not permission to
recreate work. Applying any proposed changes requires a separate execution pass.
