---
name: owasp-llm
description: OWASP Top 10 for LLM Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in large language model systems - Brought to you by microsoft/hve-core.
license: MIT
user-invocable: false
metadata:
  authors: "OWASP LLM Applications Security Initiative"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/"
---

# OWASP LLM Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP LLM Top 10 skill.

The skill encodes the **OWASP Top 10 for LLM Applications (2025)** as structured,
machine-readable references that an agent can query to identify, assess, and remediate
security risks in large language model systems.

## Normative references (LLM Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Prompt Injection](references/01-prompt-injection.md)
3. [02 Sensitive Information Disclosure](references/02-sensitive-information-disclosure.md)
4. [03 Supply Chain](references/03-supply-chain.md)
5. [04 Data and Model Poisoning](references/04-data-and-model-poisoning.md)
6. [05 Improper Output Handling](references/05-improper-output-handling.md)
7. [06 Excessive Agency](references/06-excessive-agency.md)
8. [07 System Prompt Leakage](references/07-system-prompt-leakage.md)
9. [08 Vector and Embedding Weaknesses](references/08-vector-and-embedding-weaknesses.md)
10. [09 Misinformation](references/09-misinformation.md)
11. [10 Unbounded Consumption](references/10-unbounded-consumption.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the LLM Top 10 normative documents.
  * `00-vulnerability-index.md` — index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP LLM Applications numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
