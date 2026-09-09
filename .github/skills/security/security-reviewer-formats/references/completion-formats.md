---
title: Completion Formats
description: Scan Status, Scan Completion, and Minimal Profile Stub formats for orchestrator progress reporting
---

# Completion Formats

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

## RAI Generator Response and Terminal Errors

The successful RAI generator response contains Report path, Report format=`RAI_REPORT_V1`, Mode,
Generation status=`complete`, Summary counts, Severity breakdown, Verification counts for audit
or diff (null for plan), Human acceptance=`PENDING`, and Errors as an empty array.

Every RAI child failure returns Status=`ERROR`, Phase, Code, Message, Retryable, and Report
path=null when the generator fails. Code is one of UNSUPPORTED_DOMAIN, INVALID_MODE,
INVALID_PAYLOAD, UNRESOLVED_REFERENCE, PATH_MISMATCH, MALFORMED_VERDICT, MISSING_CAUTION,
HUMAN_ACCEPTANCE_VIOLATION, or REPORT_WRITE_FAILED. The parent and both RAI children consume the
following canonical total mapping:

| Code                       | Retryable |
|----------------------------|-----------|
| UNSUPPORTED_DOMAIN         | false     |
| INVALID_MODE               | false     |
| INVALID_PAYLOAD            | false     |
| UNRESOLVED_REFERENCE       | false     |
| PATH_MISMATCH              | false     |
| MALFORMED_VERDICT          | false     |
| MISSING_CAUTION            | false     |
| HUMAN_ACCEPTANCE_VIOLATION | false     |
| REPORT_WRITE_FAILED        | true      |

`REPORT_WRITE_FAILED` may retry once. All other terminal contract errors stop immediately.
