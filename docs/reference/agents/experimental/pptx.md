---
title: PowerPoint Builder
description: "Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx"
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - experimental
  - pptx
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | agent                                                       |
| Source      | `.github/agents/experimental/pptx.agent.md`                 |
| Invocation  | Selected from the chat agent picker as `PowerPoint Builder` |
| Interactive | Yes                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use PowerPoint Builder to create or update a presentation from supplied content, topic evidence, or an existing deck. It coordinates YAML-based content and style with extraction, build, and validation workers. Use a documentation workflow when you need a written reference rather than slides.

## How to use it

1. Select `PowerPoint Builder` and supply the audience, purpose, sources, style constraints, and any existing presentation.
2. Review the content and structure derived from research or extraction before the build.
3. Inspect the generated presentation and validation findings. A blocked extraction or build stops dependent work; slide count and file integrity are checked before visual validation.
4. Specify any final delivery destination explicitly. Delivery follows validation and applicable overwrite confirmation, not an assumed shared location.

## Example usage

Ask: "Create a short onboarding presentation from `docs/onboarding.md`. Keep the audience focused on new contributors, include speaker notes, and show me validation findings before delivering a final copy."

Expect content and style definitions, a generated presentation, and validation evidence. Success means the deck matches the supplied narrative and layout constraints; a successful build alone does not establish visual quality.
