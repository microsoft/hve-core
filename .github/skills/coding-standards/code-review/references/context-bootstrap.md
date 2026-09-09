---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-09-08
---

## Objective

Before any worker is dispatched, resolve the review target and profile, establish the review context once, and serialize it for reuse across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Orientation entry

Start with the orientation floor from [Walkthrough Protocol](walkthrough-protocol.md) before deeper review dispatch. Use the walkthrough to map the diff and runway, then carry the resulting appendices into the dispatch board.

## Tier 0 procedure

1. Resolve `reviewTarget` and `reviewProfile` using [Review Targets and Profiles](review-targets.md).
2. Compute the diff once from the selected target and capture the changed-file surface.
3. Gather the six categories from the [Change-Risk Evidence Checklist](change-risk-model.md): change scope, path criticality, history, test presence, coverage, and rollback. Record each category as `observed`, `unavailable`, or `qualitative` with concise supporting evidence.
4. Summarize the change in a concise change brief that explains what changed and why it matters.
5. Auto-detect hotspot candidates and specialist concern signals from the diff and file paths in the same pass. Tag the specialist concern classes for security, supply-chain, RAI or AI, accessibility, sustainability or efficiency, and privacy or PII using the signal-to-concern mapping in [Cross-Skill Forks](cross-skill-forks.md). Use available history evidence to inform hotspot ordering without treating co-change or churn as proof of a defect.
6. Derive an advisory depth recommendation from the checklist. Use `standard` when the evidence is incomplete or inconclusive.
7. Persist the target, profile, emerging brief, checklist evidence, recommendation, hotspot list, tagged specialist concerns, out-of-scope areas, diff identity, and orientation task before dispatching the fresh-context orientation worker.
8. Present the walkthrough, emerging brief, checklist evidence, recommendation, and hotspot candidates to the human for confirmation and correction.
9. Invite the human to correct evidence, add or remove hotspots, select the review depth, explain any difference from the recommendation, and mark out-of-scope areas before findings perspectives dispatch.
10. Persist the target, profile, brief, `changeRiskEvidence`, `recommendedDepth`, selected `depthTier`, `depthRationale`, scoped hotspots, tagged specialist concerns, and out-of-scope areas as the review context for later aggregation. In interactive mode, identify values the human confirmed or corrected. In workflow mode, identify generated or defaulted values as automation-derived.

## Change brief expectations

The change brief should be short and specific. It should explain:

* the intent of the change,
* the primary files or modules involved,
* the likely risk areas,
* and any notable test or rollout considerations.

## Change-risk evidence expectations

The checklist is advisory evidence, not an overall score, categorical rating, or confidence assessment. Cite concrete observations when available, mark missing history or coverage `unavailable`, and identify interpretation-dependent evidence as `qualitative`. Treat agent-generated qualitative evidence as proposed until a human confirms or corrects it. Missing evidence must remain visible and defaults the recommendation to standard unless other evidence supports comprehensive review.

## Human-scoping protocol

Do not let the agent decide the entire scope alone. The human should be able to:

* confirm or edit the change brief,
* review and correct the change-risk evidence and recommendation,
* select the depth tier and explain any difference from the recommendation,
* add or remove hotspot candidates,
* and explicitly mark areas that should not be reviewed in this run.

The review should pause for confirmation before dispatching perspective subagents or applying deeper verification.
