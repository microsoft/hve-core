---
title: Rai Capture
description: Start responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - rai-planning
  - rai-capture
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                |
|-------------|------------------------------------------------------|
| Kind        | prompt                                               |
| Source      | `.github/prompts/rai-planning/rai-capture.prompt.md` |
| Invocation  | Slash command `/rai-capture`                         |
| Interactive | Yes                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to begin Responsible AI assessment planning from existing notes or team knowledge. Use a PRD or security-plan entry prompt when a confirmed source artifact is available.

## How to use it

Provide a fictional or approved `project-slug` and answer the focused discovery questions. The RAI Planner records assessment state and evidence gaps; its output requires qualified professional review before decisions or attestations.

## Example usage

```text
/rai-capture project-slug=customer-support-assistant
```

The prompt starts capture-mode discovery and creates a draft Responsible AI planning record for review.
