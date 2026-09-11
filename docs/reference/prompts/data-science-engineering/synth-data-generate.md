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

Use this prompt when you need a notebook that produces realistic fictional data for development, demonstrations, or data-science experiments. Use approved source data instead when the work requires actual observed records. For either mode, the `dataops` synthetic-data operation contract is the preflight authority.

## How to use it

Describe the subject and optionally provide an example schema or sample structure. Before
project setup, package installation, notebook creation, source access, or generation,
provide or create the applicable `SYNTHETIC_DATA_OPERATION_V1` preflight and run the
`dataops` `validate` command. The preflight must contain current approved qualified-owner
decisions; this prompt does not decide whether data or fields are sensitive. If validation
is blocked, it stops and reports stable reason categories without reading source values.

New output is the default. For `replace-local`, use one approved regular local file and
expected SHA-256 digest, generate one candidate, and route the separately confirmed
replacement through the `dataops` `commit-local` command so a recoverable predecessor is
created and the original is not written by notebook code.

## Example usage

```text
/synth-data-generate subject="retail inventory demand" example_data="inventory.csv schema"
```

The prompt creates a notebook that generates fictional inventory and demand records with realistic relationships.
