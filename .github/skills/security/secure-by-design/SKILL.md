---
name: secure-by-design
description: Secure by Design principles knowledge base for assessing adherence to security-first design, development, and deployment practices across the software lifecycle - Brought to you by microsoft/hve-core.
license: OGL-UK-3.0 AND CC-BY-4.0
user-invocable: false
metadata:
  authors: "UK Government Security Group, Australian Signals Directorate (ASD) ACSC"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-03-27"
  content_based_on: "https://www.security.gov.uk/policy-and-guidance/secure-by-design/principles/ AND https://www.cyber.gov.au/business-government/secure-design/secure-by-design/secure-by-design-foundations"
---

# Secure by Design — Skill Entry

This `SKILL.md` is the **entrypoint** for the Secure by Design skill.

The skill synthesizes the **UK Government Secure by Design Principles** (10 principles) and the
**Australian ASD/ACSC Secure by Design Foundations** (6 foundations) into structured,
machine-readable references that an agent can query to identify, assess, and improve adherence to
secure-by-design practices across the software lifecycle.

## Normative references (Secure by Design)

1. [00 Principle Index](references/00-principle-index.md)
2. [01 Security Governance](references/01-security-governance.md)
3. [02 Risk-Driven Approach](references/02-risk-driven-approach.md)
4. [03 Secure Product Development](references/03-secure-product-development.md)
5. [04 Supply Chain Security](references/04-supply-chain-security.md)
6. [05 Usable Security Controls](references/05-usable-security-controls.md)
7. [06 Detect and Respond](references/06-detect-and-respond.md)
8. [07 Flexible Architecture](references/07-flexible-architecture.md)
9. [08 Minimize Attack Surface](references/08-minimize-attack-surface.md)
10. [09 Defense in Depth](references/09-defense-in-depth.md)
11. [10 Continuous Assurance](references/10-continuous-assurance.md)
12. [11 Secure Deprecation](references/11-secure-deprecation.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the Secure by Design normative documents.
  * `00-principle-index.md` — index of all principle identifiers, categories, source mappings, and cross-references.
  * `01` through `11` — one document per synthesized principle area merging UK and AU guidance.

## Third-Party Attribution

### UK Government Secure by Design Principles

* **Copyright**: Crown Copyright, UK Government Security Group
* **License**: [Open Government Licence v3.0 (OGL-UK-3.0)](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
* **Source**: <https://www.security.gov.uk/policy-and-guidance/secure-by-design/principles/>
* **Modifications**: Synthesized into structured principle-checklist format with cross-references; merged with Australian guidance into unified principle areas
* **Trademark**: Use of UK Government content does not imply endorsement

### Australian ASD/ACSC Secure by Design Foundations

* **Copyright**: © Commonwealth of Australia, Australian Signals Directorate
* **License**: [Creative Commons Attribution 4.0 (CC-BY-4.0)](https://creativecommons.org/licenses/by/4.0/)
* **Source**: <https://www.cyber.gov.au/business-government/secure-design/secure-by-design/secure-by-design-foundations>
* **Modifications**: Synthesized into structured principle-checklist format with cross-references; merged with UK guidance into unified principle areas
* **Trademark**: Use of ASD/ACSC content does not imply endorsement

---
