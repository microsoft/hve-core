---
name: security-reviewer-formats
description: Format specifications and data contracts for the security reviewer orchestrator and its subagents - Brought to you by microsoft/hve-core.
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-03-16"
---

# Security Reviewer Formats — Skill Entry

This `SKILL.md` is the **entrypoint** for the security reviewer format specifications skill.

The skill provides shared format templates and data contracts used by the security reviewer
orchestrator and its subagents during vulnerability assessments. Each reference file covers
a focused area of the reporting pipeline.

## Normative references

1. [Report Formats](references/report-formats.md) — VULN_REPORT_V1 template, diff mode qualifiers, and PLAN_REPORT_V1 template.
2. [Finding Formats](references/finding-formats.md) — Finding Serialization Format and Verified Findings Collection Format.
3. [Completion Formats](references/completion-formats.md) — Scan Status Format, Scan Completion Format, and Minimal Profile Stub Format.
4. [Severity Definitions](references/severity-definitions.md) — Standard severity level definitions for all OWASP skill assessments.

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — format specification documents.
  * `report-formats.md` — full report templates for audit, diff, and plan modes.
  * `finding-formats.md` — serialization and collection formats for findings exchange between subagents.
  * `completion-formats.md` — status updates, completion summaries, and the minimal profile stub.
  * `severity-definitions.md` — severity level table shared across all assessments.

---

> Brought to you by microsoft/hve-core
