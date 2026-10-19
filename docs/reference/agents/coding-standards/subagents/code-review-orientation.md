---
title: Code Review Orientation
description: Builds the factual Register 1 walkthrough and dispatch-board appendices for a serialized Code Review target
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-25
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-orientation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | agent                                                                        |
| Source      | `.github/agents/coding-standards/subagents/code-review-orientation.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)     |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Builds the factual Register 1 walkthrough and dispatch-board appendices for a serialized Code Review target
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Orientation before the user chooses deeper review work. It explains the serialized change and prepares a dispatch board in factual language. It is an orientation stage, not a findings perspective or a directly selected agent.

## Example usage

The parent supplies `task.kind=orientation`, an exact `task.outputPath`, a verified review target, and the precomputed diff. For an importer change, the worker maps entry points, data flow, affected areas, and questions worth inspecting. It writes the walkthrough only to that output and returns its path and area count, without assigning severity or declaring the change correct.
