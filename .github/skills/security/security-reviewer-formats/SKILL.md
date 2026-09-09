---
name: security-reviewer-formats
description: Format specifications and data contracts for the security reviewer orchestrator and its subagents.
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-03-16"
---

# Security Reviewer Formats — Skill Entry

This `SKILL.md` is the **entrypoint** for the security reviewer format specifications skill.

The skill provides shared format templates and data contracts used by security, accessibility,
and RAI review orchestrators and their subagents. Each reference file covers a focused area of
the reporting pipeline.

## Normative references

1. [Report Formats](references/report-formats.md) — VULN_REPORT_V1, PLAN_REPORT_V1, and RAI_REPORT_V1 templates.
2. [Finding Formats](references/finding-formats.md) — Security and RAI finding, verification, and collection formats.
3. [Completion Formats](references/completion-formats.md) — Scan status, completion, RAI response, and terminal error formats.
4. [Severity Definitions](references/severity-definitions.md) — Standard severity level definitions for all OWASP skill assessments.

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — format specification documents.
  * `report-formats.md` — full report templates for audit, diff, and plan modes.
  * `finding-formats.md` — serialization and collection formats for findings exchange between subagents.
  * `completion-formats.md` — status updates, completion summaries, and the minimal profile stub.
  * `severity-definitions.md` — severity level table shared across all assessments.
