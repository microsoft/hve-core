---
title: Jira Backlog Executor
description: Runs the Jira skill CLI in one confirmed project. Applies a dispatched Jira operation set and returns Jira reads the caller cannot perform.
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - jira-backlog-executor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/project-planning/subagents/jira-backlog-executor.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Runs the Jira skill CLI in one confirmed project. Applies a dispatched Jira operation set and returns Jira reads the caller cannot perform.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Backlog Manager dispatches this worker to execute confirmed Jira operations or obtain Jira reads unavailable to the parent. It uses the Jira skill CLI for the specified project and does not reselect the platform or destination. Its terminal usage is restricted by its operating policy, not a general-purpose shell workflow.

## Example usage

The parent supplies a confirmed project key, sanitized issue-update operations, autonomy and approval evidence, and logging references. The worker invokes the supported Jira CLI operations and returns structured issue results. It stops for missing configuration or unsupported actions rather than running another CLI, exposing credentials, or extending the operation set.
