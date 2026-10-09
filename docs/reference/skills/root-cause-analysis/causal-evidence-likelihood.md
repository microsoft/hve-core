---
title: causal-evidence-likelihood
description: "Assess how one evidence item changes an RCA hypothesis using an uncalibrated, model-elicited likelihood-ratio band. Use through the root-cause-analysis workflow."
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-07
ms.topic: reference
keywords:
  - skill
  - root-cause-analysis
  - causal-evidence-likelihood
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                        |
|-------------|----------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                        |
| Source      | `.github/skills/root-cause-analysis/causal-evidence-likelihood`                              |
| Invocation  | Invoked directly as `/causal-evidence-likelihood`, or loaded on demand by referencing agents |
| Interactive | No                                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assess how one evidence item changes an RCA hypothesis using an uncalibrated, model-elicited likelihood-ratio band. Use through the root-cause-analysis workflow.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this companion skill when the RCA workflow selects one statistically significant,
direction-supporting hypothesis-evidence pair for causal relevance assessment. It is appropriate
when the evidence observation, provenance, reliability, proposed mechanism, and plausible
alternatives can be stated independently of the statistical result.

Do not use it to repeat statistical inference, combine dependent evidence, or assign the RCA
hypothesis disposition. Return `Not Assessed` when evidence provenance or meaning is too uncertain
to support the comparison.

## Example usage

```text
Assess whether E-014 supports H-003: a connection leak in release R exhausted the client pool.
E-014 directly observes pool-wait growth before request timeouts on release R, while database
execution latency remained near baseline. Consider delayed telemetry and an unrelated workload
surge as alternatives. Do not use the statistical-test output in this assessment.
```

The skill returns the rationales for the evidence under the hypothesis and its negation, direction,
likelihood-ratio band, representative value when defensible, standardized relevance estimate,
reasoning confidence, dependence notes, and the next observation that would best calibrate the
assessment.
