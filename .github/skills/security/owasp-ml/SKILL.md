---
name: owasp-ml
description: OWASP Machine Learning Top 10 (2023) vulnerability knowledge base for identifying, assessing, and remediating security risks in machine learning systems - Brought to you by microsoft/hve-core.
license: CC-BY-SA-4.0
user-invocable: false
metadata:
  authors: "OWASP Machine Learning Security Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-16"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://owasp.org/www-project-machine-learning-security-top-10/"
---

# OWASP ML Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP ML Top 10 skill.

The skill encodes the **OWASP Machine Learning Security Top 10** as structured, machine-readable references
that an agent can query to identify, assess, and remediate machine learning security risks.

## Normative references (ML Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Input Manipulation Attack](references/01-input-manipulation-attack.md)
3. [02 Data Poisoning Attack](references/02-data-poisoning-attack.md)
4. [03 Model Inversion Attack](references/03-model-inversion-attack.md)
5. [04 Membership Inference Attack](references/04-membership-inference-attack.md)
6. [05 Model Theft](references/05-model-theft.md)
7. [06 AI Supply Chain Attacks](references/06-ai-supply-chain-attacks.md)
8. [07 Transfer Learning Attack](references/07-transfer-learning-attack.md)
9. [08 Model Skewing](references/08-model-skewing.md)
10. [09 Output Integrity Attack](references/09-output-integrity-attack.md)
11. [10 Model Poisoning](references/10-model-poisoning.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the ML Top 10 normative documents.
  * `00-vulnerability-index.md` — index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP ML Security Top 10 numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
