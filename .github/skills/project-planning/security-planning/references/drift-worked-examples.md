---
title: Security Plan Drift Worked Examples
description: Minimal baseline and finding fixtures with deterministic expected outcomes for correlation and caller regressions.
ms.date: 2026-09-04
ms.topic: reference
---

# Security Plan Drift Worked Examples

These synthetic examples make category, degradation, exclusion, sequence, and caller-regression behavior gradeable.

## Fixture purpose

These synthetic fixtures define expected behavior without containing customer, production, personal, or secret data. They are normative examples for behavior scenarios, not machine-parsed schemas.

## Completed baseline

```json
{
  "projectSlug": "sample-service",
  "securityPlanFile": ".copilot-tracking/security-plans/sample-service/security-plan.md",
  "currentPhase": 6,
  "phaseGates": {
    "phase1": { "gate": "hard", "confirmedAt": "2026-09-01T10:00:00Z" },
    "phase2": { "gate": "summary-and-advance" },
    "phase3": { "gate": "summary-and-advance" },
    "phase4": { "gate": "hard", "confirmedAt": "2026-09-01T11:00:00Z" },
    "phase5": { "gate": "summary-and-advance" },
    "phase6": { "gate": "hard", "confirmedAt": null }
  },
  "bucketsCompleted": ["web/UI/reporting", "identity/auth", "build"],
  "standardsMapped": ["web/UI/reporting", "identity/auth", "build"],
  "handoffGenerated": { "ado": false, "github": false },
  "aiComponents": [],
  "raiEnabled": false,
  "raiScope": "none",
  "raiTier": "none",
  "referencesProcessed": []
}
```

```markdown
## Components

* API gateway at src/api/gateway.ts in the web/UI/reporting bucket
* Authorization policy at src/auth/policy.ts in the identity/auth bucket
* Retired legacy proxy at src/legacy/proxy.ts

## Threats

| ID             | State     | Component            | Risk                               | Mitigation                           | Backlog    |
|----------------|-----------|----------------------|------------------------------------|--------------------------------------|------------|
| T-WEB-001      | mitigated | API gateway          | Unvalidated request input          | CTRL-WEB-INPUT at src/api/gateway.ts | WI-SEC-001 |
| T-IDENTITY-001 | open      | Authorization policy | Missing object-level authorization | CTRL-AUTHZ at src/auth/policy.ts     | WI-SEC-002 |
| T-WEB-002      | accepted  | API gateway          | Verbose error response             | CTRL-ERROR at src/api/gateway.ts     | WI-SEC-003 |
| T-WEB-003      | mitigated | Legacy proxy         | Unsupported transport              | CTRL-LEGACY at src/legacy/proxy.ts   | WI-SEC-004 |
```

## Direct Form B findings

```text
- **ID:** WEB-INPUT
- **Title:** Request validation
- **Status:** PASS
- **Severity:** N/A
- **Location:** src/api/gateway.ts#L20-L44
- **Finding:** Validation is present.
- **Recommendation:** N/A

- **ID:** AUTHZ-OBJECT
- **Title:** Object authorization
- **Status:** FAIL
- **Severity:** HIGH
- **Location:** src/auth/policy.ts#L51-L65
- **Finding:** Object authorization is absent.
- **Recommendation:** Enforce ownership.

- **ID:** ERROR-DETAIL
- **Title:** Error disclosure
- **Status:** PARTIAL
- **Severity:** MEDIUM
- **Location:** src/api/gateway.ts#L80-L92
- **Finding:** The accepted risk remains partially mitigated.
- **Recommendation:** Normalize responses.

- **ID:** SESSION-ROTATE
- **Title:** Session rotation
- **Status:** FAIL
- **Severity:** HIGH
- **Location:** src/auth/session.ts#L12-L29
- **Finding:** Session identifiers are not rotated.
- **Recommendation:** Rotate after authentication.

- **ID:** LEGACY-REMOVED
- **Title:** Legacy proxy
- **Status:** PASS
- **Severity:** N/A
- **Location:** src/legacy/proxy.ts
- **Finding:** The component is absent from repository-wide inventory.
- **Recommendation:** Remove the stale plan item.
```

Expected categories:

| Category                 | Expected entry                                      |
|--------------------------|-----------------------------------------------------|
| Validated controls       | `T-WEB-001` / `CTRL-WEB-INPUT` with `WEB-INPUT`     |
| Control drift            | `T-IDENTITY-001` / `CTRL-AUTHZ` with `AUTHZ-OBJECT` |
| Residual planned risk    | `T-WEB-002` with `ERROR-DETAIL`                     |
| Newly introduced threats | `SESSION-ROTATE`                                    |
| Obsolete plan items      | `T-WEB-003` / `WI-SEC-004` with `LEGACY-REMOVED`    |

These are caller-authored inline Form B records, not Security Reviewer pipeline output. They supply explicit covered locations and therefore exercise all five categories. A path-only location is valid for `LEGACY-REMOVED` because repository inventory can prove that a component is absent without a meaningful line range.

## Security Reviewer Form A findings

A conformant VULN_REPORT_V1 uses `N/A` for Location, Finding, and Recommendation on `PASS` rows:

```text
| ID             | Title                | Status  | Severity | Location                    | Finding                                        | Recommendation               | Verdict   | Justification                              |
|----------------|----------------------|---------|----------|-----------------------------|------------------------------------------------|------------------------------|-----------|--------------------------------------------|
| WEB-INPUT      | Request validation   | PASS    | N/A      | N/A                         | N/A                                            | N/A                          | UNCHANGED | Validation is present.                     |
| AUTHZ-OBJECT   | Object authorization | FAIL    | HIGH     | src/auth/policy.ts#L51-L65  | Object authorization is absent.                | Enforce ownership.           | CONFIRMED | The route reaches data without the policy. |
| ERROR-DETAIL   | Error disclosure     | PARTIAL | MEDIUM   | src/api/gateway.ts#L80-L92  | The accepted risk remains partially mitigated. | Normalize responses.         | CONFIRMED | Internal detail can still escape.          |
| SESSION-ROTATE | Session rotation     | FAIL    | HIGH     | src/auth/session.ts#L12-L29 | Session identifiers are not rotated.           | Rotate after authentication. | CONFIRMED | No matching plan item exists.              |
| LEGACY-REMOVED | Legacy proxy         | PASS    | N/A      | N/A                         | N/A                                            | N/A                          | UNCHANGED | The check passed without a cited location. |
```

Expected Form A result:

| Category                 | Expected result                                                                      |
|--------------------------|--------------------------------------------------------------------------------------|
| Validated controls       | `Insufficient evidence: VULN_REPORT_V1 PASS rows do not include a covered location.` |
| Control drift            | `T-IDENTITY-001` / `CTRL-AUTHZ` with `AUTHZ-OBJECT`                                  |
| Residual planned risk    | `T-WEB-002` with `ERROR-DETAIL`                                                      |
| Newly introduced threats | `SESSION-ROTATE`                                                                     |
| Obsolete plan items      | `Insufficient evidence: VULN_REPORT_V1 PASS rows do not include a covered location.` |

When a finding has only semantic similarity to a plan item and no explicit identity, component, control, bucket, standard, or backlog match, place it only in Limitations and insufficient evidence as unassessed input. It occupies no drift category and is not treated as an unmatched newly introduced threat.

## Edge scenarios

### S2 incomplete baseline

Set `currentPhase` to `3` and remove the threat table. Expected: `baseline-incomplete`; suppress categories requiring threat identities and report each reason.

### S3 schema drift

Remove `aiComponents` and set `standardsMapped` to a string. Expected: two named `schema-drift` notes; do not infer empty AI components or a standards list; suppress dependent RAI signals and mappings.

### S4 exclusions and override

Add findings under `.github/skills/sample/SKILL.md` and `.github/agents/sample.agent.md`. Expected without explicit scope: both dropped and `Filtered findings: 2`. Expected with `scope=.github/skills/sample/`: the skill finding is retained, the agent finding is dropped, the opted-in prefix is reported, and `Filtered findings: 1`.

### S5 new threat

Use the completed baseline and `SESSION-ROTATE`. Expected: newly introduced threat, not control drift, because no plan identity matches and plan facts are extractable.

### S6 diff-scoped evidence

Change the direct Form B source mode to `diff`. Expected: validated controls and obsolete plan items report insufficient evidence; control drift, residual planned risk, and new threats remain eligible.

### S7 unextractable facts

Replace the threat table with unstructured prose whose identities cannot be extracted. Expected: threat facts are `unresolved`; newly introduced threats and residual planned risks report insufficient evidence rather than zero or unmatched findings.

### S8 missing locations

Remove every finding location. Expected: named `input-format-drift` notes and stop before classification because exclusions cannot be enforced.

### S9 category suppression

For every suppressed category in S2, S6, or S7, render `Insufficient evidence: <reason>`. Never omit the category or report a zero count.

### Mixed finding locations

Provide one located record and one location-less record. Expected: classify the located record, exclude the location-less record from observed-evidence categories, and report `Unassessed input: 1`. Do not stop the whole correlation while at least one location permits exclusion filtering.

### Positive RAI handoff

Provide a complete baseline with `aiComponents: []`, `raiEnabled: false`, and one located `owasp-llm` finding. Expected: recommend RAI Planner without dispatch. When either AI state field is schema-drifted, suppress the recommendation instead.

### Explicit baseline precedence

Provide two discoverable candidates plus an explicit valid state path. Expected: use the explicit path without choosing by recency. Provide an explicit path outside `.copilot-tracking/security-plans/`. Expected: reject it and do not fall back silently.

### Empty report sequence

Provide an empty report listing for the requested date. Expected: select `security-audit-<YYYY-MM-DD>-001.md`. Existing `001` and `003` select `004`; a collision retries `005`; a full `001` through `999` range stops without writing.

### Code Review discovery triggers

Exercise a changed path under `.copilot-tracking/security-plans/` and a PR body or linked issue that names a plan. Expected: each discovered reference requires human confirmation before the baseline is read. Declining confirmation preserves the ordinary review without drift.

## Caller regression controls

### S10 Security Reviewer without baseline

Input: ordinary audit or diff request with no baseline argument. Expected: normal VULN report and Scan Completion output only; no drift step, drift body, or drift artifact.

### S11 Security Planner without current evidence

Input: Phase 6 session with no supplied or confirmed reviewer report. Expected: state that drift was not assessed and name a user-run audit or diff; continue the threat-model completeness review; do not dispatch, synthesize findings, mutate state, or advance a gate.

### S12 Code Review without plan context

Input: ordinary diff with no explicit, diff-carried, or confirmed co-located Security Planner baseline. Expected: omit `securityPlanContext`, drift section, and `security_plan_drift`; leave selected perspectives and security findings unchanged.
