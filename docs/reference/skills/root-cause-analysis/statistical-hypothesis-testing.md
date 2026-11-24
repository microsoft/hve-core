---
title: statistical-hypothesis-testing
description: Compare binary rates or average values across affected and unaffected cohorts during root cause analysis. Use when root-cause-analysis selects an applicable affected-versus-unaffected cohort comparison.
sidebar_position: 3
author: Microsoft
ms.date: 2026-10-19
ms.topic: reference
keywords:
  - skill
  - root-cause-analysis
  - statistical-hypothesis-testing
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                               |
|-------------|---------------------------------------------------------------------|
| Kind        | skill                                                               |
| Source      | `.github/skills/root-cause-analysis/statistical-hypothesis-testing` |
| Invocation  | Loaded on demand by referencing agents                              |
| Interactive | No                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compare binary rates or average values across affected and unaffected cohorts during root cause analysis. Use when root-cause-analysis selects an applicable affected-versus-unaffected cohort comparison.
<!-- END AUTO-GENERATED: overview -->

## When to use it

This internal companion is loaded only when a
[root-cause-analysis](./) investigation has independent affected and unaffected
cohorts and one consistently defined binary outcome or finite numeric observation per instance.
The root workflow supplies the investigation and test IDs, scope, authorization, prepared input
and hash, cohort definitions, observation rule, and requested result. The companion compares binary
rates with an unconditional exact two-sample binomial test or its controlled fallback and compares
meaningful averages with Welch's independent-samples t-test.

Do not invoke it directly or use it for duplicated, paired, repeated, censored, dependent, or
outcome-selected observations. It fails closed without the internal invocation context. The result
informs the RCA evidence assessment but does not establish causality or set a hypothesis
disposition by itself.

A qualified human reviewer must validate cohort definitions, execution provenance, assumptions,
and limitations before the result informs a postmortem or corrective action. Do not use this skill
as the sole basis for legal, safety, regulatory, or individual-performance determinations.

## Example usage

```text
The root RCA workflow loads this companion for RCA-007 and T-012 with the approved runtime call,
source and prepared-input locators, input SHA-256 hash, and complete cohort definitions. The
prepared table contains 18 independent instances assigned to the incident-affected deployment and
20 comparable instances assigned to an unaffected deployment. Deployment impact was established
before timeout values were inspected.
```

The skill returns the cohort definitions, selected test, exact runtime invocation and parameters,
sample sizes, rates or summary statistics, test statistic, p-value or certified p-value interval,
limitations, and a non-causal conclusion for the RCA record.
