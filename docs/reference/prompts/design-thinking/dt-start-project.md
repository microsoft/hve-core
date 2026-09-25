---
title: Dt Start Project
description: Start a new Design Thinking coaching project with state initialization and first coaching interaction
sidebar_position: 15
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-start-project
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | prompt                                                       |
| Source      | `.github/prompts/design-thinking/dt-start-project.prompt.md` |
| Invocation  | Slash command `/dt-start-project`                            |
| Interactive | Yes                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start a new Design Thinking coaching project with state initialization and first coaching interaction
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to initialize a new Design Thinking coaching project and begin the first method. Use the resume prompt when durable project state already exists.

## How to use it

Provide an optional `project-slug`, or let the prompt derive one from your context or ask for a short project name. You can also provide context, stakeholders, and industry. The prompt creates the project state and starts the first coaching interaction from that context.

## Example usage

```text
/dt-start-project context="Reduce maintenance delays on the factory floor" industry=manufacturing
```

The prompt initializes the project and begins Method 1 coaching for the manufacturing scenario.
