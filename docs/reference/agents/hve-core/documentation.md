---
title: Documentation
description: "Orchestrates documentation audit, drift, authoring, and validation work through the documentation skill"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - hve-core
  - documentation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/hve-core/documentation.agent.md`       |
| Invocation  | Selected from the chat agent picker as `Documentation` |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Orchestrates documentation audit, drift, authoring, and validation work through the documentation skill
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Documentation to audit coverage, inspect code-to-documentation drift, author a guide or reference page, or validate documentation. It routes the selected mode through the documentation skill. Formal accessibility, security, and responsible-AI assessments belong with their specialist planners.

## How to use it

1. Select `Documentation` and name `audit`, `drift`, `author`, or `validate`, together with target paths and the focus area.
2. For authoring, specify a guide or reference template and output path. For drift or validation, state whether changes are prohibited.
3. Review the resulting evidence, draft, or validation results and any unresolved discovery needs. Drift mode stays read-only.
4. Treat unavailable CI-owned checks separately from local results; a generic validation request does not authorize browser installation, services, or credentials.

## Example usage

Ask: "Use drift mode to compare `src/importer` with `docs/importing.md`. Report outdated behavior and missing examples without editing either path."

Expect a focused code-to-documentation comparison with evidence and recommended corrections. Success means each proposed change follows the current source contract and any missing evidence is recorded instead of converted into invented documentation.
