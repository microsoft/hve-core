---
title: PowerPoint Subagent
description: "Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - experimental
  - pptx-subagent
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/experimental/subagents/pptx-subagent.agent.md`           |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation
<!-- END AUTO-GENERATED: overview -->

## When to use it

PowerPoint Builder dispatches this worker for a specific extraction, content, build, validation, or export operation. It uses the PowerPoint skill within the assigned working paths and returns execution evidence. Users coordinate the presentation through the parent rather than invoking the worker directly.

## Example usage

The parent supplies `task type=build-deck`, content and style YAML, an exact output PPTX path, and an execution-log path. The worker builds the assigned deck and returns output and execution details for parent validation. It does not launch another subagent, invent missing content decisions, or continue a dependent operation after a blocking failure.
