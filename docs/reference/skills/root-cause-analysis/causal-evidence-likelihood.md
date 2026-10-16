---
title: causal-evidence-likelihood
description: "Assess how one evidence item changes an RCA hypothesis using an uncalibrated, model-elicited likelihood-ratio band. Use through the root-cause-analysis workflow."
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-15
ms.topic: reference
keywords:
  - skill
  - root-cause-analysis
  - causal-evidence-likelihood
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                           |
|-------------|-----------------------------------------------------------------|
| Kind        | skill                                                           |
| Source      | `.github/skills/root-cause-analysis/causal-evidence-likelihood` |
| Invocation  | Loaded on demand by referencing agents                          |
| Interactive | No                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assess how one evidence item changes an RCA hypothesis using an uncalibrated, model-elicited likelihood-ratio band. Use through the root-cause-analysis workflow.
<!-- END AUTO-GENERATED: overview -->

## When to use it

This internal companion is loaded only when the
[root-cause-analysis](./) workflow selects one eligible hypothesis-evidence pair
for causal relevance assessment. It is appropriate when the root workflow provides a complete
invocation context containing the investigation, hypothesis, and evidence IDs; evidence class;
observation; provenance; reliability; system context; and plausible alternatives independently of
any statistical result.

Do not invoke it directly, repeat statistical inference, combine dependent evidence, or assign the
RCA hypothesis disposition. It fails closed without the internal invocation context. Return
`Unassessed` when evidence provenance or meaning is too uncertain to support the comparison.

The likelihood band is an uncalibrated, model-elicited judgment, not a measured probability that a
cause is real. A qualified human reviewer must validate the evidence interpretation before the
assessment informs a postmortem or corrective action. Do not use this skill for legal, safety,
regulatory, or individual-performance determinations.

## Example usage

```text
The root RCA workflow loads this companion for investigation RCA-007, H-003, and Confirmatory
E-014. E-014 directly observes pool-wait growth before request timeouts on release R, while
database execution latency remained near baseline. Its source provenance, reliability,
classification rationale, system context, and alternatives accompany the request. Statistical
test output is withheld from the causal assessment.
```

The skill returns the rationales for the evidence under the hypothesis and its negation, direction,
likelihood-ratio band, standardized relevance estimate, reasoning confidence, dependence notes,
and the next observation that would best calibrate the assessment. The assessment inherits the
evidence class but is not a second observation or independent corroboration.
