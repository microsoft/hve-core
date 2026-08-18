---
title: outcome-hypothesis
description: "Create or assess an evidence-grounded, falsifiable outcome hypothesis: a testable prediction of what measurable business result will change, for whom, by when, and how leading and lagging indicators will prove or disprove it. Use when framing measurable outcomes, turning an MVP, POC, feature, or technical initiative into a beneficiary result, defining targets and indicators, or judging whether evidence is strong enough to invest. Also applies to business outcome hypotheses, value hypotheses, and outcome statements."
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-18
ms.topic: reference
keywords:
  - skill
  - project-planning
  - outcome-hypothesis
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/project-planning/outcome-hypothesis`                                 |
| Invocation  | Invoked directly as `/outcome-hypothesis`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create or assess an evidence-grounded, falsifiable outcome hypothesis: a testable prediction of what measurable business result will change, for whom, by when, and how leading and lagging indicators will prove or disprove it. Use when framing measurable outcomes, turning an MVP, POC, feature, or technical initiative into a beneficiary result, defining targets and indicators, or judging whether evidence is strong enough to invest. Also applies to business outcome hypotheses, value hypotheses, and
outcome statements.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when an engagement idea, proposal, or existing outcome statement needs to become a measurable prediction about beneficiary change. It is especially useful before requirements authoring, when the available evidence, baselines, targets, or measurement ownership may still be incomplete.

Use `requirements-author` instead when the outcome is already understood and the task is to create or govern a BRD or PRD. Use `performance-slo-planner` for production SLOs, capacity, latency budgets, and load-test planning.

## How to use it

Invoke `/outcome-hypothesis` with the relevant evidence sources and choose create or assess mode. Create mode scores seven readiness dimensions before producing a Full Outcome Hypothesis, a Provisional Outcome Hypothesis with explicit gaps, or an Investigation response. Assess mode preserves the supplied statement, then reports the D1-D7 readiness decision and OH.0-OH.13 findings separately. Both modes identify critical failures that make a hypothesis not investable.

Review a created draft in chat before asking to save it. Unknown baselines,
targets, owners, stakeholders, sources, and dates remain explicit gaps rather
than inferred values. An accepted save offer defaults to
`docs/planning/outcome-hypotheses/yyyy-mm-dd-<short-slug>-outcome-hypothesis.md`
unless you choose another destination.

Treat investable as an evidence-readiness signal only: it means the defined
evidence gates passed, while not investable means required evidence is
incomplete. The verdict is decision support, not financial or professional
investment advice, approval, funding authorization, stakeholder commitment, or
measurement sign-off. Validate it with affected stakeholders, the measurement
owner, and the accountable sponsor or decision owner before making commitments.

Assessment does not revise or persist the supplied statement; request a revised
draft separately when needed.

## Example usage

```text
/outcome-hypothesis

Create an onboarding outcome hypothesis from our discovery notes. The product
dashboard shows 42% activation for mid-market support administrators, and the
approved target is 60% within 90 days of guided setup launch.
```

The skill first presents the D1-D7 scorecard and readiness route. In create mode, it then returns a Full or Provisional Outcome Hypothesis when readiness permits, including measurable indicators, validation warnings, investability, confidence, and unresolved evidence gaps.
