---
title: Dt Method 06 Testing
description: Hypothesis-driven testing and constraint validation for Design Thinking Method 6c
sidebar_position: 12
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-06-testing
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                            |
|-------------|------------------------------------------------------------------|
| Kind        | prompt                                                           |
| Source      | `.github/prompts/design-thinking/dt-method-06-testing.prompt.md` |
| Invocation  | Slash command `/dt-method-06-testing`                            |
| Interactive | Yes                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Hypothesis-driven testing and constraint validation for Design Thinking Method 6c
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 6c to plan and conduct hypothesis-driven prototype testing. Use the building prompt first when no testable low-fidelity prototype exists.

## How to use it

Provide the `project-slug` and optionally describe the `testEnvironment`. The prompt frames observable hypotheses, guides evidence collection, and records constraints without treating planned or simulated observations as proof.

## Example usage

```text
/dt-method-06-testing project-slug=factory-floor-maintenance testEnvironment="factory floor"
```

The prompt creates a test approach and observation record for the prototype in the named environment.
