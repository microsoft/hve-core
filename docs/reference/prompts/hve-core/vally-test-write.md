---
title: Vally Test Write
description: "Authors Vally conformance test stimuli for an existing prompt, instructions, agent, or skill artifact"
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - vally-test-write
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | prompt                                                |
| Source      | `.github/prompts/hve-core/vally-test-write.prompt.md` |
| Invocation  | Slash command `/vally-test-write`                     |
| Interactive | Yes                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Authors Vally conformance test stimuli for an existing prompt, instructions, agent, or skill artifact
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to add benign Vally conformance stimuli for an existing prompt, instruction, agent, or skill. Use corpus import when approved stimuli already exist in a supported CSV or XLSX file.

## How to use it

Provide the target `files`, artifact `kind`, and optional authoring `mode`. The prompt checks safety, rejects harmful or sensitive stimuli, deduplicates by content hash, and appends only valid tests to the routed suite.

## Example usage

```text
/vally-test-write files=.github/prompts/hve-core/rpi.prompt.md kind=prompt
```

The prompt drafts a benign conformance stimulus for the RPI prompt and reports whether it was appended or skipped.
