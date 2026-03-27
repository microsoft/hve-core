---
name: secure-by-design
description: Secure by Design principles knowledge base for assessing adherence to security-first design, development, and deployment practices across the software lifecycle - Brought to you by microsoft/hve-core.
license: MIT
user-invocable: false
metadata:
  authors: "UK Government Security Group, Australian Signals Directorate (ASD) ACSC"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-03-27"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on:
    - "https://www.security.gov.uk/policy-and-guidance/secure-by-design/principles/"
    - "https://www.cyber.gov.au/business-government/secure-design/secure-by-design/secure-by-design-foundations"
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
  * `00-principle-index.md` — master index of all principle identifiers, categories, source mappings, and cross-references.
  * `01` through `11` — one document per synthesized principle area merging UK and AU guidance.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
