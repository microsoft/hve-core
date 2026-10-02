---
title: Code Review Depth Tiers
description: Basic, standard, and comprehensive review rigor dials for code review perspectives.
ms.date: 2026-10-02
---

## Tier model

Review depth is a verification-rigor dial, not a lane-selection mechanism. The selected perspectives determine which review lanes run; the resolved depth tier determines how deeply each lane verifies the change scope. Use the [Change-Risk Evidence Checklist](change-risk-model.md) to make an advisory recommendation before the human selects a tier or explicit invocation preauthorization accepts the recommendation.

## Tier 1 — Basic

Recommend Tier 1 only when available evidence consistently supports a narrow, reversible, well-tested change with no critical-path concern. The human may still select another tier. Focus on:

* the primary diff surface,
* obvious correctness and safety issues,
* and a quick pass over the main changed files.

## Tier 2 — Standard

Recommend Tier 2 for most reviews. It is the safe default when history, coverage, or other material evidence is unavailable, conflicting, or inconclusive. Focus on:

* the full changed-file surface,
* the confirmed hotspot list and adjacent logic,
* boundary conditions and regression risks,
* and a more complete validation of findings and recommendations.

## Tier 3 — Comprehensive

Recommend Tier 3 when observed or qualitative evidence identifies critical paths, broad behavioral spread, weak detection for important logic, hard rollback, or material ambiguity. Do not escalate only because history or coverage is unavailable. Focus on:

* a deep re-check of the confirmed hotspots and related call paths,
* broader dependency and regression analysis,
* verification of edge cases, recovery behavior, and security posture,
* and a stricter pass over testing, rollout, and rollback considerations.

## Interaction with perspective selection

The orchestrator should resolve perspective selection and depth level independently. Present the checklist and recommendation first, then record the selected depth, rationale, and provenance. In default interactive mode the human selects the tier. With explicit invocation preauthorization, use the recommended tier and label the selection automation-derived. For example, a basic review might run the functional and standards lanes, while a comprehensive run might run the same lanes with deeper verification of confirmed hotspots.
