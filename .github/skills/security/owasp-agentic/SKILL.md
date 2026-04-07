---
name: owasp-agentic
description: OWASP Agentic Security Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in AI agent systems - Brought to you by microsoft/hve-core.
license: CC-BY-SA-4.0
user-invocable: false
metadata:
  authors: "OWASP Agentic Security Initiative"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/"
---

# OWASP® Agentic Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP Agentic Top 10 skill.

The skill encodes the **OWASP Top 10 for Agentic Applications (2026)** as structured,
machine-readable references that an agent can query to identify, assess, and remediate
security risks in AI agent systems.

## Normative references (Agentic Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Agent Goal Hijack](references/01-agent-goal-hijack.md)
3. [02 Tool Misuse and Exploitation](references/02-tool-misuse-and-exploitation.md)
4. [03 Identity and Privilege Abuse](references/03-identity-and-privilege-abuse.md)
5. [04 Agentic Supply Chain Vulnerabilities](references/04-agentic-supply-chain-vulnerabilities.md)
6. [05 Unexpected Code Execution](references/05-unexpected-code-execution.md)
7. [06 Memory and Context Poisoning](references/06-memory-and-context-poisoning.md)
8. [07 Insecure Inter-Agent Communication](references/07-insecure-inter-agent-communication.md)
9. [08 Cascading Failures](references/08-cascading-failures.md)
10. [09 Human-Agent Trust Exploitation](references/09-human-agent-trust-exploitation.md)
11. [10 Rogue Agents](references/10-rogue-agents.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the Agentic Top 10 normative documents.
  * `00-vulnerability-index.md` — master index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP Agentic Security numbering.

## Third-Party Attribution

Copyright © OWASP Foundation.
OWASP® Top 10 for Agentic Applications (2026) content is derived from works by the
OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Source: <https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/>
Modifications: Vulnerability descriptions restructured into agent-consumable reference
documents with added detection and remediation guidance.
OWASP® is a registered trademark of the OWASP Foundation. Use does not imply endorsement.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
