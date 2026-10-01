---
title: RAI Skill Assessor
description: "Assesses a single Responsible AI framework from the rai-standards skill against the codebase, reading framework references and returning structured findings"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - rai-planning
  - rai-skill-assessor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/rai-planning/subagents/rai-skill-assessor.agent.md`      |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assesses a single Responsible AI framework from the rai-standards skill against the codebase, reading framework references and returning structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

RAI Reviewer dispatches this worker to assess exactly one responsible-AI framework against a supplied codebase profile or plan. It uses the framework's references and returns requirement-level findings. It does not choose the parent's overall scope, publish a report, or grant human acceptance.

## Example usage

The parent supplies NIST AI RMF as the framework, an AI-system profile, and the plan for a document assistant. The worker returns `RAI_PLAN_FINDINGS_V1` with risk-oriented statuses and evidence gaps. In audit or diff mode it uses `RAI_FINDINGS_V1`; the parent owns verification and reporting, so a plan assessment is not presented as proof of implemented controls.
