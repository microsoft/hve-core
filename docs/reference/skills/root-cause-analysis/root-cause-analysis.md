---
title: root-cause-analysis
description: "Investigate incidents, software defects, and data or process failures by forming falsifiable hypotheses, executing tests against available evidence, and iterating to a verified causal explanation or an explicit evidence blocker. Use for root cause analysis, incident investigation, and postmortems."
sidebar_position: 2
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - root-cause-analysis
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                 |
|-------------|---------------------------------------------------------------------------------------|
| Kind        | skill                                                                                 |
| Source      | `.github/skills/root-cause-analysis/root-cause-analysis`                              |
| Invocation  | Invoked directly as `/root-cause-analysis`, or loaded on demand by referencing agents |
| Interactive | No                                                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Investigate incidents, software defects, and data or process failures by forming falsifiable hypotheses, executing tests against available evidence, and iterating to a verified causal explanation or an explicit evidence blocker. Use for root cause analysis, incident investigation, and postmortems.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to investigate an incident, software defect, or data or process failure when the
cause is not yet established. It is appropriate when evidence can be gathered or supplied,
competing explanations need to be tested, and the result must distinguish a verified cause from a
provisional or blocked investigation.

Use the incident-response prompt instead when you need the broader operational workflow of triage,
diagnosis, mitigation, communication, and post-incident documentation. Use an ordinary debugging
workflow for a localized defect whose cause is already reproducible and does not require competing
hypotheses or evidence-source analysis.

## Example usage

```text
Use the root-cause-analysis skill to investigate why checkout requests began timing out after
14:20 UTC. Compare affected and unaffected instances, examine the deployed change history, and
test at least one competing explanation. Keep the investigation read-only and return a resumable
checkpoint if the completion gate cannot pass.
```

The skill returns the investigation status, source coverage, hypotheses, executed tests, evidence,
causal account, completion-gate assessment, cause-linked actions, and a resume checkpoint when the
result is not complete.
