---
title: Engagement Report Council Arbiter
description: Reconciles independent report critiques against research evidence and records user-approved decisions.
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-01
ms.topic: reference
keywords:
  - agent
  - engagement-reporting
  - council-arbiter
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/engagement-reporting/subagents/council-arbiter.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reconciles independent report critiques against research evidence and records user-approved decisions.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this subagent after at least two isolated Council critiques exist. It
compares conflicting recommendations with the research record, identifies
material decisions, and records the user's approved reconciliation.

Do not dispatch it for a single critique, routine inline review, or before the
independent critics have completed.

## Example usage

The report generator first dispatches proposal mode with two critique artifacts,
the draft, research findings, coverage summary, audience, and template. After
the user decides the material proposals, the generator dispatches persistence
mode with the validated reporting date, report-type slug, completed critique
set, and approved decisions. The arbiter writes only the confined
`synthesis/council-minutes.md` record.
