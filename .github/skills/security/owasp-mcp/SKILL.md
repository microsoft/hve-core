---
name: owasp-mcp
description: OWASP MCP Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in Model Context Protocol environments - Brought to you by microsoft/hve-core.
license: CC-BY-SA-4.0
user-invocable: false
metadata:
  authors: "OWASP MCP Top 10 Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://owasp.org/www-project-mcp-top-10/"
---

# OWASP MCP Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the MCP Vulnerabilities skill.

The skill encodes the **OWASP MCP Top 10 (2025)** as structured, machine-readable references
that an agent can query to identify, assess, and remediate MCP security risks.

## Normative references (MCP Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Token Mismanagement and Secret Exposure](references/01-token-mismanagement-secret-exposure.md)
3. [02 Privilege Escalation via Scope Creep](references/02-privilege-escalation-scope-creep.md)
4. [03 Tool Poisoning](references/03-tool-poisoning.md)
5. [04 Software Supply Chain Attacks and Dependency Tampering](references/04-supply-chain-attacks-dependency-tampering.md)
6. [05 Command Injection and Execution](references/05-command-injection-execution.md)
7. [06 Prompt Injection via Contextual Payloads](references/06-prompt-injection-contextual-payloads.md)
8. [07 Insufficient Authentication and Authorization](references/07-insufficient-authentication-authorization.md)
9. [08 Lack of Audit and Telemetry](references/08-lack-of-audit-telemetry.md)
10. [09 Shadow MCP Servers](references/09-shadow-mcp-servers.md)
11. [10 Context Injection and Over-Sharing](references/10-context-injection-over-sharing.md)

## Skill layout

- `SKILL.md` — this file (skill entrypoint).
- `references/` — the MCP Top 10 normative documents.
  - `00-vulnerability-index.md` — index of all vulnerability identifiers, severities, and cross-references.
  - `01` through `10` — one document per vulnerability aligned with OWASP MCP numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
