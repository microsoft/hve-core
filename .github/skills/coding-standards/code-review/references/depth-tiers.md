---
title: Code Review Depth Tiers
description: Basic, standard, and comprehensive review rigor dials for code review perspectives.
ms.date: 2026-07-31
---

## Tier model

Review depth is a verification-rigor dial, not a lane-selection mechanism. The selected perspectives determine which review lanes run; the selected depth tier determines how deeply each lane verifies the confirmed change scope. Depth-tier recommendations are driven by the evidence provided in the **Change-Risk Profile** (see [Change-Risk Model](change-risk-model.md)), mapping deterministic, git-computable signals to verification rigor rather than relying on heuristic "gut feel".

## Tier 1 — Basic

Use Tier 1 when the Change-Risk Profile indicates low risk. Evidence includes low **Likelihood** (small size, low diffusion, mechanical changes), high **Detectability** (tests present), or high **Recoverability** (safely behind feature flags). Focus on:

* the primary diff surface,
* obvious correctness and safety issues,
* and a quick pass over the main changed files.

## Tier 2 — Standard

Use Tier 2 as the default depth for most reviews, or when the Change-Risk Profile indicates moderate risk. Evidence includes moderate **Likelihood** (standard feature work, contained diffusion) with adequate **Detectability** (tests present) and standard **Recoverability** (no hard-to-rollback schema migrations). Focus on:

* the full changed-file surface,
* the confirmed hotspot list and adjacent logic,
* boundary conditions and regression risks,
* and a more complete validation of findings and recommendations.

## Tier 3 — Comprehensive

Use Tier 3 when the Change-Risk Profile indicates high risk, high impact, or ambiguity. Evidence includes high **Likelihood** and **Severity** (touches trailing 90-day hotspots, high diffusion across subsystems, missed co-changes in coupled clusters, or critical paths per [Severity Taxonomy](severity-taxonomy.md)), low **Detectability** (missing tests for critical logic), or high agentic **Amplification Ratio** (plan-to-code mismatch). Focus on:

* a deep re-check of the confirmed hotspots and related call paths,
* broader dependency and regression analysis,
* verification of edge cases, recovery behavior, and security posture,
* and a stricter pass over testing, rollout, and rollback considerations.

## Interaction with perspective selection

The orchestrator should ask for perspective selection and depth level independently. For example, a basic review might run the functional and standards lanes, while a comprehensive run might run the same lanes plus a deeper security or accessibility pass on the confirmed hotspots.
