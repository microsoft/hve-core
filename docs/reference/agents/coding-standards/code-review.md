---
title: Code Review
description: "Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
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
It always uses the latest copy of a document and compares against the version on the base branch, so editing the document in the same PR doesn't hide drift.
The agent uses the same severity rubric RPI Review uses and adds a Business Alignment section to the draft.
Critical and High alignment findings request changes until the code is aligned or you confirm, in the pause before posting, that the source owner acknowledged the change; a PR's own claim of approval is shown as not verified.
For each of those findings, the agent offers to draft a copy-ready note to the source owner; the note stays in your local draft and is never posted.
It also alerts you when a cited document is stale or when no document covers the change, suggesting that you update the reference or draft a new ADR, BRD, or PRD.

## Example usage

Ask: "Review my local changes to `src/importer` and its tests. Start with an orientation, recommend perspectives and depth, and let me confirm before the sweep. Keep the review local."

Expect a dispatch board followed by a consolidated draft with findings, evidence, limitations, and suggested next actions. Success means the report covers the confirmed change surface and does not publish comments or confuse unchecked areas with reviewed code.
