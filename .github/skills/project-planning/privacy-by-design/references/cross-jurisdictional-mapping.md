---
title: Cross-Jurisdictional Mapping
description: Regulatory equivalence matrix mapping PbD principles across GDPR, CCPA/CPRA, and Australian Privacy Principles
---

# Cross-Jurisdictional Mapping

This reference provides a regulatory equivalence matrix to help the Privacy Planner and Reviewer identify applicable obligations when a system operates across multiple jurisdictions.

## Jurisdictional scope triggers

Assess which regulations apply based on:

| Trigger                                     | GDPR                                    | CCPA/CPRA                       | APP (Australia)                                 |
|---------------------------------------------|-----------------------------------------|---------------------------------|-------------------------------------------------|
| Entity established in jurisdiction          | Yes (Art. 3(1))                         | Yes (Cal. entity)               | Yes (Australian entity)                         |
| Processing data of jurisdiction's residents | Assess targeting/monitoring (Art. 3(2)) | Assess statutory business scope | Assess Australian link (Privacy Act 1988, s 5B) |
| Revenue threshold                           | N/A                                     | $25M+ annual revenue            | $3M+ annual turnover (or other triggers)        |
| Data volume threshold                       | N/A                                     | 100K+ consumers/households      | N/A                                             |
| Derives revenue from selling data           | N/A                                     | 50%+ revenue from selling       | N/A                                             |

## PbD principle-to-regulation equivalence matrix

### PbD-01: Proactive Not Reactive

| Obligation                           | GDPR                                            | CCPA/CPRA                                                    | APP                         |
|--------------------------------------|-------------------------------------------------|--------------------------------------------------------------|-----------------------------|
| Privacy assessment before processing | Art. 25(1), Art. 35 (DPIA)                      | No explicit DPIA but CPRA §1798.185(a)(15) audit regulations | APP 1.2 (reasonable steps)  |
| Risk-based approach                  | Art. 24 (appropriate measures considering risk) | §1798.100(e) (reasonable security)                           | APP 11.1 (reasonable steps) |

### PbD-02: Privacy as the Default

| Obligation                   | GDPR                                           | CCPA/CPRA                                                                                  | APP                                                                   |
|------------------------------|------------------------------------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| Data minimization by default | Art. 5(1)(c), Art. 25(2)                       | §1798.100(c) (necessary and proportionate processing)                                      | APP 3 (necessary for functions)                                       |
| Consent and choice           | Art. 6–7 (lawful bases and consent conditions) | Sale/sharing opt-out (§1798.120); sensitive-use limitation (§1798.121), not blanket opt-in | APP 3.3 (sensitive collection consent, subject to APP 3.4 exceptions) |
| Purpose limitation           | Art. 5(1)(b)                                   | §1798.100(c) (compatible purposes)                                                         | APP 6 (primary purpose or related secondary)                          |

### PbD-03: Privacy Embedded into Design

| Obligation              | GDPR                                | CCPA/CPRA                          | APP                                      |
|-------------------------|-------------------------------------|------------------------------------|------------------------------------------|
| Technical measures      | Art. 25(1) (pseudonymization, etc.) | §1798.100(e) (reasonable security) | APP 11.1 (reasonable steps)              |
| Organizational measures | Art. 24, Art. 25(1)                 | Implied (reasonable security)      | APP 1.2 (practices, procedures, systems) |

### PbD-04: Full Functionality

| Obligation                               | GDPR                                | CCPA/CPRA                                          | APP                                   |
|------------------------------------------|-------------------------------------|----------------------------------------------------|---------------------------------------|
| Non-discrimination for exercising rights | Art. 7(4) (consent not conditional) | §1798.125 (no discrimination)                      | Implied (APP 3 — fair means)          |
| Service equivalence                      | Art. 7(4)                           | §1798.125(a) (no denial, different price, quality) | Not explicit but fair dealing implied |

### PbD-05: End-to-End Security

| Obligation             | GDPR                   | CCPA/CPRA                                                              | APP                                                             |
|------------------------|------------------------|------------------------------------------------------------------------|-----------------------------------------------------------------|
| Retention limitation   | Art. 5(1)(e)           | §1798.100(a)(3) (disclose period or criteria)                          | APP 11.2 (destroy/de-identify, subject to statutory exceptions) |
| Right to deletion      | Art. 17                | §1798.105                                                              | APP 11.2 (entity-initiated), APP 13.1 (correction on request)   |
| Security of processing | Art. 32                | §1798.100(e) (reasonable security)                                     | APP 11.1 (protect from misuse)                                  |
| Processor obligations  | Art. 28 (DPA required) | §1798.100(d) (third-party, service provider and contractor agreements) | APP 8 (cross-border disclosure)                                 |

### PbD-06: Visibility and Transparency

| Obligation             | GDPR              | CCPA/CPRA                                   | APP                                                          |
|------------------------|-------------------|---------------------------------------------|--------------------------------------------------------------|
| Privacy notice         | Art. 12–14        | §1798.100(a), §1798.130                     | APP 1.3–1.6 (privacy policy), APP 5 (collection notice)      |
| Right to access        | Art. 15           | §1798.100, §1798.110                        | APP 12                                                       |
| Records of processing  | Art. 30           | Not explicit but audit requirement emerging | Not explicit but APP 1.2 implies                             |
| Third-party disclosure | Art. 13(1)(e)–(f) | §1798.115 (right to know about sharing)     | APP 1.4(f)–(g) (overseas recipients and countries in policy) |

### PbD-07: Respect for User Privacy

| Obligation                | GDPR                                            | CCPA/CPRA                                             | APP                                               |
|---------------------------|-------------------------------------------------|-------------------------------------------------------|---------------------------------------------------|
| Consent withdrawal        | Art. 7(3) (as easy as giving)                   | §1798.120 (opt-out of sale)                           | APP 7 (can withdraw consent for direct marketing) |
| Data portability          | Art. 20                                         | Not in CCPA; CPRA §1798.130(a)(2) (machine-readable)  | Not explicit                                      |
| Correction                | Art. 16                                         | §1798.106                                             | APP 13                                            |
| Objection to processing   | Art. 21                                         | §1798.120 (opt-out of sale/sharing)                   | Not explicit (but APP 7 for direct marketing)     |
| Automated decision-making | Art. 22 (safeguards for covered decisions)      | §1798.185 (rulemaking; verify applicable regulations) | Not explicit                                      |
| Sensitive-information use | Art. 9 (special-category processing conditions) | §1798.121 (right to limit use and disclosure)         | APP 3.3, APP 6 (collection and use restrictions)  |

## Key jurisdictional differences

| Aspect                | GDPR                                                     | CCPA/CPRA                                                                                                            | APP                                                     |
|-----------------------|----------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| Consent model         | Consent is one lawful basis (Art. 6–7)                   | Sale/sharing opt-out; sensitive-use limits (§1798.121)                                                               | Sensitive collection consent (APP 3.3), with exceptions |
| Enforcement body      | DPAs (each EU member state)                              | California AG + CPPA                                                                                                 | OAIC                                                    |
| Breach notification   | Generally within 72 hours to DPA when required (Art. 33) | Resident notice within 30 calendar days of discovery/notification, subject to permitted delays (§1798.82(a)(2), (c)) | Notifiable Data Breaches scheme (30 days assessment)    |
| Cross-border transfer | Adequacy + SCCs/BCRs (Ch. V)                             | No explicit restriction                                                                                              | APP 8 (reasonable steps for overseas recipients)        |
| Children's data       | Art. 8 (parental consent under 16/13)                    | CalOPPA + COPPA apply                                                                                                | Capacity assessed case by case (OAIC Chapter B)         |
| Maximum fine          | €20M or 4% global turnover                               | $7,500 per intentional violation                                                                                     | A$50M or 30% of turnover (since 2022)                   |

## Multi-jurisdictional compliance strategy

When a system spans multiple jurisdictions:

1. Apply the highest common standard across all applicable regulations as the baseline.
2. Implement jurisdiction-specific controls only where a regulation imposes unique obligations (e.g., GDPR cross-border transfer mechanisms).
3. Document which regulations apply and which specific articles govern each data flow.
4. Maintain a jurisdictional applicability register updated when new markets or data residency requirements emerge.
5. Identify the applicable lawful basis and consent or choice obligations for each purpose; a privacy-protective default does not mean every regime requires consent for all processing.

The California notice timing above reflects SB 446, effective January 1, 2026. Permitted delays address law-enforcement needs or work necessary to establish breach scope and restore system integrity. Section 1798.82 is a separate breach-notice duty, not a CCPA subsection. APP 2 concerns anonymity and pseudonymity, not extraterritorial scope.

---

Content synthesized from GDPR (Regulation (EU) 2016/679), CCPA/CPRA (California Civil Code §1798), and Australian Privacy Act 1988 (Privacy Principles). Paraphrased with attribution for planning use, not legal interpretation.

Official sources:

- [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj)
- [CCPA general duties, §1798.100](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.100)
- [Sensitive-use limits, §1798.121](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.121)
- [California breach notification, §1798.82](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.82)
- [Australian Privacy Principles](https://www.oaic.gov.au/privacy/australian-privacy-principles/read-the-australian-privacy-principles)
- [OAIC Chapter B, Australian link and capacity](https://www.oaic.gov.au/privacy/australian-privacy-principles-guidelines/chapter-b-key-concepts)
