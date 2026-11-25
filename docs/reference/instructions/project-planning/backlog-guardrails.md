---
title: Project Planning/Backlog Guardrails
description: "Require the backlog-management destination, authorization, sanitization, and review controls before a tracker-bound mutation from a backlog tracking root"
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - project-planning
  - project-planning/backlog-guardrails
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                    |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                              |
| Source      | `.github/instructions/project-planning/backlog-guardrails.instructions.md`                                                               |
| Invocation  | Applied automatically to `**/.copilot-tracking/workitems/**, **/.copilot-tracking/github-issues/**, **/.copilot-tracking/jira-issues/**` |
| Interactive | No                                                                                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Require the backlog-management destination, authorization, sanitization, and review controls before a tracker-bound mutation from a backlog tracking root
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this guardrail before any tracker-bound create, update, comment,
transition, close, or payload confirmation originating from backlog tracking
roots. Activate `backlog-management` and stop if it is unavailable; read-only
analysis and local file authoring do not require that mutation contract.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
