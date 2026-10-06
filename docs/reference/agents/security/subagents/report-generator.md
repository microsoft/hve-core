---
title: Report Generator
description: Collates verified security or accessibility skill assessment findings and generates a comprehensive report written to the domain-appropriate reports directory
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - report-generator
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/security/subagents/report-generator.agent.md`            |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Collates verified security or accessibility skill assessment findings and generates a comprehensive report written to the domain-appropriate reports directory
<!-- END AUTO-GENERATED: overview -->

## When to use it

Security, accessibility, and RAI reviewer workflows dispatch Report Generator to consolidate supplied findings into the correct mode and domain report. It calculates summaries and preserves verification limits, disclaimers, and required artifact inventories. It does not perform a new assessment or provide human acceptance.

## Example usage

The parent supplies verified security findings, repository identity, date, and `diff` mode with changed files. The worker writes a `VULN_REPORT_V1` report and returns its path and counts; plan mode uses `PLAN_REPORT_V1`. RAI dispatches instead require `RAI_REPORT_V1`, the parent-resolved path, and pending human acceptance. Success means counts and findings agree with supplied evidence, not that missing checks become passes.
