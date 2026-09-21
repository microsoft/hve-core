---
title: Backlog Manager
description: "Read-only backlog orchestrator for Azure DevOps, GitHub, and Jira. Classifies, plans, and grooms requests, and dispatches every mutation to a per-platform executor."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-18
ms.topic: reference
keywords:
  - agent
  - project-planning
  - backlog-manager
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                      |
|-------------|------------------------------------------------------------|
| Kind        | agent                                                      |
| Source      | `.github/agents/project-planning/backlog-manager.agent.md` |
| Invocation  | Selected from the chat agent picker as `Backlog Manager`   |
| Interactive | Yes                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only backlog orchestrator for Azure DevOps, GitHub, and Jira. Classifies, plans, and grooms requests, and dispatches every mutation to a per-platform executor.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Backlog Manager to discover, triage, groom, or plan work in a confirmed Azure DevOps, GitHub, or Jira destination, or to coordinate execution of a reviewed handoff. It stays read-only with respect to trackers and dispatches mutations to one platform-specific executor. Use Functional Planner for PRD-to-hierarchy planning.

## How to use it

1. Select `Backlog Manager` and identify the platform, destination, and requested workflow.
2. Supply the issue scope, requirements brief, or reviewed handoff. Resolve ambiguous destinations before any execution dispatch.
3. Review proposed operations and the applicable autonomy tier. Payload sanitization and required human review precede tracker writes.
4. Read the summary and retained handoff logs. Missing platform capabilities stop the dependent action rather than triggering an alternate write path.

## Example usage

Ask: "Triage the open import-related issues in my confirmed GitHub repository. Identify duplicates and priority gaps, and prepare recommendations only. Do not update labels or post comments."

Expect a scoped advisory summary with evidence and proposed next actions. Success means planning remains read-only and any later write requires a confirmed, sanitized operation set for the correct executor.
