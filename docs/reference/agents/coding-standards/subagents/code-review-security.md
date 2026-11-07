---
title: Code Review Security
description: Review assigned changes for concrete security consequences and return the shared worker result.
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-06
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
Review assigned changes for concrete security consequences and return the shared worker result.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for the security perspective when a change touches a trust boundary, such as authentication, authorization, parsing, input validation, secrets, or sensitive-data handling. It preloads `code-review-core` and `code-review-security` and reviews only the assigned change. For a standalone audit, use the Security Reviewer; this worker doesn't start one.

## Example usage

For an upload-validation change, the parent supplies the work item, assigned hunks, depth, applicable criteria, and the result path. The worker traces input from the request to its use and writes findings that name the actor, reachable path, failed control, and consequence, anchored to the changed lines.
It returns the path, execution status, and unresolved evidence. It doesn't alter source or report theoretical issues without a realistic consequence.
