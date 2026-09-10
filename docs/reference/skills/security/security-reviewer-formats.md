---
title: security-reviewer-formats
description: Format specifications and data contracts for the security reviewer orchestrator and its subagents.
sidebar_position: 11
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - security-reviewer-formats
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                               |
|-------------|-----------------------------------------------------|
| Kind        | skill                                               |
| Source      | `.github/skills/security/security-reviewer-formats` |
| Invocation  | Loaded on demand by referencing agents              |
| Interactive | No                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Format specifications and data contracts for the security reviewer orchestrator and its subagents.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Security, accessibility, and RAI review orchestrators load this skill when they
need compatible finding, verification, report, and completion formats. Use it to
exchange assessment results or assemble a report, not to decide which security
standard applies. Domain references supply assessment criteria; this package
supplies the reporting contracts and shared severity definitions.

## Example usage

For an illustrative Security Reviewer diff review, provide the bounded code diff
and the resulting finding and verification records. Ask the orchestrator to load
`security-reviewer-formats` and assemble the audit/diff report and completion
summary. Expect severity counts and verification outcomes to agree with the
underlying records, with unassessed areas still visible.

For a plan review, supply the proposed architecture instead. The output should
distinguish risks, cautions, and covered elements rather than claiming runtime
verification. Success is a report in the correct contract with traceable counts
and its qualified-security-review caution intact. For RAI output, human acceptance
remains `PENDING`; report generation is not human approval. Missing or malformed
records must not become a successful empty report.
