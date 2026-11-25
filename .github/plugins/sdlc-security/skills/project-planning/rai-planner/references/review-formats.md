---
description: RAI review contracts for framework findings, independent verification, report generation and terminal errors
---

# RAI review formats

## Findings and verification

`RAI_FINDING_V1` contains ID, Title, Status, Severity, Location, Finding, and Recommendation. Only FAIL and PARTIAL records enter verification; every field is required. Verify each against its named framework requirement and the source evidence, including evidence that could disprove it.

`RAI_DEEP_VERIFICATION_V1` contains Schema, Finding ID, Finding Title, Original Status, Original Severity, Framework, Requirement, Confirming Evidence, Contradicting Evidence, Necessary Capability Assessment and rationale, Verdict, Verified Status, Verified Severity, Verified Categories, Justification, Updated Recommendation, and Limitations.

Distinguish REQUIRED, AVOIDABLE, and NOT_APPLICABLE capability from residual harm. Assign only evidence-supported AI STRIDE categories, NO_CATEGORY, or NOT_ASSESSED. Apply the total verdict mapping:

* CONFIRMED retains the source-supported FAIL or PARTIAL status, severity, and residual categories.
* DOWNGRADED maps to PARTIAL with lower evidence-supported severity.
* DISPROVED maps to PASS, NONE, and NO_CATEGORY.

A verifier never emits UNCHANGED. Assemble `RAI_VERIFIED_FINDINGS_COLLECTION_V1` by framework: each FAIL or PARTIAL input has exactly one verification record; PASS and NOT_ASSESSED pass through as `RAI_FINDING_V1` with Verdict=UNCHANGED. Account for every input exactly once.

For plans, `RAI_PLAN_FINDINGS_COLLECTION_V1` groups ID, Title, Status, Severity, Finding, Recommendation and optional limitation by framework. Use RISK, CAUTION, COVERED or NOT_APPLICABLE and no verification fields.

## Report and acceptance

`RAI_REPORT_V1` includes Date, Repository, Agent, Mode, Frameworks, the resolved path, the verbatim RAI Planning CAUTION, executive summary, findings by framework, recommendations, limitations, evidence appendix and an unchecked human-review handoff. Audit and diff include verification counts. Diff includes changed files. Plan includes the plan source and only plan findings; omit the verification summary. Preserve evidence provenance and necessary-capability reasoning. Human acceptance is `PENDING`, never implied by generation.

Under `.copilot-tracking/rai-reviews/{{YYYY-MM-DD}}/`, use `rai-report-{{REPO}}-{{YYYYMMDD}}.md` (audit), `rai-report-diff-{{REPO}}-{{YYYYMMDD}}.md` (diff), or `rai-plan-assessment-{{REPO}}-{{YYYYMMDD}}.md` (plan). Resolve the unsuffixed path first, then the lowest unoccupied numeric suffix starting at `-2`. Accept only the requested path of that form. Create without overwriting an existing file.

Successful generation returns Report path, Report format=`RAI_REPORT_V1`, Mode, Generation status=`complete`, Summary counts, Severity breakdown, Verification counts (null for plan), Human acceptance=`PENDING`, and Errors=`[]`. Read back the report before accepting success.

## Terminal errors

Return Status=`ERROR`, Phase, Code, Message and Retryable; Report path is null for generator failures. `UNSUPPORTED_DOMAIN`, `INVALID_MODE`, `INVALID_PAYLOAD`, `UNRESOLVED_REFERENCE`, `PATH_MISMATCH`, `MALFORMED_VERDICT`, `MISSING_CAUTION`, and `HUMAN_ACCEPTANCE_VIOLATION` are not retryable. Only `REPORT_WRITE_FAILED` is retryable, once, at a freshly resolved collision-safe path. Never accept a report when its path, caution, verdict mapping or human acceptance fails validation.
