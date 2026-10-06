---
title: SSSC Reviewer
description: "Evidence-based reviewer for repository supply-chain security posture with audit, diff, and plan review modes"
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - sssc-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/security/sssc-reviewer.agent.md`       |
| Invocation  | Selected from the chat agent picker as `SSSC Reviewer` |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Evidence-based reviewer for repository supply-chain security posture with audit, diff, and plan review modes
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use SSSC Reviewer to assess supply-chain posture across repository configuration, dependencies, CI/CD, release integrity, provenance, and SBOM evidence. It supports full audits, change-focused reviews, and plan reviews. Use Security Reviewer for broader application-security concerns or SSSC Planner for a guided remediation plan.

## How to use it

1. Select `SSSC Reviewer` and supply `audit`, `diff`, or `plan` mode with the repository scope, PR context, changed files, or plan.
2. Provide existing supply-chain evidence and any prior report for comparison.
3. Review the assessment, verification limits, and prioritized recommendations. Keep plan risks distinct from observed repository findings.
4. If requesting a VEX assessment, provide the affected product and vulnerability evidence and retain the separate human acceptance and document-mutation gates.

## Example usage

Ask: "Review the release-workflow changes in diff mode. Assess action pinning, permissions, provenance, and artifact integrity. Keep the report scoped to current evidence and do not publish a VEX document."

Expect a supply-chain-specific report with actionable findings, evidence, and exclusions. Success means the review does not infer release assurance or vulnerability applicability from missing data.
