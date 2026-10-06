---
title: Security Capture
description: Start security planning from existing notes using the Security Planner agent (capture mode)
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-capture
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | prompt                                                |
| Source      | `.github/prompts/security/security-capture.prompt.md` |
| Invocation  | Slash command `/security-capture`                     |
| Interactive | Yes                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start security planning from existing notes using the Security Planner agent (capture mode)
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to start security planning from existing notes or team knowledge when no confirmed PRD or BRD handoff is available. Use the from-PRD prompt when requirements artifacts can provide the initial scope.

## How to use it

Provide an approved or fictional `project-slug` when useful, then answer focused discovery questions about the system, data, boundaries, and dependencies. Treat the resulting plan as AI-assisted evidence that requires qualified security review.

## Example usage

```text
/security-capture project-slug=sample-api
```

The prompt begins capture-mode discovery and creates a draft security-planning state for the sample service.
