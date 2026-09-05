---
title: Finding Formats
description: Finding Serialization Format and Verified Findings Collection Format for inter-subagent data exchange
---

# Finding Formats

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

## RAI Finding and Verification Formats

`RAI_FINDING_V1` contains ID, Title, Status, Severity, Location, Finding, and Recommendation.
For verifier input, Status is FAIL or PARTIAL and every field is required.

`RAI_DEEP_VERIFICATION_V1` contains Schema, Finding ID, Finding Title, Original Status, Original
Severity, Framework, Requirement, Confirming Evidence, Contradicting Evidence, Necessary
Capability Assessment and rationale, Verdict, Verified Status, Verified Severity, Verified
Categories, Justification, Updated Recommendation, and Limitations. Required verdicts are
CONFIRMED, DISPROVED, and DOWNGRADED. Necessary Capability Assessment is REQUIRED, AVOIDABLE, or
NOT_APPLICABLE. Verified Categories contains evidence-supported AI STRIDE categories,
NO_CATEGORY, or NOT_ASSESSED.

The total mapping is: CONFIRMED retains the source-supported FAIL or PARTIAL status, severity,
and residual categories; DOWNGRADED maps to PARTIAL with lower evidence-supported severity; and
DISPROVED maps to PASS, NONE, and NO_CATEGORY. A verifier never emits UNCHANGED.

`RAI_VERIFIED_FINDINGS_COLLECTION_V1` groups each framework's findings. FAIL and PARTIAL items
are exactly one `RAI_DEEP_VERIFICATION_V1` response; PASS and NOT_ASSESSED items
are `RAI_FINDING_V1` records with Verdict=UNCHANGED. Every input finding occurs exactly once.

`RAI_PLAN_FINDINGS_COLLECTION_V1` groups framework findings with ID, Title, Status, Severity,
Finding, Recommendation, and optional limitation. Status is RISK, CAUTION, COVERED, or
NOT_APPLICABLE. Verification fields are prohibited.

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
