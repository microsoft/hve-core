---
title: SSSC Planner
description: "Six-phase repository supply chain security assessment against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog of reusable workflows."
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - sssc-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | agent                                                 |
| Source      | `.github/agents/security/sssc-planner.agent.md`       |
| Invocation  | Selected from the chat agent picker as `SSSC Planner` |
| Interactive | Yes                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Six-phase repository supply chain security assessment against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog of reusable workflows.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use SSSC Planner to plan software supply-chain improvements across repository controls, dependency hygiene, build provenance, signing, and SBOM practices. It connects assessment evidence to OpenSSF Scorecard, SLSA, and related guidance and produces prioritized workflow work. Use SSSC Reviewer to assess existing posture or changes.

## How to use it

1. Select `SSSC Planner` and identify the repository, release process, target standards, and any PRD, BRD, or security-plan context.
2. Confirm scope and supply-chain facts before interpreting maturity or control gaps.
3. Review assessment evidence, standards mappings, and the gap analysis through the six planning phases.
4. Review prioritized backlog drafts before execution. Optional VEX planning is distinct from accepting vulnerability applicability or publishing a VEX statement.

## Example usage

Ask: "Plan supply-chain improvements for our release workflows. Assess dependency pinning, provenance, signing, and SBOM coverage, then prioritize reusable-workflow changes with evidence and unknowns."

Expect a repository-specific assessment and control backlog rather than a generic checklist. Success means the proposed work closes named gaps and does not claim an unverified assurance level.
