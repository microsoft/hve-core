---
title: Supply Chain Skill Assessor
description: Assesses supply-chain posture against the supply-chain skill and returns structured findings
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - supply-chain-skill-assessor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/security/subagents/supply-chain-skill-assessor.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assesses supply-chain posture against the supply-chain skill and returns structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

SSSC Reviewer dispatches this worker to assess one supply-chain skill and its reference catalogs against repository evidence or a plan. It records posture, adoption categories, gaps, and remediation guidance. The parent owns scope, verification, and the final report rather than this delegated assessor.

## Example usage

The parent supplies the supply-chain skill, codebase profile, and changed release workflows in diff mode. The worker returns structured findings about provenance, dependency, or repository controls with supporting evidence and adoption categories. For plan mode it reports proposed-risk coverage instead of observed posture, and it does not change workflows or certify a supply-chain maturity level.
