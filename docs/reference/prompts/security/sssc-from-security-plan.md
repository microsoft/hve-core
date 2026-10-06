---
title: Sssc From Security Plan
description: Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent in from-security-plan mode
sidebar_position: 12
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - sssc-from-security-plan
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | prompt                                                       |
| Source      | `.github/prompts/security/sssc-from-security-plan.prompt.md` |
| Invocation  | Slash command `/sssc-from-security-plan`                     |
| Interactive | Yes                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent in from-security-plan mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to extend a completed security plan with dedicated software supply chain coverage. Use another entry mode when no current security plan exists.

## How to use it

Provide an approved or fictional `project-slug`. The SSSC Planner reads the security plan as source evidence, identifies unresolved supply-chain gaps, and asks for dependency, provenance, build, and release details as needed.

## Example usage

```text
/sssc-from-security-plan project-slug=sample-api
```

The prompt traces reusable security evidence and adds a draft supply-chain assessment for qualified review.
