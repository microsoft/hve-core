---
title: Code Review Depth Tiers
description: Basic, standard, and comprehensive review rigor dials for code review perspectives.
ms.date: 2026-06-18
---

## Tier model

Review depth is a verification-rigor dial, not a lane-selection mechanism. The selected perspectives determine which review lanes run; the selected depth tier determines how deeply each lane verifies the confirmed change scope.

## Tier 1 — Basic

Use Tier 1 when the change is small, low-risk, or time-sensitive. Focus on:

* the primary diff surface,
* obvious correctness and safety issues,
* and a quick pass over the main changed files.

## Tier 2 — Standard

Use Tier 2 as the default depth for most reviews. Focus on:

* the full changed-file surface,
* the confirmed hotspot list and adjacent logic,
* boundary conditions and regression risks,
* and a more complete validation of findings and recommendations.

## Tier 3 — Comprehensive

Use Tier 3 for high-risk, high-impact, or ambiguous changes. Focus on:

* a deep re-check of the confirmed hotspots and related call paths,
* broader dependency and regression analysis,
* verification of edge cases, recovery behavior, and security posture,
* and a stricter pass over testing, rollout, and rollback considerations.

## Interaction with perspective selection

The orchestrator should ask for perspective selection and depth level independently. For example, a basic review might run the functional and standards lanes, while a comprehensive run might run the same lanes plus a deeper security or accessibility pass on the confirmed hotspots.
