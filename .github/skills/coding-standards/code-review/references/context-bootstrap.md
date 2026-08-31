---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-08-29
---

## Objective

Before any perspective lanes are dispatched, establish the review context once and use it consistently across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Orientation entry

Start with the orientation floor from [Walkthrough Protocol](walkthrough-protocol.md) before deeper review dispatch. Use the walkthrough to map the diff and runway, then carry the resulting appendices into the dispatch board.

## Tier 0 procedure

1. Compute the diff once from the selected base branch and capture the changed-file surface.
2. Gather the six categories from the [Change-Risk Evidence Checklist](change-risk-model.md): change scope, path criticality, history, test presence, coverage, and rollback. Record each category as `observed`, `unavailable`, or `qualitative` with concise supporting evidence.
3. Summarize the change in a concise change brief that explains what changed and why it matters.
4. Auto-detect hotspot candidates and specialist concern signals from the diff and file paths in the same pass. Tag the specialist concern classes for security, supply-chain, RAI or AI, accessibility, sustainability or efficiency, and privacy or PII using the signal-to-concern mapping in [Cross-Skill Forks](cross-skill-forks.md). Use available history evidence to inform hotspot ordering without treating co-change or churn as proof of a defect.
5. Derive an advisory depth recommendation from the checklist. Use `standard` when the evidence is incomplete or inconclusive.
6. Present the emerging brief, checklist evidence, recommendation, and hotspot candidates to the human for confirmation and correction.
7. Invite the human to correct evidence, add or remove hotspots, select the review depth, explain any difference from the recommendation, and mark out-of-scope areas before review lanes dispatch.
8. Persist the brief, `changeRiskEvidence`, `recommendedDepth`, selected `depthTier`, `depthRationale`, scoped hotspots, tagged specialist concerns, and out-of-scope areas as the review context for later aggregation. In interactive mode, identify values the human confirmed or corrected. In workflow mode, identify generated or defaulted values as automation-derived.

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
