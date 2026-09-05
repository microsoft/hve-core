---
title: "PRD Planning Workflow"
description: "Where PRD-to-work-item hierarchy planning moved after the backlog consolidation"
author: Microsoft
ms.date: 2026-08-06
ms.topic: tutorial
keywords:
  - ado
  - prd
  - work items
  - migration
estimated_reading_time: 3
sidebar_position: 11
---

PRD planning still exists. The per-platform PRD-to-work-item agents were replaced by one platform-agnostic agent.

## Where This Went

The Functional Planner agent turns a Product Requirements Document into a validated work-item hierarchy for Azure DevOps, GitHub, or Jira. It replaces both `ADO PRD to WIT` and `Jira PRD to WIT`, and it adds GitHub support those agents never had.

Planning is strictly read-only. The agent validates supported types and required fields with read-only discovery, then produces a reviewable handoff. Nothing reaches your tracker during planning.

## What Changed

Applying the plan is now a separate, explicit step. After you review the handoff, run `/backlog-execute run` to create the hierarchy. That pass carries the autonomy gates, dry-run preview, content sanitization, and operation logging that a mutating run requires.

Separating planning from execution means a hierarchy proposal can be reviewed and corrected before any work item exists.

## Where to Go Next

* [Backlog Management overview](../backlog/README.md) explains the consolidated agents and their workflows.
* [Execution workflow](../backlog/execution.md) describes how a reviewed handoff becomes tracker changes.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
