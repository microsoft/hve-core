---
title: PRD Quality Reviewer
description: Read-only PRD quality reviewer that emits both PRD_STANDARD_FINDINGS_V1 and PRD_QUALITY_REPORT_V1 payloads
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - prd-quality-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/project-planning/subagents/prd-quality-reviewer.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only PRD quality reviewer that emits both PRD_STANDARD_FINDINGS_V1 and PRD_QUALITY_REPORT_V1 payloads
<!-- END AUTO-GENERATED: overview -->

## When to use it

PRD Builder dispatches this read-only worker during Validate or Finalize to assess testability, product-goal traceability, constraints, and the separation of requirements from design decisions. It returns quality evidence to the builder rather than editing the document or approving it on behalf of stakeholders.

## Example usage

The parent supplies a PRD draft and active `Validate` phase with the applicable taxonomy and rubric inputs. The reviewer returns `PRD_STANDARD_FINDINGS_V1` and `PRD_QUALITY_REPORT_V1` with evidence, coverage, gate decisions, and prioritized corrections. Success means the builder can identify what blocks advancement without treating a worker verdict as human approval.
