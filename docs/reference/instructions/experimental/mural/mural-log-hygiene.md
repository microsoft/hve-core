---
title: Experimental/Mural/Mural Log Hygiene
description: "Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log."
sidebar_position: 4
ms.date: 2026-07-03
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                                                                                                                                                                                                                  |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                                                                                                                                                                                                            |
| Source      | `.github/instructions/experimental/mural/mural-log-hygiene.instructions.md`                                                                                                                                                                                                                                            |
| Invocation  | Applied automatically to `**/.copilot-tracking/mural/**, **/.github/skills/experimental/mural/**, **/.github/agents/design-thinking/dt-coach.agent.md, **/.github/agents/rai-planning/rai-planner.agent.md, **/.github/agents/project-planning/ux-ui-designer.agent.md, **/.github/instructions/experimental/mural/**` |
| Interactive | No                                                                                                                                                                                                                                                                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.
<!-- END AUTO-GENERATED: overview -->

## When to use it

<!-- asset-docs:stub -->
Describe the situations where this asset is the right choice, and when to reach for a different asset instead.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
