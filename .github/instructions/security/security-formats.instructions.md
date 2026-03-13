---
description: "Shared format specifications and subagent response contracts for the security reviewer orchestrator and its subagents - Brought to you by microsoft/hve-core"
applyTo: '**security**'
---

# Security Reviewer Formats

Shared format specifications used by the security reviewer orchestrator and its subagents. These formats define the contracts between subagents and the orchestrator for data exchange during vulnerability assessments.

## Subagent Response Contracts

Required fields the orchestrator extracts from each subagent response.

### Codebase Profiler

| Field | Usage |
|-------|-------|
| `**Repository:**` | Extracted as `repo_name` for report metadata and completion message. |
| `**Mode:**` | Scanning mode echo. |
| `**Primary Languages:**` | Technology context passed to downstream subagents. |
| `**Frameworks:**` | Technology context passed to downstream subagents. |
| `### Applicable Skills` | YAML list intersected with Available Skills to determine assessment targets. |
| Full profile text | Passed verbatim to Skill Assessor and Finding Deep Verifier as `codebase_profile`. |

### Skill Assessor

| Field | Usage |
|-------|-------|
| Skill metadata (`**Skill:**`, `**Framework:**`, `**Version:**`, `**Reference:**`) | Carried through to Report Generator for per-skill context. |
| Findings table (ID, Title, Status, Severity, Location, Finding, Recommendation) | Each row extracted and classified by Status. FAIL and PARTIAL rows serialized into Finding Serialization Format for verification. PASS and NOT_ASSESSED rows passed through with verdict UNCHANGED. |
| Detailed Remediation subsections (offending code, example fix, remediation steps per FAIL/PARTIAL item) | Carried through to Report Generator for severity-grouped remediation guidance. |

### Finding Deep Verifier

One verdict block per finding. Required fields per block:

| Field | Usage |
|-------|-------|
| `**Verdict:**` | CONFIRMED, DISPROVED, or DOWNGRADED. Drives verification summary counts. |
| `**Verified Status:**` | Updated status after adversarial review. |
| `**Verified Severity:**` | Updated severity after adversarial review. Drives severity breakdown counts. |
| Full verdict block | Added verbatim to the Verified Findings Collection passed to Report Generator. |

### Report Generator

| Field | Usage |
|-------|-------|
| Report file path | Inserted into the Scan Completion Format as `REPORT_FILE_PATH`. |
| Report format used | VULN_REPORT_V1 (audit or diff) or PLAN_REPORT_V1 (plan). Confirms which template was applied. |
| Mode | Scanning mode that determined the report format. |
| Severity breakdown (critical, high, medium, low counts) | Populates `CRITICAL_COUNT`, `HIGH_COUNT`, `MEDIUM_COUNT`, `LOW_COUNT` in the completion message. |
| Summary counts (pass, fail, partial, not-assessed or risk, caution, covered, not-applicable) | Populates the status count fields in the completion message. |
| Verification counts (confirmed, disproved, downgraded) | Populates verification fields in the audit/diff completion message. |
| Generation status | Indicates whether report generation completed successfully. |
| Clarifying questions | Questions surfaced when inputs are ambiguous or missing. Handled by orchestrator retry protocol. |

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

## Finding: A01-001 — Broken Access Control — Missing authorization checks

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
- **Title:** Broken Access Control — CORS misconfiguration
- **Status:** PASS
- **Severity:** N/A
- **Location:** N/A
- **Finding:** CORS configuration restricts origins appropriately.
- **Recommendation:** N/A
- **Verdict:** UNCHANGED
```

## Scan Status Format

Brief status update shown to the user during orchestration.

```text
**Vulnerability Scan — <PHASE>**
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

### Plan Mode

```text
Report saved → <REPORT_FILE_PATH>

**Mode:** plan
**Skills assessed:** <SKILLS_ASSESSED>
**Severity:** <CRITICAL_COUNT> critical, <HIGH_COUNT> high, <MEDIUM_COUNT> medium, <LOW_COUNT> low
**Summary:** <RISK_COUNT> risks, <CAUTION_COUNT> cautions, <COVERED_COUNT> covered, <NA_COUNT> not applicable
```

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
