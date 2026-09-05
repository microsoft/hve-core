---
title: Synth Data Generate
description: Generate synthetic data for any subject with realistic patterns and relationships
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - data-science-engineering
  - synth-data-generate
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | prompt                                                                   |
| Source      | `.github/prompts/data-science-engineering/synth-data-generate.prompt.md` |
| Invocation  | Slash command `/synth-data-generate`                                     |
| Interactive | Yes                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generate synthetic data for any subject with realistic patterns and relationships
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when you need a notebook that produces realistic fictional data for development, demonstrations, or data-science experiments. Use approved source data instead when the work requires actual observed records.

## How to use it

Describe the subject and optionally provide an example schema or sample structure. Confirm before generating PII-like fields, keep values fictional, and review any proposed update to an existing data source.

## Example usage

```text
/synth-data-generate subject="retail inventory demand" example_data="inventory.csv schema"
```

The prompt creates a notebook that generates fictional inventory and demand records with realistic relationships.
