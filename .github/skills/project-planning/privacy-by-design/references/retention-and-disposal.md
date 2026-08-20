---
title: Retention and Disposal Verification (Principle 05)
description: Lifecycle protection checks, retention validation, secure disposal methods, legal hold exceptions, and failure severity guidance for PbD Principle 5.
---

# Retention and Disposal Verification (Principle 05)

This reference captures the detailed verification checklist for Privacy-by-Design Principle 5: End-to-End Security – Full Lifecycle Protection. It is the authoritative source for assessing data retention, secure disposal, and legal hold compliance.

## Verification Categories

Principle 05 assessment uses four mandatory check categories:

-   **Retention Period Validation** — Purpose-linked, documented, and enforced
-   **Secure Disposal Methods** — Regulatory-compliant deletion across all copies
-   **Legal Hold Exception Handling** — Suspension of disposal during active holds
-   **Indefinite Retention Justification** — Documented legal basis for no expiry

## Classification Guidance

Use this decision order when determining which verification checks apply:

1.  Contains PII or sensitive personal data? → Apply ALL four categories
2.  Contains non-PII business data with regulatory retention requirements? → Apply Retention + Disposal + Legal Hold
3.  Contains transient/ephemeral data with <24h TTL? → Apply Disposal only
4.  Anonymous/aggregated data with no re-identification risk? → Skip Principle 05 entirely

## Mandatory Checklist

### Retention Period Validation

-   [ ] Retention period explicitly documented in policy OR code/config
-   [ ] Retention period directly linked to stated processing purpose
-   [ ] Automated enforcement mechanism exists (TTL, scheduled purge, lifecycle rule)
-   [ ] Retention period reviewed and updated within last 12 months
-   [ ] No indefinite retention without documented legal justification

### Secure Disposal Methods

-   [ ] Deletion method matches data sensitivity and storage medium:
    -   Cryptographic erasure for encrypted-at-rest data
    -   NIST SP 800-88 compliant overwrite for unencrypted block storage
    -   Secure API deletion calls for cloud-managed services
    -   Anonymization/aggregation where physical deletion is infeasible
-   [ ] Disposal verified across ALL copies: primary store, backups, caches, replicas, logs
-   [ ] Audit trail of disposal actions maintained and tamper-evident
-   [ ] Disposal completion confirmed within regulatory timeframe

### Legal Hold Exception Handling

-   [ ] Mechanism exists to suspend automated disposal on demand
-   [ ] Legal hold scope precisely targets affected records/data sets
-   [ ] Hold release triggers resumption of normal disposal schedule
-   [ ] Hold activation/release logged with authorized approver attribution
-   [ ] Held data remains protected under Principle 05 security controls

### Indefinite Retention Justification

-   [ ] Written legal opinion or regulatory citation supporting indefinite retention
-   [ ] Business necessity documented and approved by privacy officer
-   [ ] Periodic re-evaluation scheduled (minimum annual)
-   [ ] Data minimization applied even under indefinite retention (no excess fields)

## Failure Severity Matrix

| Check Category | Missing Check | Default Severity | Escalation Condition |
| :--- | :--- | :--- | :--- |
| Retention Validation | Any unchecked item | HIGH | No documented retention period at all → CRITICAL |
| Secure Disposal | Wrong method or incomplete coverage | HIGH | PII disposed insecurely → CRITICAL |
| Legal Hold | No suspension mechanism | MEDIUM | Active hold ignored; data deleted → CRITICAL |
| Indefinite Retention | No legal justification | CRITICAL | N/A (always CRITICAL) |

> [!WARNING]
> ANY failure in Principle 05 MUST cite at least one legal obligation from `cross-jurisdictional-mapping.md`. Common citations: `gdpr_article_5_1_e`, `gdpr_article_17`, `gdpr_article_32`, `app_11_2`, `ccpa_1798_105_d`.

## Assessment Output Template

Use this format when documenting each Principle 05 finding:

```markdown
### Principle 05 Finding: {brief-description}

Status: PASS | PARTIAL | FAIL
Severity: INFO | LOW | MEDIUM | HIGH | CRITICAL
Evidence: {file:line, config key, or infrastructure resource ID}
Citation: {verbatim_legal_reference}; {additional_if_multi_jurisdiction}
Failed Checks:
* {specific unchecked item from Mandatory Checklist}
Recommendation: {actionable remediation with technical specificity}
