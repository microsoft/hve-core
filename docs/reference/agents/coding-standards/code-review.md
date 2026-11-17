---
title: Code Review
description: "Prioritize functional code review through the consolidated code-review skill, with parallel general-purpose task orchestration, strictly opt-in non-functional vectors, and an optional Code Review canvas."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-17
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
Prioritize functional code review through the consolidated code-review skill, with parallel general-purpose task orchestration, strictly opt-in non-functional vectors, and an optional Code Review canvas.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Select Code Review for a dedicated chat that reviews a PR or MR, a named branch comparison, a commit, local changes, or selected code. The agent preloads the `code-review` skill and prioritizes functional review by default. Non-functional review vectors (`security`, `rai`, `sssc`, `performance`, `privacy`, `accessibility`) and BRD/PRD/ADR alignment remain unloaded unless you explicitly request them.

## How to use it

1. Select `Code Review` and name the target: a PR or MR, a branch and its base, a commit, staged or unstaged changes, or a file and line range. Code Review asks when the target is ambiguous and doesn't guess a base, fetch, or check out a branch.
2. Functional review runs first by default, checking codebase requirements, code quality and standards, unintended side effects and bugs, refactored control paths, missed APIs/SDKs, missed abstractions, and unneeded edge-case checks. Optionally request specific non-functional vectors (`security`, `rai`, `sssc`, `performance`, `privacy`, `accessibility`) for specific areas or the whole review, and choose `depth=basic|standard|comprehensive` or `mode=guided`.
3. Code Review captures one immutable snapshot, reviews small diffs inline, and orchestrates parallel `general-purpose` tasks across vectors, phases, and areas (or reports recommended sessions to a Project coordinator when working inside a Project). It verifies each returned finding against captured lines, tags findings and comments with vector pills, and records dispositions.
4. Open `review.md` and edit it before acting on it. Staging or posting to a PR needs your explicit confirmation of the target, event, and comments, and Code Review re-reads the PR's revisions first. The human-review and posting checkboxes stay yours to check.

When your host supports canvases, Code Review opens the Code Review canvas, where you can inspect findings and comments with vector pills and request non-functional reviews per area or across the review.

If you explicitly request BRD, PRD, or ADR alignment, Code Review loads `references/integrations.md`, compares existing sources at the base revision so in-PR edits do not hide drift, and applies the shared business-alignment rubric.

## Example usage

Ask: "Review my staged changes to `src/importer` and its tests. Keep the review local, and also run a `security` review on the parser area."

Expect a compact scope summary, then a `review.md` that leads with vector-tagged findings and their consequences, shows what each scheduled vector covered, and lists limitations and pending work. Success means the report covers the captured change, keeps incomplete work distinct from a clean result, and posts nothing.
