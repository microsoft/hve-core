---
title: engagement-report-council-critique
description: Template prompt for running one independent Council critique against research evidence
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - prompt
  - engagement-reporting
  - engagement-report-council-critique
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | prompt                                                                              |
| Source      | `.github/prompts/engagement-reporting/engagement-report-council-critique.prompt.md` |
| Invocation  | Slash command `/engagement-report-council-critique`                                 |
| Interactive | Yes                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Template prompt for running one independent Council critique against research evidence
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to run an independent Council critique manually when isolated
subagent runs are unavailable. Run it in at least two separate model sessions
with the same draft and research evidence, but do not expose one critique to
another.

Use the Engagement Report Reviewer when only one independent review is needed.

## How to use it

1. Prepare the draft, research findings, coverage summary, audience, and
   selected template.
2. Start a separate model session for each critic.
3. Invoke `/engagement-report-council-critique` and append the prepared inputs,
   reporting date, report-type slug, and a unique critic-run slug. The prompt
   derives the confined critique path. Confirm effective-ignore protection for
   `.working/` before the invocation.
4. Save each critique independently.
5. Provide at least two completed critiques to the Council Arbiter.

## Example usage

```text
/engagement-report-council-critique
Report date: 2026-08-28
Report type: weekly
Critic run: critic-2
Audience: customer steering committee
Draft: [draft content]
Research findings: [normalized findings]
Coverage summary: [coverage record]
Effective-ignore protection for .working/: confirmed
```

The prompt returns evidence-linked accuracy, completeness, proportion,
directionality, privacy, terminology, and continuity findings without rewriting
the report.
