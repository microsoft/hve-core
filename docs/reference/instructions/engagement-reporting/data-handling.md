---
title: Engagement Reporting/Data Handling
description: "Protects sensitive engagement sources, working files, reports, transcripts, and configuration."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-24
ms.topic: reference
keywords:
  - instruction
  - engagement-reporting
  - engagement-reporting/data-handling
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                                                           |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                                                     |
| Source      | `.github/instructions/engagement-reporting/data-handling.instructions.md`                                                                                                       |
| Invocation  | Applied automatically to `**/.github/agents/engagement-reporting/**, **/.github/prompts/engagement-reporting/**, **/.github/skills/engagement-reporting/**, **/engagement.yaml` |
| Interactive | No                                                                                                                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Protects sensitive engagement sources, working files, reports, transcripts, and configuration.
<!-- END AUTO-GENERATED: overview -->

## When to use it

This instruction applies whenever engagement reporting reads M365, board,
document, transcript, configuration, or local working data. It keeps raw
content and unnecessary personal data out of reports, separates working and
final artifacts, and requires explicit approval before Outlook draft creation.

It does not replace an organization's information-protection, retention, or
records-management policies.

## Example usage

When an email thread contains names, addresses, and unrelated discussion, the
workflow records only the minimum source-backed status needed for the report.
It stores working evidence in the ignored `.working/` path and does not invoke
an email send operation.
