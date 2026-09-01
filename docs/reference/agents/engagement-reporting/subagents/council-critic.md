---
title: Engagement Report Council Critic
description: Independently critiques one engagement report draft against research evidence without reading other critiques.
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-01
ms.topic: reference
keywords:
  - agent
  - engagement-reporting
  - council-critic
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/engagement-reporting/subagents/council-critic.agent.md`  |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Independently critiques one engagement report draft against research evidence without reading other critiques.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this subagent when Council validation is explicitly enabled for a
high-stakes or complex report. Dispatch at least two isolated runs with distinct
critic identifiers so each critique remains independent.

Use the Engagement Report Reviewer instead for a single independent quality
review.

## Example usage

The report generator supplies one draft, the normalized research findings,
coverage summary, audience, template, reporting date, report-type slug, and
critic-run slug. The critic derives a confined synthesis path and returns
section-level accuracy and completeness findings without reading other
critiques or rewriting the draft.
