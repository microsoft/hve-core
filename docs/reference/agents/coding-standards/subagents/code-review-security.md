---
title: Code Review Security
description: Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-security
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/coding-standards/subagents/code-review-security.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this perspective for security-relevant changes such as authorization, parsing, input validation, or sensitive-data handling. It traces concrete exploit paths within the supplied scope and does not invoke the standalone Security Reviewer. Users steer it through the parent review workflow.

## Example usage

For an upload-validation change, the parent supplies the serialized diff, hotspots, review depth, exclusions, and `task.outputs.security`. The worker traces input to its use and returns JSON findings with evidence, impact, and a concrete fix. It does not alter source or report theoretical issues without a realistic security consequence.
