---
title: engagement-report-council-critique
description: Run one independent Council critique against engagement-report research evidence. Use as the manual separate-session fallback when independent critic agents are unavailable.
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - engagement-reporting
  - engagement-report-council-critique
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                             |
|-------------|-------------------------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                                             |
| Source      | `.github/skills/engagement-reporting/engagement-report-council-critique`                                          |
| Invocation  | Invoked directly as `/engagement-report-council-critique`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run one independent Council critique against engagement-report research evidence. Use as the manual separate-session fallback when independent critic agents are unavailable.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to run an independent Council critique manually when isolated
subagent runs are unavailable. Run it in at least two separate model sessions
with the same draft and research evidence, but do not expose one critique to
another.

Use the Engagement Report Reviewer when only one independent review is needed.

## How to use it

1. Prepare the draft, research findings, coverage summary, audience, and
   selected template.
2. Start a separate model session for each critic.
3. Run `/engagement-report-council-critique` with the prepared inputs, the
   reporting date, the report-type slug, and a unique critic-run slug. The
   skill derives the confined critique path. Confirm effective-ignore
   protection for `.working/` before the invocation.
4. Save each critique independently.
5. Provide at least two completed critiques to the Council Arbiter.

## Example usage

```text
/engagement-report-council-critique report-date=2026-08-28 report-type=weekly critic-run=critic-2
audience="customer steering committee" draft=[draft content]
research=[normalized findings] coverage=[coverage record] template=[selected template]
Effective-ignore protection for .working/: confirmed
```

The skill returns evidence-linked accuracy, completeness, proportion,
directionality, privacy, terminology, and continuity findings without rewriting
the report.
