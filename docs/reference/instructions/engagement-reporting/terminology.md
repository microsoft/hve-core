---
title: Engagement Reporting/Terminology
description: "Correct spellings and naming conventions for people, products, and teams"
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - engagement-reporting
  - engagement-reporting/terminology
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                                                           |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                                                     |
| Source      | `.github/instructions/engagement-reporting/terminology.instructions.md`                                                                                                         |
| Invocation  | Applied automatically to `**/.github/agents/engagement-reporting/**, **/.github/prompts/engagement-reporting/**, **/.github/skills/engagement-reporting/**, **/engagement.yaml` |
| Interactive | No                                                                                                                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Correct spellings and naming conventions for people, products, and teams
<!-- END AUTO-GENERATED: overview -->

## When to use it

This instruction applies when `engagement.yaml` defines canonical stakeholder,
team, product, or program terminology. It ensures reports and reviews use those
configured names consistently without embedding engagement-specific terms in
the reusable package.

When no terminology is configured, preserve the spellings used by primary
sources.

## Example usage

If `engagement.yaml` maps `Project North Star` and `North-Star` to the canonical
term `North Star`, the report uses `North Star` consistently while leaving the
source record unchanged.
