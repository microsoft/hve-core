---
title: Security Plan From Prd
description: Start security planning from PRD/BRD artifacts using the Security Planner agent (from-prd mode)
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-plan-from-prd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | prompt                                                      |
| Source      | `.github/prompts/security/security-plan-from-prd.prompt.md` |
| Invocation  | Slash command `/security-plan-from-prd`                     |
| Interactive | Yes                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start security planning from PRD/BRD artifacts using the Security Planner agent (from-prd mode)
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a confirmed PRD or BRD should seed security planning. Use capture mode when no current requirements artifact can be found or when it lacks enough system context.

## How to use it

Provide an approved or fictional `project-slug`. The Security Planner discovers the requirements artifact, extracts relevant evidence, asks for missing security context, and keeps the resulting plan subject to qualified review.

## Example usage

```text
/security-plan-from-prd project-slug=sample-api
```

The prompt initializes a draft security plan from available requirements or falls back to focused capture questions.
