---
title: Experiment Designer
description: "Coach for designing a Minimum Viable Experiment (MVE) with hypothesis formation, vetting, and experiment planning"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - experimental
  - experiment-designer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | agent                                                        |
| Source      | `.github/agents/experimental/experiment-designer.agent.md`   |
| Invocation  | Selected from the chat agent picker as `Experiment Designer` |
| Interactive | Yes                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coach for designing a Minimum Viable Experiment (MVE) with hypothesis formation, vetting, and experiment planning
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Experiment Designer when an uncertain assumption needs a Minimum Viable Experiment before production investment. It coaches problem framing, testable hypotheses, viability checks, and experiment design. Use RPI for implementing a sufficiently understood change rather than treating experimental uncertainty as an implementation plan.

## How to use it

1. Select `Experiment Designer` and describe the problem, decision at stake, prior evidence, and constraints.
2. Refine the hypotheses and evaluate whether the experiment can produce useful evidence within the available access, time, and ownership boundaries.
3. Define the minimum test, measurements, success and failure criteria, and next actions for either result.
4. Review the complete experiment plan. For collaborative engagements, include how the partner team will reproduce and own the result; a plan is not an executed experiment.

## Example usage

Ask: "Help design an experiment to determine whether caching can meet our report-latency target. We have a sanitized workload sample and one test environment. Challenge the hypothesis and define what result would stop the investment."

Expect context, hypotheses, viability findings, and a bounded test plan with decision criteria. Success means both positive and negative results lead to a defined next decision, rather than an open-ended prototype.
