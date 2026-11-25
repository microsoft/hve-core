---
title: Git/Code Review Telemetry
description: Check telemetry evidence in code-review reports
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - instruction
  - git
  - git/code-review-telemetry
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                   |
|-------------|-------------------------------------------------------------------------|
| Kind        | instruction                                                             |
| Source      | `.github/instructions/git/code-review-telemetry.instructions.md`        |
| Invocation  | Applied automatically to `**/.copilot-tracking/reviews/code-reviews/**` |
| Interactive | No                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Check telemetry evidence in code-review reports
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this instruction when reviewing code changes and writing code-review
reports under `.copilot-tracking/reviews/code-reviews/`. It ensures production
code paths that emit logs, metrics, or traces cite a semantic-convention
reference rather than introducing unverified telemetry names. Use
`telemetry-overlay` and `telemetry-foundations` alongside it for shared
attribute naming and PII rules; skip it when reviewed changes do not emit
telemetry.

## Example usage

Open or update a review report at
`.copilot-tracking/reviews/code-reviews/2026-11-24-checkout-review.md` while
reviewing a pull request that adds a custom counter metric. Copilot applies the
instruction automatically and flags any new production emitter that lacks a
semantic-convention reference in `telemetry-foundations`, prompting you to link
the convention or record a proposed addition before approving the change.
