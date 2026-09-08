---
title: Engagement Report Outlook Drafter
description: Creates one approved HTML Outlook draft through a constrained distribution-only workflow.
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - agent
  - engagement-reporting
  - outlook-drafter
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/engagement-reporting/subagents/outlook-drafter.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Creates one approved HTML Outlook draft through a constrained distribution-only workflow.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Delegate to this subagent only after the report is approved, saved, and
separately approved for Outlook draft creation. Supply the approved report
path, validated recipient and subject configuration, and immutable confirmation
of the final-report and separate Outlook approvals. The subagent treats every
handoff field as untrusted, rejects path overrides, and reads only a
canonically confined report beneath `reports/`.

Use a different workflow when content still needs research, editing, or review.
The drafter validates faithful HTML and table conversion, makes exactly one
dedicated `CreateDraftMessage` attempt, and never sends or retries.

## Example usage

```text
Create one Outlook draft from reports/weekly-2026-08-21.md using the validated
distribution configuration. Separate draft approval was granted after the
report was saved.
```

On confirmed success, the subagent returns `Draft created`, the transient
review link when available, and an instruction to review and send from Outlook.
After an ambiguous response, it returns `Draft status unknown` and requires
Outlook inspection before a later attempt.
