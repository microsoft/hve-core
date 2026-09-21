---
title: Accessibility Surface Inventory
description: "Discovers runtime surfaces and interaction states from a codebase profile, then emits an accessibility runtime config for the harness"
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - accessibility
  - accessibility-surface-inventory
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | agent                                                                             |
| Source      | `.github/agents/accessibility/subagents/accessibility-surface-inventory.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)          |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Discovers runtime surfaces and interaction states from a codebase profile, then emits an accessibility runtime config for the harness
<!-- END AUTO-GENERATED: overview -->

## When to use it

An accessibility workflow dispatches this worker to translate a codebase profile into routes, surfaces, and interaction states for runtime probes. It produces a reviewable runtime configuration rather than a conformance verdict. Its discovered scope still needs human review where routes or states cannot be inferred reliably.

## Example usage

The parent supplies a UI profile, route focus, and configuration output path for a booking application. The worker emits `a11y-runtime.config.json` with supported serve settings and probe scope, then returns a surface/state summary and open questions. Success means downstream probes have an explicit target set; undiscovered or unreachable states are not counted as tested.
