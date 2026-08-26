---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-08-25
---

## Objective

Before any worker is dispatched, resolve the review target and profile, establish the review context once, and serialize it for reuse across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Orientation entry

Start with the orientation floor from [Walkthrough Protocol](walkthrough-protocol.md) before deeper review dispatch. Use the walkthrough to map the diff and runway, then carry the resulting appendices into the dispatch board.

## Tier 0 procedure

1. Resolve `reviewTarget` and `reviewProfile` using [Review Targets and Profiles](review-targets.md).
2. Compute the diff once from the selected target and capture the changed-file surface.
3. Summarize the change in a concise change brief that explains what changed and why it matters.
4. Auto-detect hotspot candidates and specialist concern signals from the diff and file paths in the same pass. Tag the specialist concern classes for security, supply-chain, RAI or AI, accessibility, sustainability or efficiency, and privacy or PII using the signal-to-concern mapping in [Cross-Skill Forks](cross-skill-forks.md).
5. Persist the target, profile, emerging brief, hotspot list, tagged specialist concerns, out-of-scope areas, diff identity, and orientation task before dispatching the fresh-context orientation worker.
6. Present the walkthrough, emerging brief, and hotspot candidates to the human for confirmation and correction.
7. Invite the human to add or remove hotspots and mark out-of-scope areas before findings perspectives dispatch.
8. Persist the confirmed scope and expanded profile selection for later aggregation.

## Change brief expectations

The change brief should be short and specific. It should explain:

* the intent of the change,
* the primary files or modules involved,
* the likely risk areas,
* and any notable test or rollout considerations.

## Human-scoping protocol

Do not let the agent decide the entire scope alone. The human should be able to:

* confirm or edit the change brief,
* add or remove hotspot candidates,
* and explicitly mark areas that should not be reviewed in this run.

The review should pause for confirmation before dispatching perspective subagents or applying deeper verification.
