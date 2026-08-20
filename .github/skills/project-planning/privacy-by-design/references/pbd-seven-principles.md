---
title: Privacy-by-Design Seven Foundational Principles
description: PbD principle definitions, PASS/FAIL/PARTIAL assessment criteria, severity guidance, and finding ID conventions for privacy assessment.
---

# Privacy-by-Design Seven Foundational Principles

This reference captures the 7 Foundational Principles of Privacy by Design (Dr. Ann Cavoukian), structured assessment criteria, severity guidance, and finding table conventions used during privacy review.

## PbD Principles

-   **Principle 1: Proactive not Reactive; Preventative not Remedial** — Privacy risks identified and mitigated before deployment
-   **Principle 2: Privacy as the Default Setting** — PII protected automatically without user action required
-   **Principle 3: Privacy Embedded into Design** — Privacy integral to architecture, not bolted on
-   **Principle 4: Full Functionality – Positive-Sum, Not Zero-Sum** — Privacy and functionality coexist without false trade-offs
-   **Principle 5: End-to-End Security – Full Lifecycle Protection** — Data secured from collection through secure disposal
-   **Principle 6: Visibility and Transparency – Keep it Open** — Processing visible to users and auditors
-   **Principle 7: Respect for User Privacy – Keep it User-Centric** — Meaningful consent and full data subject rights support

## Assessment Criteria

For each principle, assign exactly one status with supporting evidence:

| Status | Definition | Severity Default |
| :--- | :--- | :--- |
| PASS | Principle fully satisfied with documented evidence | INFO |
| PARTIAL | Principle partially satisfied; gaps identified but mitigations in progress | MEDIUM |
| FAIL | Principle not satisfied; no evidence or active violation | HIGH |

> [!WARNING]
> Principle 5 failures default to HIGH severity. Indefinite retention without legal justification escalates to CRITICAL. Always consult `retention-and-disposal.md` for Principle 5 verification.

## Finding ID Pattern

Use `PBD-{PRINCIPLE_NUMBER}-{NNN}` for standard findings and `PBD-{PRINCIPLE_NUMBER}-XJ-{NNN}` for cross-jurisdictional findings that map to multiple legal obligations.

Examples:

-   `PBD-02-001`: Privacy as Default failure in consent flow
-   `PBD-05-XJ-003`: Lifecycle protection gap violating both GDPR Art. 17 and APP 11.2

## Finding Table Format

| ID | Principle | Status | Severity | Evidence | Citation | Recommendation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| PBD-02-001 | 2. Default | FAIL | HIGH | `src/components/CookieBanner.tsx:42` defaults to opt-out | gdpr_article_25_2 | Change default to opt-in; require explicit consent toggle |
| PBD-05-XJ-003 | 5. Lifecycle | PARTIAL | MEDIUM | S3 bucket lacks lifecycle policy; manual deletion only | gdpr_article_17; app_11_2 | Implement automated TTL; add cryptographic erasure for backups |

## Cross-Jurisdictional Assessment Guidance

When assessing any principle, always consult `cross-jurisdictional-mapping.md` to identify all applicable legal obligations. A single codebase gap may violate multiple jurisdictions simultaneously — cite ALL applicable sources separated by semicolon in the `Citation` field.

### Mandatory Verification Points

-   **Principle 2**: Verify opt-in (not opt-out) for all secondary data uses
-   **Principle 5**: Always load `retention-and-disposal.md` for detailed checklist
-   **Principle 6**: Confirm audit logs exist AND are accessible to compliance reviewers
-   **Principle 7**: Test consent withdrawal end-to-end; verify DSR fulfillment within regulatory timelines
