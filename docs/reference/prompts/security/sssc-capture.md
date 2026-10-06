---
title: Sssc Capture
description: Start supply chain security planning from existing knowledge using the SSSC Planner agent in capture mode
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - sssc-capture
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                             |
|-------------|---------------------------------------------------|
| Kind        | prompt                                            |
| Source      | `.github/prompts/security/sssc-capture.prompt.md` |
| Invocation  | Slash command `/sssc-capture`                     |
| Interactive | Yes                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start supply chain security planning from existing knowledge using the SSSC Planner agent in capture mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to begin software supply chain security planning from existing notes or team knowledge. Use a BRD, PRD, or security-plan entry prompt when a confirmed source artifact is available.

## How to use it

Provide an approved or fictional `project-slug` and answer focused questions about dependencies, builds, registries, signing, and release controls. Keep sensitive infrastructure details out of examples and require qualified security review.

## Example usage

```text
/sssc-capture project-slug=sample-api
```

The prompt starts capture-mode discovery and creates a draft supply chain security planning state.
