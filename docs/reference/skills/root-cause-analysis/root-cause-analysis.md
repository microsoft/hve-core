---
title: root-cause-analysis
description: "Investigate incidents, software defects, and data or process failures by forming falsifiable hypotheses, executing tests against available evidence, and iterating to a verified causal explanation or an explicit evidence blocker. Use for root cause analysis, incident investigation, and postmortems."
sidebar_position: 2
author: Microsoft
ms.date: 2026-10-15
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

Use the [incident-response](../security/incident-response) skill instead when you need
the broader operational workflow of triage, diagnosis, mitigation, communication, and
post-incident documentation. Use an ordinary debugging workflow for a localized defect whose cause
is already reproducible and does not require competing hypotheses or evidence-source analysis.

Results, including a `Complete` status, are AI-assessed and need validation by a qualified human
reviewer before adoption. Do not use the output as the sole basis for regulatory incident reports,
safety determinations, legal conclusions, or evaluating an individual's performance or conduct.

Install and govern the skill with the bundled `references/setup-and-governance.md` guidance. The
[statistical-hypothesis-testing](statistical-hypothesis-testing) and
[causal-evidence-likelihood](causal-evidence-likelihood) companion skills provide bounded
assessments but do not set RCA dispositions. They are internal-only capabilities that fail closed
without an invocation context from this root workflow.

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
