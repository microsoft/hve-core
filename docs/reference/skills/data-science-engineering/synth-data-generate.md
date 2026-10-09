---
title: synth-data-generate
description: Generate synthetic datasets in a Jupyter notebook after the dataops synthetic-data preflight passes. Use when creating new synthetic data or preparing a guarded local replacement candidate from an approved source.
sidebar_position: 8
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - synth-data-generate
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                              |
|-------------|----------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                              |
| Source      | `.github/skills/data-science-engineering/synth-data-generate`                                      |
| Invocation  | Invoked directly as `/synth-data-generate`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generate synthetic datasets in a Jupyter notebook after the dataops synthetic-data preflight passes. Use when creating new synthetic data or preparing a guarded local replacement candidate from an approved source.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when you need a notebook that produces realistic fictional data for development, demonstrations, or data-science experiments. Use approved source data instead when the work requires actual observed records.

## How to use it

Describe the subject and optionally provide an example schema or sample structure. Confirm before generating PII-like fields, keep values fictional, and review any proposed update to an existing data source.

## Example usage

```text
/synth-data-generate subject="retail inventory demand" example_data="inventory.csv schema"
```

The skill creates a notebook that generates fictional inventory and demand records with realistic relationships.
