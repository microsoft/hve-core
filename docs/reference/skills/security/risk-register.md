---
title: risk-register
description: "Create a qualitative risk register and mitigation plan using a Probability x Impact matrix. Use when a project needs structured risk identification, scoring, ownership, and response planning."
sidebar_position: 11
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - security
  - risk-register
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                        |
|-------------|----------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                        |
| Source      | `.github/skills/security/risk-register`                                                      |
| Invocation  | Invoked directly as `/risk-register`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create a qualitative risk register and mitigation plan using a Probability x Impact matrix. Use when a project needs structured risk identification, scoring, ownership, and response planning.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to create a qualitative project risk register using probability and impact. Use quantitative risk analysis when monetary exposure, distributions, or statistically supported forecasts are required.

## How to use it

Provide the `project-name` and optionally a `focus-area`. Review the proposed risks, scores, owners, and mitigations with qualified stakeholders; generated ratings are draft inputs, not risk acceptance decisions.

## Example usage

```text
/risk-register project-name="sample checkout service" focus-area="availability"
```

The skill drafts an availability-focused risk register for stakeholder review.
