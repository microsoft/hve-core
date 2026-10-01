---
title: Experimental/Mural/Mural Log Hygiene
description: "Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log."
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - experimental
  - experimental/mural/mural-log-hygiene
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

Apply these rules whenever Mural commands, customizations, diagnostics, or
network evidence could expose URLs, headers, tokens, authorization codes, or
Azure SAS values. Use only redacted evidence outside the terminal and treat
the skill's redaction helper as defense in depth, not permission to log raw
traffic.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
