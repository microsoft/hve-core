---
title: statistical-hypothesis-testing
description: Compare binary rates or average values across affected and unaffected cohorts during root cause analysis.
sidebar_position: 3
author: Microsoft
ms.date: 2026-10-08
ms.topic: reference
keywords:
  - skill
  - root-cause-analysis
  - statistical-hypothesis-testing
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                            |
| Source      | `.github/skills/root-cause-analysis/statistical-hypothesis-testing`                              |
| Invocation  | Invoked directly as `/statistical-hypothesis-testing`, or loaded on demand by referencing agents |
| Interactive | No                                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compare binary rates or average values across affected and unaffected cohorts during root cause analysis.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this companion skill when an RCA has independent affected and unaffected cohorts and one
consistently defined binary outcome or finite numeric observation per instance. It compares binary
rates with an unconditional exact two-sample binomial test or its controlled fallback and compares
meaningful averages with Welch's independent-samples t-test.

Do not use it for duplicated, paired, repeated, censored, dependent, or outcome-selected
observations. The result informs the RCA evidence assessment but does not establish causality or
set a hypothesis disposition by itself.

## Example usage

```text
Compare the timeout rate for 18 instances assigned to the incident-affected deployment with the
timeout rate for 20 comparable instances assigned to an unaffected deployment. Deployment impact
was established from routing and availability records before timeout values were inspected. Each
row represents one independent instance, and the observation is whether at least one timeout
occurred during the same UTC window.
```

The skill returns the cohort definitions, selected test, exact query and parameters, sample sizes,
rates or summary statistics, test statistic, p-value or certified p-value interval, limitations,
and a non-causal conclusion for the RCA record.
