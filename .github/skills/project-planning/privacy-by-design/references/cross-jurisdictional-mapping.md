---
title: Cross-Jurisdictional Mapping
description: Regulatory equivalence matrix mapping PbD principles across GDPR, CCPA/CPRA, and Australian Privacy Principles
---

# Cross-Jurisdictional Mapping

This reference provides a regulatory equivalence matrix to help the Privacy Planner and Reviewer identify applicable obligations when a system operates across multiple jurisdictions.

## Jurisdictional scope triggers

Assess which regulations apply based on:

| Trigger                                     | GDPR            | CCPA/CPRA                  | APP (Australia)                          |
|---------------------------------------------|-----------------|----------------------------|------------------------------------------|
| Entity established in jurisdiction          | Yes (Art. 3(1)) | Yes (Cal. entity)          | Yes (Australian entity)                  |
| Processing data of jurisdiction's residents | Yes (Art. 3(2)) | Yes (CA consumers)         | Possible (APP 2 — extraterritorial)      |
| Revenue threshold                           | N/A             | $25M+ annual revenue       | $3M+ annual turnover (or other triggers) |
| Data volume threshold                       | N/A             | 100K+ consumers/households | N/A                                      |
| Derives revenue from selling data           | N/A             | 50%+ revenue from selling  | N/A                                      |

## PbD principle-to-regulation equivalence matrix

### PbD-01: Proactive Not Reactive

| Obligation                           | GDPR                                            | CCPA/CPRA                                                    | APP                         |
|--------------------------------------|-------------------------------------------------|--------------------------------------------------------------|-----------------------------|
| Privacy assessment before processing | Art. 25(1), Art. 35 (DPIA)                      | No explicit DPIA but CPRA §1798.185(a)(15) audit regulations | APP 1.2 (reasonable steps)  |
| Risk-based approach                  | Art. 24 (appropriate measures considering risk) | §1798.100 (reasonable security)                              | APP 11.1 (reasonable steps) |

### PbD-02: Privacy as the Default

| Obligation                   | GDPR                          | CCPA/CPRA                                                                | APP                                                         |
|------------------------------|-------------------------------|--------------------------------------------------------------------------|-------------------------------------------------------------|
| Data minimization by default | Art. 5(1)(c), Art. 25(2)      | §1798.100(b) (no excess collection)                                      | APP 3 (necessary for functions)                             |
| Opt-in consent model         | Art. 6–7 (consent conditions) | Opt-out model (§1798.120) but sensitive data requires opt-in (§1798.121) | APP 3 (solicited collection requires consent for sensitive) |
| Purpose limitation           | Art. 5(1)(b)                  | §1798.100(c) (compatible purposes)                                       | APP 6 (primary purpose or related secondary)                |

### PbD-03: Privacy Embedded into Design

| Obligation              | GDPR                                | CCPA/CPRA                       | APP                                      |
|-------------------------|-------------------------------------|---------------------------------|------------------------------------------|
| Technical measures      | Art. 25(1) (pseudonymization, etc.) | §1798.100 (reasonable security) | APP 11.1 (reasonable steps)              |
| Organizational measures | Art. 24, Art. 25(1)                 | Implied (reasonable security)   | APP 1.2 (practices, procedures, systems) |

### PbD-04: Full Functionality

| Obligation                               | GDPR                                | CCPA/CPRA                                          | APP                                   |
|------------------------------------------|-------------------------------------|----------------------------------------------------|---------------------------------------|
| Non-discrimination for exercising rights | Art. 7(4) (consent not conditional) | §1798.125 (no discrimination)                      | Implied (APP 3 — fair means)          |
| Service equivalence                      | Art. 7(4)                           | §1798.125(a) (no denial, different price, quality) | Not explicit but fair dealing implied |

### PbD-05: End-to-End Security

| Obligation             | GDPR                   | CCPA/CPRA                                 | APP                                                           |
|------------------------|------------------------|-------------------------------------------|---------------------------------------------------------------|
| Retention limitation   | Art. 5(1)(e)           | §1798.100(e) (disclose period)            | APP 11.2 (destroy when no longer needed)                      |
| Right to deletion      | Art. 17                | §1798.105                                 | APP 11.2 (entity-initiated), APP 13.1 (correction on request) |
| Security of processing | Art. 32                | §1798.100 (reasonable security)           | APP 11.1 (protect from misuse)                                |
| Processor obligations  | Art. 28 (DPA required) | §1798.140(j) (service provider contracts) | APP 8 (cross-border disclosure)                               |

### PbD-06: Visibility and Transparency

| Obligation             | GDPR              | CCPA/CPRA                                   | APP                                                     |
|------------------------|-------------------|---------------------------------------------|---------------------------------------------------------|
| Privacy notice         | Art. 12–14        | §1798.100(a), §1798.130                     | APP 1.3–1.6 (privacy policy), APP 5 (collection notice) |
| Right to access        | Art. 15           | §1798.100, §1798.110                        | APP 12                                                  |
| Records of processing  | Art. 30           | Not explicit but audit requirement emerging | Not explicit but APP 1.2 implies                        |
| Third-party disclosure | Art. 13(1)(e)–(f) | §1798.115 (right to know about sharing)     | APP 1.4(e) (overseas recipients in policy)              |

### PbD-07: Respect for User Privacy

| Obligation                | GDPR                            | CCPA/CPRA                                            | APP                                               |
|---------------------------|---------------------------------|------------------------------------------------------|---------------------------------------------------|
| Consent withdrawal        | Art. 7(3) (as easy as giving)   | §1798.120 (opt-out of sale)                          | APP 7 (can withdraw consent for direct marketing) |
| Data portability          | Art. 20                         | Not in CCPA; CPRA §1798.130(a)(2) (machine-readable) | Not explicit                                      |
| Correction                | Art. 16                         | §1798.106                                            | APP 13                                            |
| Objection to processing   | Art. 21                         | §1798.120 (opt-out of sale/sharing)                  | Not explicit (but APP 7 for direct marketing)     |
| Automated decision-making | Art. 22 (right to human review) | §1798.185 (limit use of sensitive PI)                | Not explicit                                      |

## Key jurisdictional differences

| Aspect                | GDPR                                  | CCPA/CPRA                                       | APP                                                  |
|-----------------------|---------------------------------------|-------------------------------------------------|------------------------------------------------------|
| Consent model         | Opt-in (Art. 6–7)                     | Opt-out (except sensitive: opt-in)              | Consent required for sensitive (APP 3.3)             |
| Enforcement body      | DPAs (each EU member state)           | California AG + CPPA                            | OAIC                                                 |
| Breach notification   | 72 hours to DPA (Art. 33)             | No specific timeline (Cal. Civil Code §1798.82) | Notifiable Data Breaches scheme (30 days assessment) |
| Cross-border transfer | Adequacy + SCCs/BCRs (Ch. V)          | No explicit restriction                         | APP 8 (reasonable steps for overseas recipients)     |
| Children's data       | Art. 8 (parental consent under 16/13) | CalOPPA + COPPA apply                           | APP 3.4 (capacity to consent)                        |
| Maximum fine          | €20M or 4% global turnover            | $7,500 per intentional violation                | A$50M or 30% of turnover (since 2022)                |

## Multi-jurisdictional compliance strategy

When a system spans multiple jurisdictions:

1. Apply the highest common standard across all applicable regulations as the baseline.
2. Implement jurisdiction-specific controls only where a regulation imposes unique obligations (e.g., GDPR cross-border transfer mechanisms).
3. Document which regulations apply and which specific articles govern each data flow.
4. Maintain a jurisdictional applicability register updated when new markets or data residency requirements emerge.
5. Align consent mechanisms with the most restrictive applicable model (typically GDPR opt-in).

---

Content synthesized from GDPR (Regulation (EU) 2016/679), CCPA/CPRA (California Civil Code §1798), and Australian Privacy Act 1988 (Privacy Principles). Paraphrased with attribution for planning use, not legal interpretation.
