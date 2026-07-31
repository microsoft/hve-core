---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-07-31
---

## Objective

Before any perspective lanes are dispatched, establish the review context once and use it consistently across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Orientation entry

Start with the orientation floor from [Walkthrough Protocol](walkthrough-protocol.md) before deeper review dispatch. Use the walkthrough to map the diff and runway, then carry the resulting appendices into the dispatch board.

## Tier 0 procedure

1. Compute the diff once from the selected base branch and capture the changed-file surface.
2. Draft a **Change-Risk Profile** alongside the change brief using the deterministic signals defined in [Change-Risk Model](change-risk-model.md). Evaluate Likelihood (size, diffusion, entropy), Severity (path criticality), Detectability (test presence), and Recoverability (rollback markers) using `git log` and `git diff` heuristics.
3. Summarize the change in a concise change brief that explains what changed and why it matters.
4. Auto-detect hotspot candidates and specialist concern signals from the diff and file paths in the same pass. Tag the specialist concern classes for security, supply-chain, RAI or AI, accessibility, sustainability or efficiency, and privacy or PII using the signal-to-concern mapping in [Cross-Skill Forks](cross-skill-forks.md). Rank hotspot candidates using the risk profile's evidence (e.g., trailing churn, missed co-changes).
5. Present the emerging brief, the Change-Risk Profile evidence, and hotspot candidates to the human for confirmation and correction.
6. Invite the human to add or remove hotspots, adjust the risk profile interpretation, and mark out-of-scope areas before review lanes dispatch.
7. Persist the confirmed brief, the risk profile, the scoped hotspot list, the tagged specialist concerns, and out-of-scope areas as the review context for later aggregation.

## Change brief expectations

The change brief should be short and specific. It should explain:

* the intent of the change,
* the primary files or modules involved,
* the likely risk areas,
* and any notable test or rollout considerations.

## Change-Risk Profile expectations

The Change-Risk Profile is an advisory, evidence-bearing vector, never a single opaque score. It must cite specific git-computable signals (e.g., "High diffusion across 4 subsystems", "Touches trailing 90-day hotspots", "No test files present in diff"). For repositories with shallow git history, explicitly state the confidence level and rely on baseline signals like Size and Diffusion. The profile informs the human-scoping step and subsequent depth-tier selection but never acts as a hard gate.

## Human-scoping protocol

Do not let the agent decide the entire scope alone. The human should be able to:

* confirm or edit the change brief,
* review and adjust the Change-Risk Profile evidence,
* add or remove hotspot candidates,
* and explicitly mark areas that should not be reviewed in this run.

The review should pause for confirmation before dispatching perspective subagents or applying deeper verification.
