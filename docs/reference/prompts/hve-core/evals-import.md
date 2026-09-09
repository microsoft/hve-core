---
title: Evals Import
description: Imports a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - evals-import
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                             |
|-------------|---------------------------------------------------|
| Kind        | prompt                                            |
| Source      | `.github/prompts/hve-core/evals-import.prompt.md` |
| Invocation  | Slash command `/evals-import`                     |
| Interactive | Yes                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Imports a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to convert an approved CSV or XLSX corpus into Vally evaluation stimuli with deduplication and safety checks. Use manual test authoring when the source set is small or does not follow the supported tabular contract.

## How to use it

Provide the corpus `path` and optionally its artifact `kind`. The prompt validates rows, rejects unsafe or sensitive stimuli, removes duplicates, and reports advisory imports for review.

## Example usage

```text
/evals-import path=evals/sample-corpus.csv kind=prompt
```

The prompt imports benign, unique rows into the matching prompt evaluation suite and reports skipped rows.
