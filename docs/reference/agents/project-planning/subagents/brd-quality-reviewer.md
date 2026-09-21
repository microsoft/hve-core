---
title: BRD Quality Reviewer
description: Read-only BRD quality reviewer that emits both BRD_STANDARD_FINDINGS_V1 and BRD_QUALITY_REPORT_V1 payloads
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - brd-quality-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/project-planning/subagents/brd-quality-reviewer.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only BRD quality reviewer that emits both BRD_STANDARD_FINDINGS_V1 and BRD_QUALITY_REPORT_V1 payloads
<!-- END AUTO-GENERATED: overview -->

## When to use it

BRD Builder dispatches this read-only worker to assess a draft during Define or Govern. It checks requirements, constraints, measurable business goals, and traceability, then returns both per-standard findings and an aggregate quality report. It neither edits the BRD nor supplies human signoff.

## Example usage

The parent supplies the BRD draft, active `Define` phase, taxonomy, and relevant assessment inputs. The reviewer returns `BRD_STANDARD_FINDINGS_V1` and `BRD_QUALITY_REPORT_V1`, identifying missing acceptance links or unclear constraint sources with gate decisions. The parent persists and resolves those findings; the worker writes no repository files and does not advance the lifecycle itself.
