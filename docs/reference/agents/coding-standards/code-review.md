---
title: Code Review
description: "Review changes through the shared Code Review skill, with focused perspectives, snapshot-backed evidence, and an optional canvas."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-06
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
Review changes through the shared Code Review skill, with focused perspectives, snapshot-backed evidence, and an optional canvas.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Select Code Review for a dedicated chat that reviews a PR or MR, a named branch comparison, a commit, local changes, or selected code. The agent preloads the `code-review` skill and runs the same workflow as `/code-review`.
Use it to find consequential defects and see what each perspective covered. For a broader domain audit, use a standalone specialist such as the Security Reviewer.

## How to use it

1. Select `Code Review` and name the target: a PR or MR, a branch and its base, a commit, staged or unstaged changes, or a file and line range. Code Review asks when the target is ambiguous and doesn't guess a base, fetch, or check out a branch.
2. Optionally set `profile=standard|full|custom` and `depth=basic|standard|comprehensive`. A clear request runs as a sweep after a compact scope summary; ask for `mode=guided` to choose areas, perspectives, and depth yourself.
3. Code Review captures one immutable snapshot, reviews small or tightly coupled work inline, and dispatches independent perspectives to parallel workers. It verifies each returned finding against the captured lines and records a disposition.
4. Open `review.md` and edit it before acting on it. Staging or posting to a PR needs your explicit confirmation of the target, event, and comments, and Code Review re-reads the PR's revisions first. The human-review and posting checkboxes stay yours to check.

When your host supports canvases, Code Review also opens the optional Code Review canvas, where you can follow coverage and findings and send feedback. The review works the same without it.

To check a change against business intent, supply BRD, PRD, or ADR identifiers or paths, or confirm the sources Code Review finds in the PR description, linked issues, changed files, or a quick search of the repository's business documents.
It compares an existing source as it stood at the base revision, so editing the document in the same PR doesn't hide drift, and it compares a new source at its current revision. A successor or supersession link added in the PR is a proposed source update and doesn't move the baseline.
Drift findings use the same severity rubric as RPI Review and count toward the outcome like other findings. A claim of owner approval in the PR stays unverified until you confirm it, and Code Review then re-rates the finding before the posting decision.
For each retained Critical or High drift finding, Code Review offers a copy-ready note to the source owner that stays local and is never posted. It also alerts you to stale sources and to changes that no source covers.

## Example usage

Ask: "Review my staged changes to `src/importer` and its tests with the full profile. Keep the review local."

Expect a compact scope summary, then a `review.md` that leads with findings and their consequences, shows what each perspective covered, and lists limitations and pending work. Success means the report covers the captured change, keeps incomplete work distinct from a clean result, and posts nothing.
