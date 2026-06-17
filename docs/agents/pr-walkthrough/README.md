---
title: PR Walkthrough
description: Narrative-driven PR orientation agent that builds a reviewer's mental model before they open the diff
sidebar_position: 1
sidebar_label: Overview
keywords:
  - PR walkthrough
  - pull request review
  - narrative review
  - code review orientation
  - design forks
tags:
  - agents
  - pr-walkthrough
  - hve-core
author: Microsoft
ms.date: 2026-06-15
ms.topic: concept
estimated_reading_time: 5
maturity: experimental
---

The PR Walkthrough agent produces a narrative orientation of a pull request or branch diff. It builds the reviewer's mental model so they understand what changed, why, how the pieces connect, and where human judgment is required, before they open the diff.

This is not a findings tool. It does not hunt for bugs or enforce coding standards. It orients the reviewer so they can review efficiently and notice what matters.

> Most reviewers open a 40-file diff and start scrolling. The walkthrough gives them the map before they enter the territory.

## When to Use

| Scenario                | Why it helps                                               |
|-------------------------|------------------------------------------------------------|
| Large PRs (20+ files)   | Identifies the 3-5 files that carry architectural weight   |
| Cross-cutting refactors | Names the bets and design forks the diff embodies          |
| Onboarding reviewers    | Provides context a newcomer cannot get from the diff alone |
| Security/governance PRs | Surfaces implicit trust boundary decisions                 |

## Output Format

The walkthrough produces a single markdown document with:

1. A title and subtitle contextualizing scope and stakes
2. A flowing narrative structured around decisions (not files)
3. Appendices (when applicable): Design forks, Implicit bets, Triage map, The diff in N layers

The narrative uses an editorial voice with headers as narrative beats rather than section labels. Code fragments are quoted inline as evidence supporting the narrative.

## Invocation

Select **PR Walkthrough** from the agent picker and provide a branch name or PR URL. The agent computes the diff, analyzes the change, and produces the walkthrough.

## Output Location

Walkthroughs are written to:

```text
.copilot-tracking/pr/review/<sanitized-branch>/walkthrough.md
```

## Relationship to Code Review Agents

The PR Walkthrough and the Code Review agents serve complementary but distinct purposes:

| Aspect   | PR Walkthrough                                  | Code Review                                     |
|----------|-------------------------------------------------|-------------------------------------------------|
| Goal     | Build reviewer's mental model                   | Find defects and standards violations           |
| Stance   | Neutral (surfaces decisions for human judgment) | Evaluative (renders findings with verdicts)     |
| Output   | Narrative essay                                 | Structured findings with line-level citations   |
| Audience | Human reviewer before they form opinions        | Human reviewer after they want actionable items |

The agents can be used independently or sequentially. When used together, the walkthrough provides orientation and the code review provides detailed findings.

## Dependencies

The walkthrough uses the **pr-reference skill** for diff computation (shared infrastructure within the hve-core collection).

## Maturity

This agent is marked `experimental`. The voice and output format are under active validation through user testing.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
