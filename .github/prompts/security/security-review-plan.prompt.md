---
name: security-review-plan
agent: Security Reviewer
description: "Analyzes implementation plan documents for pre-implementation security risks - Brought to you by microsoft/hve-core"
argument-hint: "[plan-document-path]"
---

# Plan Security Risk Assessment

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment. Plan-mode findings are theoretical assessments of proposed architecture and carry additional uncertainty; they are not confirmed vulnerabilities.

## Inputs

* ${input:plan-document-path}: (Optional) Path to the implementation plan document. Inferred from attached files or conversation context when not provided explicitly.

## Requirements

* Run in `plan` mode. Analyze the implementation plan document for pre-implementation security risks instead of scanning code.
* Profile applicable skills from technologies described in the plan rather than detected in the codebase.
* Assessment evaluates plan content against vulnerability reference checklists.
* Verification is skipped since no source code exists to verify against.
* Output the report in `PLAN_REPORT_V1` format to `.copilot-tracking/security/`.
* Plan-mode findings are theoretical and carry a stronger "not a substitute for professional review" qualifier.
