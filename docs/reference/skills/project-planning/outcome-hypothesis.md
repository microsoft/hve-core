---
title: outcome-hypothesis
description: "Create or assess an evidence-grounded, falsifiable outcome hypothesis: a testable prediction of what measurable business result will change, for whom, by when, and how leading and lagging indicators will prove or disprove it. Use when framing measurable outcomes, turning an MVP, POC, feature, or technical initiative into a beneficiary result, defining targets and indicators, or judging whether evidence is strong enough to invest. Also applies to business outcome hypotheses, value hypotheses, and outcome statements."
sidebar_position: 2
ms.date: 2026-08-12
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

Invoke `/outcome-hypothesis` with the relevant evidence sources or an existing statement to assess. The skill scores seven readiness dimensions before drafting, then produces a Full Outcome Hypothesis, a Provisional Outcome Hypothesis with explicit gaps, or an Investigation response. It validates drafts against OH.0-OH.12 and identifies critical failures that make a hypothesis not investable.

Review the complete result in chat before asking to save it. Unknown baselines, targets, owners, stakeholders, sources, and dates remain explicit gaps rather than inferred values.

## Example usage

```text
/outcome-hypothesis

Assess the onboarding outcome described in our discovery notes. The product
dashboard shows 42% activation for mid-market support administrators, and the
approved target is 60% within 90 days of guided setup launch.
```

The skill first presents the D1-D7 scorecard and readiness route. It then returns the appropriate hypothesis or investigation response, including measurable indicators, the outcome chain, assumptions, falsification criteria, validation warnings, and unresolved evidence gaps.
