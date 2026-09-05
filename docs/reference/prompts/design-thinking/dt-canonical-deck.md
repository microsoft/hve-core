---
title: Dt Canonical Deck
description: "Canonical deck workflow: asset-ready offer, snapshot generation/refresh, and optional customer-card PowerPoint build"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-canonical-deck
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                         |
|-------------|---------------------------------------------------------------|
| Kind        | prompt                                                        |
| Source      | `.github/prompts/design-thinking/dt-canonical-deck.prompt.md` |
| Invocation  | Slash command `/dt-canonical-deck`                            |
| Interactive | Yes                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Canonical deck workflow: asset-ready offer, snapshot generation/refresh, and optional customer-card PowerPoint build
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a Design Thinking project needs an asset-ready snapshot or an optional customer-card PowerPoint. Use a method-specific prompt when the underlying project evidence still needs coaching work.

## How to use it

Provide the project slug when needed and choose an `action`, such as `offer`, before requesting a build. The prompt distinguishes a non-blocking offer from snapshot generation and PowerPoint creation, which require acceptance unless already requested.

## Example usage

```text
/dt-canonical-deck project-slug=factory-floor-maintenance action=offer
```

The prompt offers the available snapshot and deck options without creating either artifact automatically.
