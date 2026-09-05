---
title: Sssc From Brd
description: Start supply chain security planning from BRD artifacts using the SSSC Planner agent in from-brd mode
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - sssc-from-brd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | prompt                                             |
| Source      | `.github/prompts/security/sssc-from-brd.prompt.md` |
| Invocation  | Slash command `/sssc-from-brd`                     |
| Interactive | Yes                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start supply chain security planning from BRD artifacts using the SSSC Planner agent in from-brd mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a confirmed BRD should seed software supply chain security planning. Use capture mode when the business requirements are missing or do not provide enough delivery and dependency context.

## How to use it

Provide an approved or fictional `project-slug`. The SSSC Planner discovers the BRD, extracts relevant evidence, and asks focused questions for supply-chain gaps without assuming the business document is complete security evidence.

## Example usage

```text
/sssc-from-brd project-slug=sample-api
```

The prompt initializes a draft supply chain security plan from the BRD or falls back to capture questions.
