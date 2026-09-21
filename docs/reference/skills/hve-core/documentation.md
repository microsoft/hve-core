---
title: documentation
description: "Canonical documentation capability for audit, drift, validate, and author modes in hve-core."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - hve-core
  - documentation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                           |
|-------------|---------------------------------------------------------------------------------|
| Kind        | skill                                                                           |
| Source      | `.github/skills/hve-core/documentation`                                         |
| Invocation  | Invoked directly as `/documentation`, or loaded on demand by referencing agents |
| Interactive | No                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Canonical documentation capability for audit, drift, validate, and author modes in hve-core.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill directly or through the Documentation agent to audit coverage,
find code/documentation drift, validate pages, or author source-grounded guides
and references. Select the mode to match the question: missing coverage, stale
behavior claims, mechanical quality, or new prose. ADRs, BRDs, and PRDs belong to
their planning capabilities rather than this documentation workflow.

## Example usage

Ask: `/documentation Use author mode to improve the sample command's reference
page from its implementation and existing usage examples. Preserve generated
regions and do not change source code.` Supply the exact page, implementation,
and approved edit boundary. Expect a concise reference covering supported
scenarios, inputs, expected results, and limitations, with examples verified
against the source rather than guessed.

For `drift`, supply a changed command and its existing guide, and ask for mismatches
without authoring corrections. For `audit`, bound the directories and ask for
coverage gaps. For `validate`, name the pages and expect actual local-safe check
results, with hosted or specialized checks reported separately as pending,
skipped, deferred, or unavailable when they did not run.

Success is factual, scoped guidance or an evidence-backed report, not an automatic
publication or blanket quality claim. Keep examples free of personal data and
secrets, retain AI disclosure, and route formal accessibility, RAI, or security
assessment to the appropriate planner. Missing browsers, models, credentials, or
services do not authorize automatic setup during generic validation.
