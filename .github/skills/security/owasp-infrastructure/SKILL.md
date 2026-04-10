---
name: owasp-infrastructure
description: OWASP Infrastructure Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in internal IT infrastructure environments - Brought to you by microsoft/hve-core.
license: CC-BY-SA-4.0
user-invocable: false
metadata:
  authors: "OWASP Infrastructure Security Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://owasp.org/www-project-top-10-infrastructure-security-risks/"
---

# OWASP Infrastructure Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP Infrastructure Top 10 skill.

The skill encodes the **OWASP Infrastructure Security Top 10 (2024)** as structured,
machine-readable references that an agent can query to identify, assess, and remediate
infrastructure security risks.

## Normative references (Infrastructure Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Outdated Software](references/01-outdated-software.md)
3. [02 Insufficient Threat Detection](references/02-insufficient-threat-detection.md)
4. [03 Insecure Configurations](references/03-insecure-configurations.md)
5. [04 Insecure Resource and User Management](references/04-insecure-resource-user-management.md)
6. [05 Insecure Use of Cryptography](references/05-insecure-use-of-cryptography.md)
7. [06 Insecure Network Access Management](references/06-insecure-network-access-management.md)
8. [07 Insecure Authentication Methods and Default Credentials](references/07-insecure-authentication-default-credentials.md)
9. [08 Information Leakage](references/08-information-leakage.md)
10. [09 Insecure Access to Resources and Management Components](references/09-insecure-access-resources-management-components.md)
11. [10 Insufficient Asset Management and Documentation](references/10-insufficient-asset-management-documentation.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the Infrastructure Top 10 normative documents.
  * `00-vulnerability-index.md` — index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP Infrastructure Security numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
