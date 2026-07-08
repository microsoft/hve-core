---
title: Data governance controls for release readiness
description: Operational data-governance controls — classification tiers, role-aware redaction, tiered retention, and tamper-evident audit — for production-readiness privacy planning
---

## Data governance controls for release readiness

Operational controls the privacy planner and reviewer apply when a system is approaching production and must demonstrate that regulated data is classified, minimized, redacted, retained, and provably audited. These controls complement the DPIA and data-flow reasoning: DPIA decides whether deeper review is warranted, while these controls specify the concrete data-governance mechanisms a release-readiness review expects to see in place.

Treat this as planning and review guidance, not legal advice. Anchor obligations to the standards packages in the framework index (NIST Privacy Framework, NISTIR 8062, GDPR, CCPA/CPRA, OWASP Top 10 Privacy Risks) and cite source-control identifiers verbatim.

## Data classification tiers

Classify each data element before selecting a control. Record the persona(s) that read or write it.

| Class         | Definition                                                        | Typical control posture                                 |
|---------------|-------------------------------------------------------------------|---------------------------------------------------------|
| Public        | Non-sensitive, publishable                                        | No special handling                                     |
| Internal      | Non-personal but not for public release                           | Access scoping                                          |
| PII           | Identifies or relates to a person                                 | Minimization, access scoping, retention limits          |
| Sensitive-PII | Special-category data (health, biometric, precise location)       | Redaction, strict access, DPIA trigger, short retention |
| Regulated     | Data subject to a specific regime (HIPAA, sector retention rules) | Regime-specific obligations and evidence                |

## Obligations mapping

Map each classified element to the obligations it triggers, then to a concrete control:

- Minimization and lawful basis or consent — collect only what the purpose needs; record the basis.
- Redaction — role-aware masking of personal data in outputs and logs.
- Retention and deletion — tiered schedule with an enforced deletion mechanism.
- Breach handling — detection, notification threshold, and response path.
- Subject access and erasure — how a request is served and evidenced.
- Audit — tamper-evident record of who did what, when, and to which data.

Record each obligation's status as `Present`, `Partial`, or `Missing` with a source-control reference so the reviewer can assert readiness.

## Role-aware redaction

Redaction is a role decision, not a blanket rule. State explicitly who is redacted and who is retained for each output surface. For example, a public or cross-tenant export may redact impacted-person PII while retaining operator identifiers needed for accountability. Never specify "redact everything" — that hides the accountability trail as well as the sensitive data.

## Tiered retention

Retention is tiered, not binary. Capture the full-retention window and the summary-retention window separately, with the deletion or downgrade mechanism for each tier.

| Tier    | Contents                           | Window (example) | Mechanism                    |
|---------|------------------------------------|------------------|------------------------------|
| Full    | Complete record including PII      | 30 days          | Hard delete or crypto-shred  |
| Summary | Aggregated or de-identified record | 7 years          | Retain minimized fields only |

Anchor windows to the applicable regime or contractual requirement; mark proposed windows as assumptions to validate.

## Tamper-evident audit and evidence bundles

An audit trail that can be edited is not evidence. Require tamper-evidence and define what each entry captures and how a per-record evidence bundle is produced.

- Tamper-evidence: append-only or hash-chained log so entries cannot be silently altered.
- Entry captures: actor identity, timestamp, context, and stage or state change.
- Evidence bundle: for a regulated export (for example FOIA or litigation hold), the set of audit entries and source records for one subject, plus a verification step that proves the chain is intact.

## Suggested use

Use this reference during Phase 4 (Controls) and Phase 5 (Impact) to specify concrete data-governance controls, and during a release-readiness review to mark each obligation `Present` / `Partial` / `Missing` against what the codebase actually implements.
