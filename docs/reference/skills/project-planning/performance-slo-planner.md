---
title: performance-slo-planner
description: "Performance, load, and reliability (SLO/SRE) planning for production readiness. Use when defining service level objectives, load characterization, capacity, latency budgets, stress/soak/spike test plans, false-positive baselines, and reliability targets. USE FOR: SLO/SLA definition, load testing plan, performance budget, capacity planning, reliability/SRE backlog, latency targets, error-budget policy. DO NOT USE FOR: executing load tests (use Azure Load Testing tooling), security threat modeling, RAI assessment, privacy/compliance planning, or authoring/restating PRD requirements (cite the PRD's existing NFR/FR ids instead)."
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - performance-slo-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                     |
|-------------|-------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                     |
| Source      | `.github/skills/project-planning/performance-slo-planner`                                 |
| Invocation  | Invoked directly as `/performance-slo-planner`, or loaded on demand by referencing agents |
| Interactive | No                                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Performance, load, and reliability (SLO/SRE) planning for production readiness. Use when defining service level objectives, load characterization, capacity, latency budgets, stress/soak/spike test plans, false-positive baselines, and reliability targets. USE FOR: SLO/SLA definition, load testing plan, performance budget, capacity planning, reliability/SRE backlog, latency targets, error-budget policy. DO NOT USE FOR: executing load tests (use Azure Load Testing tooling), security threat
modeling, RAI assessment, privacy/compliance planning, or authoring/restating PRD requirements (cite the PRD's existing NFR/FR ids instead).
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill before a production-readiness review when latency, availability,
capacity, or error-budget expectations need measurable indicators and a test plan.
Bring BRD goals, existing PRD journey and NFR identifiers, traffic assumptions, and
accuracy expectations where relevant. It plans performance work; it does not run
load tests or redefine the PRD.

Hand the resulting test matrix to execution tooling separately. Security,
privacy, and RAI assessments remain specialist work, and the owning team must
review targets, budgets, and rollback triggers before use.

## Example usage

Ask: `/performance-slo-planner Plan for the sample PRD's FR-101 order submission
journey and NFR-201 p95 latency target of 500 ms. Assume 40 requests per second
normally and a peak of 200; do not execute tests.` These numbers are illustrative
inputs, not recommended defaults.

Expect an SLI/SLO table with measurement windows and error budgets, steady/peak/
spike/soak load profiles, a test matrix, observability hooks, and a dependency-aware
reliability backlog. Supplied NFRs remain the target authority; newly proposed
numbers are labeled `ASSUMPTION` for validation.

Success means every planned threshold has a journey, evidence source, and way to
measure it, with saturation and graceful-degradation assumptions visible. A
completed plan does not show that the service achieved the target or passed a
load test; retain the professional performance/SRE review caution.
