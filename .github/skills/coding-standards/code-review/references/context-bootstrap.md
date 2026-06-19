---
title: Code Review Context Bootstrap
description: Tier 0 workflow for establishing the change surface, drafting a change brief, and scoping review hotspots.
ms.date: 2026-06-18
---

## Objective

Before any perspective lanes are dispatched, establish the review context once and use it consistently across the run. This Tier 0 step produces a human-confirmable change brief and a scoped set of hotspot candidates.

## Tier 0 procedure

1. Compute the diff once from the selected base branch and capture the changed-file surface.
2. Summarize the change in a concise change brief that explains what changed and why it matters.
3. Auto-detect hotspot candidates from the diff and file paths for areas such as authentication, authorization, cryptography, parsing, deserialization, persistence, secrets handling, networking, or concurrency.
4. Present the emerging brief and hotspot candidates to the human for confirmation and correction.
5. Invite the human to add or remove hotspots and to mark out-of-scope areas before review lanes dispatch.
6. Persist the confirmed brief, the scoped hotspot list, and out-of-scope areas as the review context for later aggregation.

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
