---
title: 'PbD-06: Visibility and Transparency — Keep It Open'
description: Privacy by Design reference for ensuring visibility and transparency in personal data practices
---

# 06 Visibility and Transparency

Identifier: PbD-06
Category: Openness

## Source mapping

- **Cavoukian Principle 6** — Visibility and Transparency — Keep It Open
- **GDPR Art. 12–14** — Transparent information, communication, and modalities
- **APP 1** — Open and transparent management of personal information
- **APP 5** — Notification of the collection of personal information
- **CCPA §1798.100(a)** — Right to know what personal information is collected

## Description

People need understandable information about actual processing, and reviewers need evidence that can confirm or challenge those disclosures. Assess both the accessibility of notices and the accuracy of their claims against current operating records; publishing a policy is not proof that the system follows it.

Transparency builds trust. Organizations must be able to demonstrate that their data handling practices match their stated policies, and data subjects must have visibility into how their data is used. Accountability and auditability are the mechanisms through which transparency is maintained.

## Principle checklist

- A clear, accessible privacy notice accurately describes collection, use, sharing and retention, consistent with current operational evidence.
- Privacy notices are written in plain language appropriate for the target audience.
- Data processing activities are documented in a processing register (records of processing activities).
- Data subjects can request and receive information about what data is held about them.
- Third-party data sharing is disclosed including recipients and purposes.
- Privacy practices are subject to independent verification or audit.
- Changes to data practices are communicated to affected users before taking effect.
- Complaint and inquiry mechanisms are accessible and responsive.

Reconcile contradictory evidence before PASS. For example, a 30-day destruction promise with eSIM data still recoverable at day 120 establishes an accuracy gap unless an applicable, disclosed exception explains the difference. Record both sources and dates, assess the affected transparency check as NOT MET, and cross-reference PbD-05. Preserve MET credit for independently verified notice accessibility, contact routes and other unaffected controls. If the evidence cannot establish which account applies, use INSUFFICIENT EVIDENCE for that check, not an unqualified PASS.

## Controls and mitigations

1. Maintain a publicly accessible privacy notice that is reviewed and updated at least annually.
2. Implement a Records of Processing Activities (ROPA) register for internal accountability.
3. Provide a self-service data access mechanism (data subject access request portal or API).
4. Publish a transparency report covering government requests, data incidents, and privacy metrics.
5. Conduct periodic independent privacy audits or certify against privacy standards (ISO 27701, SOC 2 Type II Privacy).
6. Version-control privacy notices and notify users of material changes.
7. Establish a privacy contact (DPO, privacy team) with clear escalation paths.
8. Log and respond to privacy inquiries within defined SLAs.

## Anti-patterns

- Privacy notices are written in dense legal language that users cannot understand.
- No records of processing activities exist internally.
- Users have no mechanism to discover what data is held about them.
- Data sharing with third parties is undisclosed or buried in terms and conditions.
- Privacy practices cannot be independently verified.
- Changes to data handling are made silently without notification to affected users.
- Complaint mechanisms are non-functional or unresponsive.
- Published retention or deletion promises conflict with verified operational behavior.

## Regulatory cross-references

| Regulation | Reference    | Relevance                                                             |
|------------|--------------|-----------------------------------------------------------------------|
| GDPR       | Art. 12      | Transparent, intelligible, easily accessible communication            |
| GDPR       | Art. 13–14   | Information to be provided at collection and when obtained indirectly |
| GDPR       | Art. 15      | Right of access by the data subject                                   |
| GDPR       | Art. 30      | Records of processing activities                                      |
| APP        | APP 1.3–1.6  | APP privacy policy requirements                                       |
| APP        | APP 5        | Notification of collection                                            |
| APP        | APP 12       | Access to personal information                                        |
| CCPA/CPRA  | §1798.100(a) | Right to know categories and purposes                                 |
| CCPA/CPRA  | §1798.110    | Right to know specific pieces of information                          |
| CCPA/CPRA  | §1798.130    | Methods for submitting consumer requests                              |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.

Official sources: [IPC Ontario](https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf), [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj), [APPs](https://www.oaic.gov.au/privacy/australian-privacy-principles/read-the-australian-privacy-principles), and [CCPA](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.100).
