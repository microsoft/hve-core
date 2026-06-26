---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-06-26
---

## Objective

Before any perspective lanes are dispatched, establish the review context once and use it consistently across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Orientation entry

Start with the orientation floor from [Walkthrough Protocol](walkthrough-protocol.md) before deeper review dispatch. Use the walkthrough to map the diff and runway, then carry the resulting appendices into the dispatch board.

## Tier 0 procedure

1. Compute the diff once from the selected base branch and capture the changed-file surface.
2. Summarize the change in a concise change brief that explains what changed and why it matters.
3. Auto-detect hotspot candidates and specialist concern signals from the diff and file paths in the same pass. Tag the specialist concern classes for security, supply-chain, RAI or AI, accessibility, sustainability or efficiency, and privacy or PII using the signal-to-concern mapping in [Cross-Skill Forks](cross-skill-forks.md).
4. Present the emerging brief and hotspot candidates to the human for confirmation and correction.
5. Invite the human to add or remove hotspots and to mark out-of-scope areas before review lanes dispatch.
6. Persist the confirmed brief, the scoped hotspot list, the tagged specialist concerns, and out-of-scope areas as the review context for later aggregation.

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
