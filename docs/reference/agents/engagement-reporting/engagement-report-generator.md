---
title: Engagement Report Generator
description: "Coordinates source-grounded engagement reports, review, optional Council critique, and Outlook draft creation."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-25
ms.topic: reference
keywords:
  - agent
  - engagement-reporting
  - engagement-report-generator
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/engagement-reporting/engagement-report-generator.agent.md` |
| Invocation  | Selected from the chat agent picker as `Engagement Report Generator`       |
| Interactive | Yes                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinates source-grounded engagement reports, review, optional Council critique, and Outlook draft creation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this agent to coordinate a weekly engagement report from source discovery
through review and approval. It is the right entry point when the report may
need WorkIQ research, board evidence, independent review, Council critique, or
optional Outlook draft creation.

Use the `engagement-reporting` skill directly when another agent already owns
the user interaction and only needs the reporting workflow.

## How to use it

1. Create `engagement.yaml` from the packaged template and configure the
   engagement, stakeholders, sources, and distribution preferences.
2. Select **Engagement Report Generator** from the agent picker.
3. Provide the report type and reporting period, such as `weekly, August
   17-21`.
4. Confirm the audience and available evidence sources.
5. Review the generated draft and resolve any coverage or verification gaps.
6. Approve the report. If Outlook distribution is enabled, approve draft
   creation separately.

## Example usage

```text
Create the customer-facing weekly report for August 17-21 using our configured
M365 and Azure DevOps sources. Keep the standard weekly format and flag any
claims that lack primary-source support.
```

The agent gathers the configured evidence, prepares the report and talk track,
runs the appropriate review gate, and returns the approved output paths,
coverage gaps, unresolved claims, and retention action. Outlook distribution
uses validated HTML and stops rather than flattening a report when conversion
cannot preserve required structures.
