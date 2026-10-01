---
title: ADO Backlog Executor
description: "Applies a dispatched Azure DevOps backlog operation set in one confirmed project. Creates, updates, links, comments on, and transitions work items."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - ado-backlog-executor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/project-planning/subagents/ado-backlog-executor.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Applies a dispatched Azure DevOps backlog operation set in one confirmed project. Creates, updates, links, comments on, and transitions work items.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Backlog Manager dispatches this worker to apply one sanitized operation set in a confirmed Azure DevOps project. The parent owns platform resolution, destination confirmation, and autonomy choices. Use Backlog Manager rather than selecting this worker directly; it cannot redirect work to another tracker.

## Example usage

After review, the parent supplies the organization and project, ordered work-item operations, relationships, tracking references, and granted confirmations. The executor applies only those operations and returns structured results with work-item identifiers and unresolved actions. Missing destination or approval evidence stops the affected operation; the worker does not broaden the batch or autonomy tier.
