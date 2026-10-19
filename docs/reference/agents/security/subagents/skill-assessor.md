---
title: Skill Assessor
description: Assesses a single security skill against the codebase and returns structured findings
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - skill-assessor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/security/subagents/skill-assessor.agent.md`              |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assesses a single security skill against the codebase and returns structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Security Reviewer dispatches Skill Assessor for exactly one security knowledge skill at a time. It reads the skill's vulnerability references and assesses code or a supplied plan. Users select the parent review workflow; the assessor neither chooses a broader scan nor replaces downstream verification.

## Example usage

The parent supplies a web-security skill, codebase profile, and changed API paths in diff mode. The worker returns `SKILL_FINDINGS_V1` with reference coverage and code evidence for each finding. A plan dispatch returns `PLAN_FINDINGS_V1` with risk-oriented statuses instead. The parent verifies and consolidates the result; the worker does not modify source or claim a whole-system audit from a narrow scope.
