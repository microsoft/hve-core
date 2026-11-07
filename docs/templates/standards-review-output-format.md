---
title: Code Review Standards Output Format
description: How the Code Review standards perspective records findings and criteria provenance in the shared review contract
sidebar_position: 9
author: microsoft/hve-core
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - code review
  - coding standards
  - output format
  - criteria provenance
---

The standards perspective has no report template of its own. It writes the shared Code Review worker result, and Code Review renders every perspective into one `review.md`.
The `code-review-core` [review contract](https://github.com/microsoft/hve-core/blob/main/.github/skills/coding-standards/code-review-core/references/review-contract.md) defines the result and finding fields, and the [`code-review-standards` skill](https://github.com/microsoft/hve-core/blob/main/.github/skills/coding-standards/code-review-standards/SKILL.md) defines how standards criteria are selected and cited.

## How standards results use the contract

| Result field                         | Standards usage                                                                                      |
|--------------------------------------|------------------------------------------------------------------------------------------------------|
| `findings[].criterion`               | The applicable instruction or exact skill name, with the criterion applied                           |
| `findings[].claim` and `consequence` | The departure and why it matters; preference alone isn't a finding                                   |
| `findings[].anchors`                 | The captured changed lines the finding applies to                                                    |
| `findings[].remediation`             | The suggested change                                                                                 |
| `observations`                       | The criteria sources used, with name, location or origin label, and scope, plus unresolved conflicts |
| `coverage`                           | The files and hunks reviewed, or a not-applicable reason                                             |
| `limitations`                        | Missing or conflicting criteria and other evidence gaps                                              |

Severity is `Critical`, `High`, `Medium`, or `Low` and describes the consequence. A result carries no confidence scores and no verdict. Code Review sets the overall outcome after it verifies each finding.

When no instructions or skills apply, the result records standards evidence as unavailable. That gap stays visible and doesn't count as a standards pass.

## Where standards findings appear

Code Review verifies each standards finding, records its disposition, and renders it under Findings in `review.md`. The criteria sources from the result's observations appear under Context and limitations. See [Language Skills](../agents/code-review/language-skills.md) for how criteria are selected and [Code Review Output Format](full-review-output-format.md) for the full report.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
