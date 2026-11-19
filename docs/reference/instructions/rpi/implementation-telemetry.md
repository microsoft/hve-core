---
title: Rpi/Implementation Telemetry
description: Check new telemetry emitters before completing an implementation step
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - rpi
  - rpi/implementation-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | instruction                                                                             |
| Source      | `.github/plugins/rpi-builder/instructions/rpi/implementation-telemetry.instructions.md` |
| Invocation  | Applied automatically to `**/.copilot-tracking/changes/**`                              |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Check new telemetry emitters before completing an implementation step
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when recording implementation changes under
`.copilot-tracking/changes/`. It prompts you to verify every newly added
telemetry emitter and its attributes against `telemetry-foundations` before
marking an implementation step complete. Use `code-review-telemetry` during
subsequent code review; skip emitter checks when an implementation step adds no
telemetry instrumentation.

## Example usage

While updating `.copilot-tracking/changes/2026-11-24-retry-backoff-changes.md`
after instrumenting HTTP retry attempts, Copilot applies the instruction and
verifies that each new span and attribute name matches `telemetry-foundations`
and omits sensitive request headers before marking the task complete.
