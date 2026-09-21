---
title: Security Reviewer
description: Security skill assessment orchestrator for codebase profiling and vulnerability reporting
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - security-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                      |
|-------------|------------------------------------------------------------|
| Kind        | agent                                                      |
| Source      | `.github/agents/security/security-reviewer.agent.md`       |
| Invocation  | Selected from the chat agent picker as `Security Reviewer` |
| Interactive | Yes                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Security skill assessment orchestrator for codebase profiling and vulnerability reporting
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Security Reviewer to audit repository security, review a changed surface, or assess a plan before implementation. It profiles technologies, selects applicable security skills, verifies findings where the mode permits, and consolidates a report. Use Security Planner to develop a security model and control roadmap.

## How to use it

1. Select `Security Reviewer` and identify `audit`, `diff`, or `plan` mode and the target scope.
2. Supply any skill focus, prior report, or plan. For audit or diff correlation, identify the security-plan baseline explicitly.
3. Review skill findings, verification results, exclusions, and report limitations. Plan-mode risks are not current-code vulnerability findings.
4. Resolve the report's priorities through the appropriate owner. Request TM7 work separately when needed, and retain the required professional-review boundary.

## Example usage

Ask: "Review the changed upload and authorization paths in diff mode. Focus on the changed behavior, verify actionable findings, and report excluded or unavailable checks. Do not modify source files."

Expect a scoped security report with evidence and verification outcomes. Success means confirmed findings are separated from unassessed areas, and a narrow diff is not presented as a full-system audit.
