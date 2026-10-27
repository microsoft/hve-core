---
title: Code Review
description: "Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report"
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-13
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/coding-standards/code-review.agent.md` |
| Invocation  | Selected from the chat agent picker as `Code Review`   |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Code Review for a pull request, an explicit branch comparison, or local working-tree changes when you want to steer the scope and depth of the assessment. It builds a factual orientation before dispatching selected functional, standards, readiness, security, or accessibility perspectives. Use a standalone specialist reviewer for a broader domain audit.

## How to use it

1. Select `Code Review` and identify the PR, base and head references, or local changes. The checked-out HEAD must match a resolved PR or branch target.
2. Read the change brief and orientation, then confirm scope, perspectives, and depth. Choosing every perspective does not itself choose a deeper assessment.
3. Bookmark areas to explore or request the selected review sweep. The agent consolidates evidence-backed findings into a local review draft.
4. Open and edit the draft before acting on it. External submission requires explicit confirmation and a fresh target-state check; required human-review checkboxes remain yours to complete.

To check a change against business intent, supply BRD, PRD, or ADR identifiers or paths, or confirm the ones the agent finds in the PR description, linked issues, changed files, or a quick search of the repository's business documents.
For an existing modified source, it establishes BRD or PRD identity from the base revision and compares against the latest source resolved from that revision, so removing metadata or editing the document in the same PR does not hide drift.
A genuinely new source has no base revision, so the agent uses its current revision.
If an existing source's base revision is unreadable, the agent uses removed diff lines for modified passages, leaves added-only passages unassessed, and may read the current source once for metadata or passages that the diff demonstrates are unchanged.
A successor or supersession link added in the PR is only a proposed source update and does not replace the comparison baseline.
The agent uses the same severity rubric RPI Review uses and adds a Business Alignment section to the draft.
Critical and High alignment findings request changes until the code is aligned or you confirm, in the pause before posting, that the source owner acknowledged the change; a PR's own claim of approval is shown as not verified.
For each of those findings, the agent offers to draft a copy-ready note to the source owner; the note stays in your local draft and is never posted.
It also alerts you when a cited document is stale or when no document covers the change, suggesting that you update the reference or draft a new ADR, BRD, or PRD.

## Example usage

Ask: "Review my local changes to `src/importer` and its tests. Start with an orientation, recommend perspectives and depth, and let me confirm before the sweep. Keep the review local."

Expect a dispatch board followed by a consolidated draft with findings, evidence, limitations, and suggested next actions. Success means the report covers the confirmed change surface and does not publish comments or confuse unchecked areas with reviewed code.
