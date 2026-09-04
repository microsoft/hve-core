---
title: Engagement Report Reviewer
description: "Reviews engagement report drafts for grounding, privacy, audience fit, style, terminology, and continuity."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - agent
  - engagement-reporting
  - engagement-report-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | agent                                                                               |
| Source      | `.github/agents/engagement-reporting/subagents/engagement-report-reviewer.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)            |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reviews engagement report drafts for grounding, privacy, audience fit, style, terminology, and continuity.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this subagent for an isolated review of a high-stakes, complex, or
explicitly selected engagement report. It checks source grounding, privacy,
audience fit, directionality, attribution, continuity, terminology, and
template compliance.

Routine weekly reports use the reporting skill's silent inline review instead.

## Example usage

The report generator supplies the validated reporting date and report-type slug,
the parent-established effective-ignore result for `.working/`, the draft,
research index, coverage summary, prior-period continuity context, audience,
and selected template. The reviewer derives and canonically confines the three
fixed artifacts under the report's `review/` working directory, then returns a
pass, revise, or blocked disposition.
