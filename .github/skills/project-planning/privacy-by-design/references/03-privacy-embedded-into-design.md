---
title: 'PbD-03: Privacy Embedded into Design'
description: Privacy by Design reference for embedding privacy into the design and architecture of systems and business practices
---

# 03 Privacy Embedded into Design

Identifier: PbD-03
Category: Architecture

## Source mapping

- **Cavoukian Principle 3** — Privacy Embedded into Design
- **GDPR Art. 25(1)** — Implement appropriate technical and organisational measures designed to implement data-protection principles
- **APP 1.2** — Take reasonable steps to implement practices, procedures, and systems for compliance
- CCPA §1798.100(e): Implement reasonable security procedures

## Description

Privacy requirements should shape data models, component boundaries and processing paths before implementation. Assess whether those requirements are enforced by the architecture and ordinary operating procedures, rather than relying on a policy notice or a late review to compensate for an unsuitable design.

This principle requires that privacy considerations are woven into the technical architecture, data models, access control layers, and business process flows from the earliest design stage. Privacy is treated as a first-class architectural concern alongside security, performance, and reliability.

## Principle checklist

- Privacy requirements are documented in architecture decision records or design specifications.
- Data flows are designed with privacy controls as integral components (not optional add-ons).
- Personal data is classified and labeled in data models and schemas.
- Access control architectures enforce need-to-know and purpose limitation at the system level.
- Data minimization is enforced architecturally (e.g., field-level encryption, tokenization, pseudonymization).
- Privacy-enhancing technologies (PETs) are evaluated during technology selection.
- System boundaries explicitly define where personal data enters, moves, and exits.
- Privacy controls are tested as part of the standard QA process, not as a separate audit.

## Controls and mitigations

1. Include privacy as a dimension in architecture reviews and design documents.
2. Use data flow diagrams that highlight personal data paths and processing purposes.
3. Implement purpose-binding at the data layer (tag data with processing purpose at collection).
4. Apply pseudonymization or tokenization where full identity is not required for processing.
5. Architect systems with privacy boundaries that limit data exposure between components.
6. Select privacy-enhancing technologies (differential privacy, homomorphic encryption, secure enclaves) where appropriate.
7. Document privacy architectural decisions in ADRs with explicit trade-off analysis.
8. Include privacy-specific test cases in integration and system testing.

## Anti-patterns

- Privacy is addressed only through a privacy policy document without technical implementation.
- Personal data flows freely between system components without purpose limitation.
- No data classification exists in the data model.
- Privacy controls are implemented as a separate module bolted onto an existing system.
- Privacy reviews happen only at the end of development, too late to influence architecture.
- Privacy-enhancing technologies are dismissed without evaluation because of perceived complexity.

## Regulatory cross-references

| Regulation | Reference    | Relevance                                                                                 |
|------------|--------------|-------------------------------------------------------------------------------------------|
| GDPR       | Art. 25(1)   | Technical and organisational measures to implement data-protection principles effectively |
| GDPR       | Art. 5(1)(f) | Integrity and confidentiality — appropriate security of personal data                     |
| APP        | APP 1.2      | Reasonable steps to implement practices, procedures, and systems                          |
| APP        | APP 11.1     | Reasonable steps to protect personal information from misuse, interference, and loss      |
| CCPA/CPRA  | §1798.100(e) | Reasonable security procedures and practices                                              |

---

Content paraphrased from Dr. Ann Cavoukian's 7 Foundation Principles of Privacy by Design (2009) with attribution. Regulatory mappings are planning references, not legal interpretations.

Official sources: [IPC Ontario](https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf), [GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj), [APPs](https://www.oaic.gov.au/privacy/australian-privacy-principles/read-the-australian-privacy-principles), and [CCPA](https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CIV&sectionNum=1798.100).
