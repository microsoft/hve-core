---
title: Report Formats
description: VULN_REPORT_V1 and PLAN_REPORT_V1 report templates for the security reviewer
---

# Report Formats

## Security Report Format

The VULN_REPORT_V1 format defines the report structure for audit and diff modes. Follow this format exactly when generating audit or diff reports.

```markdown
# OWASP Security Assessment Report

**Date:** <REPORT_DATE>
**Repository:** <REPO_NAME>
**Agent:** Security Reviewer
**Skills applied:** <SKILLS_APPLIED>

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

---

## Executive Summary

<EXECUTIVE_SUMMARY>

### Summary Counts

| Status       | Count                |
|--------------|----------------------|
| PASS         | <PASS_COUNT>         |
| FAIL         | <FAIL_COUNT>         |
| PARTIAL      | <PARTIAL_COUNT>      |
| NOT_ASSESSED | <NOT_ASSESSED_COUNT> |
| **Total**    | **<TOTAL_COUNT>**    |

### Severity Breakdown (FAIL + PARTIAL only)

| Severity | Count            |
|----------|------------------|
| CRITICAL | <CRITICAL_COUNT> |
| HIGH     | <HIGH_COUNT>     |
| MEDIUM   | <MEDIUM_COUNT>   |
| LOW      | <LOW_COUNT>      |

### Verification Summary

| Verdict    | Count              |
|------------|--------------------|
| CONFIRMED  | <CONFIRMED_COUNT>  |
| DISPROVED  | <DISPROVED_COUNT>  |
| DOWNGRADED | <DOWNGRADED_COUNT> |
| UNCHANGED  | <UNCHANGED_COUNT>  |

---

## Findings by Framework

<FRAMEWORK_FINDINGS>

---

## Detailed Remediation Guidance

<DETAILED_REMEDIATION>

### Disproved Findings

<DISPROVED_FINDINGS>

---

## Remediation Checklist

| ID | Control | Status | Evidence |
|----|---------|--------|----------|
<CHECKLIST_ROWS>

---

## Appendix: Skills Used

| Skill | Framework | Version | Reference |
|-------|-----------|---------|-----------|
<SKILLS_TABLE_ROWS>
```

Where:

* REPORT_DATE is ISO 8601; today's date in YYYY-MM-DD format.
* REPO_NAME is a string; the repository name.
* SKILLS_APPLIED is a string; comma-separated list of skill names used.
* EXECUTIVE_SUMMARY is markdown; 3–5 sentence narrative summarizing the most critical findings, skills assessed, total checks, and verification outcomes.
* PASS_COUNT, FAIL_COUNT, PARTIAL_COUNT, NOT_ASSESSED_COUNT, TOTAL_COUNT are integers.
* CRITICAL_COUNT, HIGH_COUNT, MEDIUM_COUNT, LOW_COUNT are integers counting FAIL and PARTIAL findings at each severity.
* CONFIRMED_COUNT is an integer; findings confirmed by adversarial verification.
* DISPROVED_COUNT is an integer; findings disproved by adversarial verification.
* DOWNGRADED_COUNT is an integer; findings with reduced severity after verification.
* UNCHANGED_COUNT is an integer; PASS or NOT_ASSESSED items passed through unchanged.
* FRAMEWORK_FINDINGS is markdown; one H3 section per assessed skill, each containing a markdown table with columns: ID, Title, Status, Severity, Location, Finding, Recommendation, Verdict, Justification. Location values are markdown links to the file and line range where known. PASS and NOT_ASSESSED rows use `N/A` for Severity, Location, Finding, and Recommendation. Rows are ordered by severity: CRITICAL, HIGH, MEDIUM, LOW, PASS, NOT_ASSESSED.
* DETAILED_REMEDIATION is markdown; one H3 severity group (`### CRITICAL Severity`, `### HIGH Severity`, etc.) containing one H4 subsection per FAIL or PARTIAL finding, sorted CRITICAL, HIGH, MEDIUM, LOW. Each H4 subsection includes: **File:** markdown link(s) to the vulnerable location; **Offending Code:** fenced code block with the vulnerable snippet; **Example Fix:** fenced code block with corrected code; **Steps:** numbered remediation steps; **Verification verdict:** verdict label (CONFIRMED / DOWNGRADED / DISPROVED) with downgrade justification where applicable. When the same vulnerability appears in multiple files, list each file with its own Offending Code and Example Fix blocks under one shared H4 heading. Omit a severity group entirely if no findings exist at that level.
* DISPROVED_FINDINGS is markdown; a bullet list of disproved findings with ID, title, and brief justification for transparency. Use "None." when no findings were disproved.
* CHECKLIST_ROWS is pipe-delimited rows for each CONFIRMED or DOWNGRADED item with NOT_STARTED status.
* SKILLS_TABLE_ROWS is pipe-delimited rows for each skill with metadata.

### Diff Mode Qualifiers

When mode is `diff`, apply these modifications to the VULN_REPORT_V1 format:

* Change the H1 title to: `# OWASP Security Assessment Report — Changed Files Only`
* Add a `**Scope:** Changed files relative to {default_branch}` field in the header block after the `**Skills applied:**` line.
* Use the diff filename pattern from the orchestrator constants.
* Append a "Changed Files" appendix section after the "Appendix: Skills Used" section:

```markdown
---

## Appendix: Changed Files

| File | Change Type |
|------|-------------|
<CHANGED_FILES_ROWS>
```

Where CHANGED_FILES_ROWS is pipe-delimited rows listing each changed file path and its change type (added, modified, or renamed).

## Plan Report Format

The PLAN_REPORT_V1 format defines the report structure for plan mode. Follow this format exactly when generating plan reports.

```markdown
# OWASP Pre-Implementation Security Risk Assessment

**Date:** <REPORT_DATE>
**Repository:** <REPO_NAME>
**Agent:** Security Reviewer
**Mode:** plan
**Skills applied:** <SKILLS_APPLIED>
**Plan source:** <PLAN_SOURCE>

---

## Executive Summary

<EXECUTIVE_SUMMARY>

### Risk Summary

| Status         | Count             |
|----------------|-------------------|
| RISK           | <RISK_COUNT>      |
| CAUTION        | <CAUTION_COUNT>   |
| COVERED        | <COVERED_COUNT>   |
| NOT_APPLICABLE | <NA_COUNT>        |
| **Total**      | **<TOTAL_COUNT>** |

### Severity Breakdown (RISK + CAUTION only)

| Severity | Count            |
|----------|------------------|
| CRITICAL | <CRITICAL_COUNT> |
| HIGH     | <HIGH_COUNT>     |
| MEDIUM   | <MEDIUM_COUNT>   |
| LOW      | <LOW_COUNT>      |

---

## Risk Findings by Framework

<FRAMEWORK_FINDINGS>

---

## Mitigation Guidance

<MITIGATION_GUIDANCE>

---

## Implementation Security Checklist

| ID | Risk | Severity | Mitigation Required | Status |
|----|------|----------|---------------------|--------|
<CHECKLIST_ROWS>

---

## Appendix: Skills Used

<SKILLS_TABLE_ROWS>
```

Where:

* REPORT_DATE is ISO 8601; today's date in YYYY-MM-DD format.
* REPO_NAME is a string; the repository name.
* SKILLS_APPLIED is a string; comma-separated list of skill names used.
* PLAN_SOURCE is a string; the resolved plan document path or identifier.
* EXECUTIVE_SUMMARY is markdown; 3–5 sentence narrative summarizing theoretical risks identified in the plan, skills assessed, total checks, and severity distribution.
* RISK_COUNT is an integer; plan elements with theoretical vulnerability risk.
* CAUTION_COUNT is an integer; plan elements with potential concerns depending on implementation.
* COVERED_COUNT is an integer; plan elements already mitigated by existing codebase controls.
* NA_COUNT is an integer; plan elements not applicable to any assessed framework.
* TOTAL_COUNT is an integer; sum of all statuses.
* CRITICAL_COUNT, HIGH_COUNT, MEDIUM_COUNT, LOW_COUNT are integers counting RISK and CAUTION findings at each severity.
* FRAMEWORK_FINDINGS is markdown; one H3 section per assessed skill, each containing a markdown table with columns: ID, Title, Status, Severity, Risk Description, Mitigation. Rows are ordered by severity: CRITICAL first, then HIGH, MEDIUM, LOW, COVERED, NOT_APPLICABLE. COVERED and NOT_APPLICABLE rows use `N/A` for Risk Description and Mitigation.
* MITIGATION_GUIDANCE is markdown; grouped by severity (CRITICAL, HIGH, MEDIUM, LOW). Each RISK or CAUTION finding includes: risk description, attack scenario, numbered mitigation steps, and an implementation checklist.
* CHECKLIST_ROWS is pipe-delimited rows for each RISK or CAUTION item with NOT_STARTED status.
* SKILLS_TABLE_ROWS is pipe-delimited rows for each skill with metadata.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
