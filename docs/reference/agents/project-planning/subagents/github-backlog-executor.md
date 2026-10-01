---
title: GitHub Backlog Executor
description: "Applies a dispatched GitHub backlog operation set in one confirmed repository. Creates, updates, comments on, and closes issues and sub-issues."
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - github-backlog-executor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | agent                                                                        |
| Source      | `.github/agents/project-planning/subagents/github-backlog-executor.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)     |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Applies a dispatched GitHub backlog operation set in one confirmed repository. Creates, updates, comments on, and closes issues and sub-issues.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Backlog Manager dispatches this worker for approved issue operations in one confirmed GitHub repository. The parent supplies sanitized content, destination, autonomy tier, and any freshness preconditions. This is an execution worker, not a direct user entry point or a platform-selection agent.

## Example usage

The parent supplies a reviewed set of issue updates, exact owner and repository, validated labels, and approval context. The executor performs the bounded operations and returns issue links, results, and remaining failures. It honors operation freshness and community-facing explanation requirements, never switching trackers or treating an unapproved follow-up as part of the batch.
