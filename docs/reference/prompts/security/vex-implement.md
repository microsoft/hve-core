---
title: vex-implement
description: "Plan the work to stand up VEX in a target project as a backlog for Task-* implementors - Brought to you by microsoft/hve-core"
sidebar_position: 13
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - vex-implement
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | prompt                                             |
| Source      | `.github/prompts/security/vex-implement.prompt.md` |
| Invocation  | Slash command `/vex-implement`                     |
| Interactive | Yes                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Plan the work to stand up VEX in a target project as a backlog for Task-* implementors - Brought to you by microsoft/hve-core
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to plan the backlog needed to establish VEX generation and management in a target project. Use vex-scan for an existing project that is ready to scan and draft a VEX document now.

## How to use it

Optionally provide the project `scope` and product package URL. The prompt plans and delegates implementation work; it does not publish VEX statements or replace the product's qualified author of record.

## Example usage

```text
/vex-implement scope=packages/api product=pkg:npm/@example/sample-api
```

The prompt creates a reviewable backlog for adding VEX capabilities to the fictional package.
