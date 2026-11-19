---
title: ado-backlog
description: "Plan and apply Azure Boards backlog operations in one Azure DevOps project. Use for work-item discovery, triage, iterations, PRD hierarchies, and reviewed handoffs."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - azure-devops
  - ado-backlog
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/plugins/sdlc-azure-devops/skills/azure-devops/ado-backlog`           |
| Invocation  | Invoked directly as `/ado-backlog`, or loaded on demand by referencing agents |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Plan and apply Azure Boards backlog operations in one Azure DevOps project. Use for work-item discovery, triage, iterations, PRD hierarchies, and reviewed handoffs.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Invoke `/ado-backlog` when inspecting, planning, triaging, or applying work-item
operations in a single Azure DevOps project. It routes read-only planning to
`backlog-plan`, PRD decomposition to `functional-planner` with Azure Boards
hierarchy rules, and authorized writes to `backlog-execute` under
`backlog-management` controls. Use `ado-pull-request` for Azure Repos pull
requests, `ado-build-info` for Azure Pipelines builds, or `github-backlog` and
`jira` for other trackers.

## Example usage

Run `/ado-backlog discover MyProject "state = Active AND tag contains telemetry"`
to search Azure Boards work items without modifying the tracker.

The skill runs Azure Boards preflight against `MyProject`, queries matching work
items using the platform bindings, and returns the matching IDs, titles, states,
and iteration paths. To apply a reviewed handoff after approval, run
`/ado-backlog run MyProject .copilot-tracking/workitems/handoff.md` and confirm
the reported created or updated work-item IDs.
