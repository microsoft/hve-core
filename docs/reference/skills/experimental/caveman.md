---
title: caveman
description: "Ultra-compressed response style that reduces output token count while preserving technical accuracy, with intensity levels and auto-clarity safety rules"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - experimental
  - caveman
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                  |
|-------------|----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                  |
| Source      | `.github/skills/experimental/caveman`                                                  |
| Invocation  | Invoked directly as `/caveman`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Ultra-compressed response style that reduces output token count while preserving technical accuracy, with intensity levels and auto-clarity safety rules
<!-- END AUTO-GENERATED: overview -->

## When to use it

Invoke Caveman explicitly when you want compressed assistant prose across the
current conversation. `lite` keeps full sentences, `full` permits fragments,
`ultra` is telegraphic, and `wenyan` adds a Classical Chinese register. A generic
"be brief" request does not activate the mode, and agents do not select it on
their own.

This changes output style, not code or reasoning-token usage. Security warnings,
destructive-action confirmations, quoted tool output, and ambiguous instructions
temporarily return to normal clarity.

## Example usage

Enter `/caveman lite`, then ask for a summary of a supplied test failure. Expect a
short explanation with the exact test name, error text, and command arguments
preserved. Switch with `/caveman ultra` if fragments remain clear, or use
`/caveman off` to restore normal responses.

Success is less prose without lost technical meaning. Generated code, commit
messages, PR bodies, and release notes stay in normal style. The latest visible
activation or exit directive governs the mode; it has no state file and resets
when the relevant conversation context is gone. If you ask for clarification,
clarity takes precedence over compression.
