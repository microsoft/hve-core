---
title: c4-architecture
description: "Model and document existing or planned software architectures with the C4 model across System Context, Container, and Component levels plus deployment diagrams, then emit diagrams through a selected renderer. Use when an architect needs audience-appropriate software architecture documentation; use the 'architecture-diagrams' skill for infrastructure topology."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-17
ms.topic: reference
keywords:
  - skill
  - hve-core
  - c4-architecture
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | skill                                                                             |
| Source      | `.github/skills/hve-core/c4-architecture`                                         |
| Invocation  | Invoked directly as `/c4-architecture`, or loaded on demand by referencing agents |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Model and document existing or planned software architectures with the C4 model across System Context, Container, and Component levels plus deployment diagrams, then emit diagrams through a selected renderer. Use when an architect needs audience-appropriate software architecture documentation; use the 'architecture-diagrams' skill for infrastructure topology.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use it to document how a software system is composed, from either existing code or a planned design. It emits System Context, Container, and Component diagrams by default; Code only on request, and Deployment only when the evidence describes where containers run.

Use `architecture-diagrams` instead for cloud infrastructure topology. Requests for an unsupported renderer stop with a reported limitation.

## Example usage

```text
/c4-architecture Document the architecture of the ordering service in this repo,
including a code-level view of the pricing logic.
```

The skill either returns the diagrams with source-validation and renderer-specific validation statuses, or stops and asks when the available evidence does not establish ownership or the system boundary.
