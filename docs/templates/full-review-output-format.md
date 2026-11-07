---
title: Code Review Output Format
description: Where Code Review defines its review records and report, and how to read and edit a generated review
sidebar_position: 10
author: microsoft/hve-core
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - code review
  - output format
  - review report
  - template
---

Code Review defines its review records and report layout once, in the `code-review-core` skill. Use these sources when you read a review closely or build tooling around one:

| Need                                                                               | Canonical source                                                                                                                                                                   |
|------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Review folder, snapshot, review state, worker results, findings, and outcome rules | [`code-review-core/references/review-contract.md`](https://github.com/microsoft/hve-core/blob/main/.github/skills/coding-standards/code-review-core/references/review-contract.md) |
| Layout of the rendered `review.md`                                                 | [`code-review-core/templates/review.md`](https://github.com/microsoft/hve-core/blob/main/.github/skills/coding-standards/code-review-core/templates/review.md)                     |
| Human review and publication rules                                                 | [`code-review/references/delivery.md`](https://github.com/microsoft/hve-core/blob/main/.github/skills/coding-standards/code-review/references/delivery.md)                         |

## Where a review is stored

Each review writes to its own folder at `.copilot-tracking/reviews/code-reviews/<date>/<review-id>/`. Snapshots under `snapshots/` are immutable. Code Review owns `review-state.json`, each worker owns its file under `results/`, and `review.md` belongs to you.

## Reading a generated report

| Section                     | What to check                                                                              |
|-----------------------------|--------------------------------------------------------------------------------------------|
| Target and coverage         | Execution status, outcome, target revisions, and whether each area and work item completed |
| Findings                    | Each finding's severity, disposition, anchors, consequence, and suggested change           |
| Context and limitations     | Blocking limitations, omitted content, discussion gaps, and worker observations            |
| PR comment draft            | PR and MR targets only: the proposed event and an unchecked posting checkbox               |
| Disclaimer and human review | The canonical Code Review disclaimer and an unchecked human-review checkbox                |

Read the outcome together with coverage. An `incomplete` review has no outcome. An empty Findings section means no findings within the completed scope, so check coverage before you treat the change as clean.

## Editing and publishing

* Edit `review.md` directly. Your edits are authoritative, and Code Review re-renders the file only while it still matches the last render; otherwise it asks you to reconcile.
* Only a human checks the human-review or posting checkbox.
* Posting to a pull request needs your explicit confirmation of the target, event, and comments. See [Code Review](../agents/code-review/README.md#publishing-to-a-pull-request) for the full sequence.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
