---
title: 'PbD-01: Proactive Not Reactive; Preventative Not Remedial'
description: Privacy by Design reference for anticipating and preventing privacy-invasive events before they occur
---

# 01 Proactive Not Reactive

Identifier: PbD-01
Category: Prevention

## Source mapping

- **Cavoukian Principle 1** — Proactive Not Reactive; Preventative Not Remedial
- **GDPR Art. 25(1)** — Data protection by design requiring appropriate technical and organisational measures
- **APP 1.2** — Open and transparent management of personal information
- **CCPA §1798.100** — Consumer right to know and business obligation to disclose

## Description

Privacy by Design anticipates and prevents privacy-invasive events before they happen. It does not wait for privacy risks to materialize, nor does it offer remedies for resolving privacy infractions once they have occurred. The approach requires organizations to act before the fact — building privacy protections into systems, processes, and business practices from the outset.

This principle shifts the organizational mindset from reactive incident response to proactive privacy architecture. Privacy risks are identified, assessed, and mitigated during design rather than discovered during post-deployment audits or breach investigations.

## Principle checklist

- Privacy impact assessments or reviews are conducted before system design decisions are finalized.
- Privacy risks are identified and documented during requirements gathering, not after deployment.
- A privacy threat model or risk register exists and is maintained throughout the project lifecycle.
- Privacy requirements are included in acceptance criteria for features involving personal data.
- There is a defined process for identifying new privacy risks when functionality changes.
- The team does not rely solely on incident response or breach notification as privacy controls.
- Privacy monitoring and telemetry detect potential issues before they affect data subjects.

## Controls and mitigations

1. Conduct a Privacy Impact Assessment (PIA) or Data Protection Impact Assessment (DPIA) before any new processing activity involving personal data.
2. Include privacy criteria in design review checklists and architecture decision records.
3. Maintain a privacy risk register updated at each design milestone.
4. Integrate privacy checks into CI/CD pipelines (e.g., data classification scanning, PII detection).
5. Establish privacy-specific threat modeling sessions alongside security threat modeling.
6. Define privacy acceptance criteria in user stories that involve personal data handling.
7. Monitor for privacy-relevant anomalies (unusual data access patterns, consent rate changes).

## Anti-patterns

- Privacy is considered only after a regulatory complaint or breach occurs.
- No privacy review exists in the design or architecture phase.
- Privacy requirements are treated as "nice to have" and deferred to future sprints.
- The only privacy control is a breach notification procedure.
- Privacy risks are identified exclusively through external audits rather than internal proactive review.
- Data collection decisions are made without assessing necessity or proportionality upfront.

## Regulatory cross-references

| Regulation | Reference  | Relevance                                                                                      |
|------------|------------|------------------------------------------------------------------------------------------------|
| GDPR       | Art. 25(1) | Requires implementing appropriate measures at the time of determination of means of processing |
| GDPR       | Art. 35    | DPIA required for high-risk processing before processing begins                                |
| APP        | APP 1.2    | Entities must take reasonable steps to implement practices that ensure compliance              |
| CCPA/CPRA  | §1798.100  | Businesses must inform consumers at or before point of collection                              |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.
