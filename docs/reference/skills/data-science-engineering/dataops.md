---
title: dataops
description: "DataOps and DS/MLOps testing reference for data tiering, Bronze-to-Silver validation placement, pipeline invariants, pytest categories, and validation-versus-drift. Use when designing, reviewing, or generating data pipelines, transformation code, data validation, or data-science test suites."
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-17
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - dataops
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                             |
|-------------|---------------------------------------------------|
| Kind        | skill                                             |
| Source      | `.github/skills/data-science-engineering/dataops` |
| Invocation  | Loaded on demand by referencing agents            |
| Interactive | No                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
DataOps and DS/MLOps testing reference for data tiering, Bronze-to-Silver validation placement, pipeline invariants, pytest categories, and validation-versus-drift. Use when designing, reviewing, or generating data pipelines, transformation code, data validation, or data-science test suites.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reach for this skill when the work touches data movement, transformation, or the tests that guard it:

* Designing or reviewing a tiered data layout and deciding which storage areas are pipeline tiers versus operational areas.
* Deciding where schema and quality validation belongs relative to a Bronze-to-Silver boundary, and why replayability constrains that placement.
* Writing or reviewing pytest suites for data-science and MLOps code, including which outside calls to mock and which to leave real.
* Distinguishing a data-validation failure from model or data drift, and routing each to its own remediation path.
* Guarding synthetic-data generation or an authorized local replacement. Read the [synthetic-data-operation-contract.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/data-science-engineering/dataops/references/synthetic-data-operation-contract.md), require a current approved `SYNTHETIC_DATA_OPERATION_V1` preflight, and run its `validate` command before project setup, package installation, source access, or writes.

Choose a different asset when:

* The question is about telemetry naming, span attributes, or metric conventions. Use the `telemetry-foundations` skill.
* The question is about data classification, personal-data handling, or DPIA thresholds. Use the `privacy-standards` skill.
* The question is about designing an experiment or forming a hypothesis. Use the `experiment-design` skill.

## Example usage

Ask an agent that loads this skill to review a pipeline change:

```text
Review this Bronze-to-Silver notebook. Where should schema validation live,
and what does that imply for replay?
```

The skill grounds the answer in its reference pack: validation runs at the Bronze-to-Silver boundary so Bronze retains the raw landed record, which preserves two distinct replay paths (replaying to exercise changed validation logic, and replaying to recover from a transformation defect).

It also flags the notebook-extraction trigger when transformation logic outgrows an interactive cell, and separates transformation code from data-access code so the transformation is unit-testable without mocking storage.

For synthetic-data work, validate the preflight record before any source access or write:

```text
python .github/skills/data-science-engineering/dataops/scripts/synthetic_data_operation.py validate --preflight preflight.json
```

Use `new-output` by default. For an authorized `replace-local` operation, create one
candidate and result record, recheck the approved source digest, and route the final
replacement through `commit-local`; do not overwrite the original from notebook code.
