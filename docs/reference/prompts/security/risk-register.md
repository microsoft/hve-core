---
title: risk-register
description: Create a qualitative risk register using a Probability × Impact (P×I) matrix
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - risk-register
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | prompt                                             |
| Source      | `.github/prompts/security/risk-register.prompt.md` |
| Invocation  | Slash command `/risk-register`                     |
| Interactive | Yes                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create a qualitative risk register using a Probability × Impact (P×I) matrix
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to create a qualitative project risk register using probability and impact. Use quantitative risk analysis when monetary exposure, distributions, or statistically supported forecasts are required.

## How to use it

Provide the `project-name` and optionally a `focus-area`. Review the proposed risks, scores, owners, and mitigations with qualified stakeholders; generated ratings are draft inputs, not risk acceptance decisions.

## Example usage

```text
/risk-register project-name="sample checkout service" focus-area="availability"
```

The prompt drafts an availability-focused risk register for stakeholder review.
