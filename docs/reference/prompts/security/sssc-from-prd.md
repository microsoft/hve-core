---
title: Sssc From Prd
description: Start supply chain security planning from PRD artifacts using the SSSC Planner agent in from-prd mode
sidebar_position: 11
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - sssc-from-prd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | prompt                                             |
| Source      | `.github/prompts/security/sssc-from-prd.prompt.md` |
| Invocation  | Slash command `/sssc-from-prd`                     |
| Interactive | Yes                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start supply chain security planning from PRD artifacts using the SSSC Planner agent in from-prd mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a confirmed PRD should seed software supply chain security planning. Use capture mode when product requirements are unavailable or omit the dependency, build, and release context needed for assessment.

## How to use it

Provide an approved or fictional `project-slug`. The SSSC Planner discovers the PRD, extracts applicable evidence, and asks focused questions for unresolved supply-chain controls while preserving qualified-review ownership.

## Example usage

```text
/sssc-from-prd project-slug=sample-api
```

The prompt creates a draft supply chain security plan from product requirements or records the missing evidence.
