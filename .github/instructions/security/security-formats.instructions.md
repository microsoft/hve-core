---
description: "Shared format specifications and subagent response contracts for the security reviewer orchestrator and its subagents - Brought to you by microsoft/hve-core"
applyTo: '**security**'
---

# Security Reviewer Formats

Shared format specifications used by the security reviewer orchestrator and its subagents. These formats define the contracts between subagents and the orchestrator for data exchange during vulnerability assessments.

## Subagent Response Contracts

Required fields the orchestrator extracts from each subagent response.

### Codebase Profiler

| Field                    | Usage                                                                              |
|--------------------------|------------------------------------------------------------------------------------|
| `**Repository:**`        | Extracted as `repo_name` for report metadata and completion message.               |
| `**Mode:**`              | Scanning mode echo.                                                                |
| `**Primary Languages:**` | Technology context passed to downstream subagents.                                 |
| `**Frameworks:**`        | Technology context passed to downstream subagents.                                 |
| `### Applicable Skills`  | YAML list intersected with Available Skills to determine assessment targets.       |
| Full profile text        | Passed verbatim to Skill Assessor and Finding Deep Verifier as `codebase_profile`. |

### Skill Assessor

| Field                                                                                                   | Usage                                                                                                                                                                                               |
|---------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Skill metadata (`**Skill:**`, `**Framework:**`, `**Version:**`, `**Reference:**`)                       | Carried through to Report Generator for per-skill context.                                                                                                                                          |
| Findings table (ID, Title, Status, Severity, Location, Finding, Recommendation)                         | Each row extracted and classified by Status. FAIL and PARTIAL rows serialized into Finding Serialization Format for verification. PASS and NOT_ASSESSED rows passed through with verdict UNCHANGED. |
| Detailed Remediation subsections (offending code, example fix, remediation steps per FAIL/PARTIAL item) | Carried through to Report Generator for severity-grouped remediation guidance.                                                                                                                      |

### Finding Deep Verifier

One verdict block per finding. Required fields per block:

| Field                    | Usage                                                                          |
|--------------------------|--------------------------------------------------------------------------------|
| `**Verdict:**`           | CONFIRMED, DISPROVED, or DOWNGRADED. Drives verification summary counts.       |
| `**Verified Status:**`   | Updated status after adversarial review.                                       |
| `**Verified Severity:**` | Updated severity after adversarial review. Drives severity breakdown counts.   |
| Full verdict block       | Added verbatim to the Verified Findings Collection passed to Report Generator. |

### Report Generator

| Field                                                                                        | Usage                                                                                            |
|----------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------|
| Report file path                                                                             | Inserted into the Scan Completion Format as `REPORT_FILE_PATH`.                                  |
| Report format used                                                                           | VULN_REPORT_V1 (audit or diff) or PLAN_REPORT_V1 (plan). Confirms which template was applied.    |
| Mode                                                                                         | Scanning mode that determined the report format.                                                 |
| Severity breakdown (critical, high, medium, low counts)                                      | Populates `CRITICAL_COUNT`, `HIGH_COUNT`, `MEDIUM_COUNT`, `LOW_COUNT` in the completion message. |
| Summary counts (pass, fail, partial, not-assessed or risk, caution, covered, not-applicable) | Populates the status count fields in the completion message.                                     |
| Verification counts (confirmed, disproved, downgraded)                                       | Populates verification fields in the audit/diff completion message.                              |
| Generation status                                                                            | Indicates whether report generation completed successfully.                                      |
| Clarifying questions                                                                         | Questions surfaced when inputs are ambiguous or missing. Handled by orchestrator retry protocol. |

## Finding Serialization Format

Each finding passed to the `Finding Deep Verifier` is a markdown block with these fields:

```text
- **ID:** <FINDING_ID>
- **Title:** <FINDING_TITLE>
- **Status:** <FINDING_STATUS>
- **Severity:** <FINDING_SEVERITY>
- **Location:** <FILE_LOCATION>
- **Finding:** <FINDING_DESCRIPTION>
- **Recommendation:** <RECOMMENDATION>
```

## Verified Findings Collection Format

The merged collection of verified findings passed to `Report Generator` uses the following structure:

* Items are grouped by skill name.
* UNCHANGED items (PASS and NOT_ASSESSED) use the Finding Serialization Format with an added `- **Verdict:** UNCHANGED` field.
* Verified items (FAIL and PARTIAL after deep verification) include the full Deep Verification Verdict block as returned by `Finding Deep Verifier`.

```text
### owasp-top-10

## Finding: A01-001: Broken Access Control, Missing authorization checks

### Original Assessment
- **Status:** FAIL
- **Severity:** High
- **Finding:** No authorization middleware on admin endpoints.

### Vulnerability Reference Analysis
- **Reference file:** .github/skills/security/owasp-top-10/references/A01-broken-access-control.md
- **Applicable checklist items:** A01-001, A01-003
- **Attack preconditions:** Unauthenticated network access to the API

### Vulnerable Location
- **File:** [src/api/routes.ts#L45](src/api/routes.ts#L45)
- **Lines:** L42-L48

### Offending Code

```ts
app.get('/api/admin/users', (req, res) => {
  return db.users.findAll();
});
```

### Confirming Evidence
- No auth middleware registered on the admin router at src/api/routes.ts#L42-L48.
- No global middleware guard for `/api/admin/*` routes.

### Contradicting Evidence
None found.

### Verdict
- **Verdict:** CONFIRMED
- **Verified Status:** FAIL
- **Verified Severity:** High
- **Justification:** Endpoint `/api/admin/users` lacks any auth middleware. Direct access confirmed via route definition at src/api/routes.ts:45. No global or route-level guards exist.

### Updated Remediation
Add authorization middleware that checks for admin role before processing admin API requests.

### Example Fix

```ts
app.get('/api/admin/users', requireRole('admin'), (req, res) => {
  return db.users.findAll();
});
```

---

- **ID:** A01-002
- **Title:** Broken Access Control: CORS misconfiguration
- **Status:** PASS
- **Severity:** N/A
- **Location:** N/A
- **Finding:** CORS configuration restricts origins appropriately.
- **Recommendation:** N/A
- **Verdict:** UNCHANGED
```

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
* Use the diff filename pattern from Constants.
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

## Scan Status Format

Brief status update shown to the user during orchestration.

```text
**Vulnerability Scan: <PHASE>**
**Mode:** <MODE>
<STATUS_MESSAGE>
```

Where:

* MODE: Scanning mode (`audit`, `diff`, or `plan`).
* PHASE: Current phase name (Setup, Profiling, Assessing, Verifying, Reporting, Complete).
* STATUS_MESSAGE: One to two sentence status update.

## Scan Completion Format

Final confirmation after the report is written.

### Audit and Diff Modes

```text
Report saved → <REPORT_FILE_PATH>

**Mode:** <MODE>
**Skills assessed:** <SKILLS_ASSESSED>
**Severity:** <CRITICAL_COUNT> critical, <HIGH_COUNT> high, <MEDIUM_COUNT> medium, <LOW_COUNT> low
**Verification:** <CONFIRMED_COUNT> confirmed, <DISPROVED_COUNT> disproved, <DOWNGRADED_COUNT> downgraded
**Summary:** <PASS_COUNT> passed, <FAIL_COUNT> failed, <PARTIAL_COUNT> partial, <NA_COUNT> not assessed
```

> [!CAUTION]
> AI-generated findings require validation by qualified security professionals. This assessment does not replace SAST, DAST, SCA, or penetration testing.

### Plan Mode

```text
Report saved → <REPORT_FILE_PATH>

**Mode:** plan
**Skills assessed:** <SKILLS_ASSESSED>
**Severity:** <CRITICAL_COUNT> critical, <HIGH_COUNT> high, <MEDIUM_COUNT> medium, <LOW_COUNT> low
**Summary:** <RISK_COUNT> risks, <CAUTION_COUNT> cautions, <COVERED_COUNT> covered, <NA_COUNT> not applicable
```

> [!CAUTION]
> AI-generated findings require validation by qualified security professionals. This assessment does not replace SAST, DAST, SCA, or penetration testing.

Where:

* REPORT_FILE_PATH: Path to the written report file.
* MODE: Scanning mode (`audit` or `diff`).
* SKILLS_ASSESSED: Comma-separated list of skill names.
* CRITICAL_COUNT: Findings rated critical severity.
* HIGH_COUNT: Findings rated high severity.
* MEDIUM_COUNT: Findings rated medium severity.
* LOW_COUNT: Findings rated low severity.
* CONFIRMED_COUNT: Findings confirmed by adversarial verification.
* DISPROVED_COUNT: Findings disproved by adversarial verification.
* DOWNGRADED_COUNT: Findings with reduced severity after verification.
* PASS_COUNT: Findings that passed assessment.
* FAIL_COUNT: Findings that failed assessment.
* PARTIAL_COUNT: Findings with partial compliance.
* NA_COUNT: Findings that could not be fully assessed.
* RISK_COUNT: Plan elements with theoretical vulnerability risk.
* CAUTION_COUNT: Plan elements with potential concerns depending on implementation.
* COVERED_COUNT: Plan elements already mitigated by existing codebase controls.

## Minimal Profile Stub Format

Used when `targetSkill` bypasses the Codebase Profiler.

```markdown
## Codebase Profile

**Repository:** <REPO_NAME>
**Mode:** <MODE>
**Primary Languages:** Unknown (profiling skipped)
**Frameworks:** Unknown (profiling skipped)

### Applicable Skills

- <TARGET_SKILL>
```

## Orchestrator Constants

Report directory: `.copilot-tracking/security`

Report path pattern (audit): `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-{{NNN}}.md`

Report path pattern (diff): `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-diff-{{NNN}}.md`

Report path pattern (plan): `.copilot-tracking/security/{{YYYY-MM-DD}}/plan-risk-assessment-{{NNN}}.md`

Sequence number resolution: Determine `{{NNN}}` by listing existing reports in the date directory, extracting the highest sequence number, incrementing by one, and zero-padding to three digits. Start at `001` when no reports exist.

Skill base path: `.github/skills/security`

### Subagents

| Name                  | Agent File                                         | Purpose                                                                            |
|-----------------------|----------------------------------------------------|------------------------------------------------------------------------------------|
| Codebase Profiler     | `.github/agents/**/codebase-profiler.agent.md`     | Scans the repository to build a technology profile and identify applicable skills. |
| Finding Deep Verifier | `.github/agents/**/finding-deep-verifier.agent.md` | Deep adversarial verification of findings using full vulnerability references.     |
| Report Generator      | `.github/agents/**/report-generator.agent.md`      | Collates all verified findings and generates the final vulnerability report.       |
| Skill Assessor        | `.github/agents/**/skill-assessor.agent.md`        | Assesses a single skill against the codebase, returning structured findings.       |

### Available Skills

* owasp-agentic
* owasp-llm
* owasp-top-10

## Subagent Prompt Templates

Mode-specific prompt templates used by the orchestrator when invoking subagents. Substitute placeholders (`{variable}`) with runtime values.

### Codebase Profiler Prompts

* `audit`: "Profile this codebase for OWASP vulnerability assessment. Identify the technology stack and list all applicable OWASP skills."
* `diff`: "Profile this codebase for OWASP vulnerability assessment. Scope technology detection to the following changed files.\n\nChanged Files:\n{changed_files_list}\n\nIdentify the technology stack and list applicable OWASP skills relevant to the changed files."
* `plan`: "Profile the following implementation plan for OWASP vulnerability assessment. Extract technology signals from the plan text and list applicable OWASP skills.\n\nPlan Document:\n{plan_document_content}"

When a subdirectory focus is provided (audit and diff only), append: "Focus profiling on the following subdirectory: {subdirectory_focus}"

### Skill Assessor Prompts

* `audit`: "Assess the following OWASP skill against the codebase.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}"
* `diff`: "Assess the following OWASP skill against the codebase. Scope analysis to the changed files listed below.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nChanged Files:\n{changed_files_list}"
* `plan`: "Assess the following OWASP skill against the implementation plan. Evaluate plan content against vulnerability references and assign plan-mode statuses (RISK, CAUTION, COVERED, NOT_APPLICABLE).\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nPlan Document:\n{plan_document_content}"

When a subdirectory focus is provided (audit only), append: "Subdirectory Focus: {subdirectory_focus}"

### Finding Deep Verifier Prompts

* `audit`: "Perform deep adversarial verification of all findings listed below for this OWASP skill. Verify every finding in this list within this single invocation.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nFindings to verify:\n{findings}\n\nReturn one Deep Verification Verdict block per finding."
* `diff`: "Perform deep adversarial verification of all findings listed below for this OWASP skill. Verify every finding in this list within this single invocation. These findings originate from a diff-scoped scan. Search the full repository for evidence, including unchanged code.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nChanged Files:\n{changed_files_list}\n\nFindings to verify:\n{findings}\n\nReturn one Deep Verification Verdict block per finding."

`{findings}` uses the Finding Serialization Format.

### Report Generator Prompts

* `audit`: "Generate the OWASP vulnerability assessment report following your VULN_REPORT_V1 format.\n\nVerified Findings (using the Verified Findings Collection Format):\n{verified_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}"
* `diff`: "Generate the OWASP vulnerability assessment report following your VULN_REPORT_V1 format. This is a diff-scoped scan of changed files only.\n\nMode: diff\nVerified Findings (using the Verified Findings Collection Format):\n{verified_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}\n\nChanged Files:\n{changed_files_list}\n\nUse the diff report filename pattern. Include a changed files appendix."
* `plan`: "Generate the OWASP pre-implementation security risk assessment following your PLAN_REPORT_V1 format.\n\nMode: plan\nPlan Findings:\n{plan_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}\nPlan Source: {plan_document_path}\n\nUse the plan report filename pattern. Include risk ratings and implementation guidance."

When a prior scan report path is provided, append to any prompt: "Prior Report:\n{prior_scan_report_path}"

## Severity Level Definitions

Standard severity ratings used by all OWASP skill assessments.

| Severity | Definition                                                                              |
|----------|-----------------------------------------------------------------------------------------|
| CRITICAL | Immediate exploitation leads to full system compromise or data exfiltration.            |
| HIGH     | Exploitation requires minimal prerequisites and results in significant impact.          |
| MEDIUM   | Exploitation requires specific conditions but leads to meaningful security degradation. |
| LOW      | Exploitation is difficult or impact is limited in scope.                                |
