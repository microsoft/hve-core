---
name: owasp-docker
description: OWASP Docker Top 6 vulnerability knowledge base for identifying, assessing, and remediating security risks in containerized Docker environments.
license: MIT
metadata:
  authors: "OWASP Docker Security Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://github.com/OWASP/Docker-Security"
---

# OWASP Docker Top 6 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP Docker Top 6 skill.

The skill encodes the **OWASP Docker Security Top 6** as structured, machine-readable references
that an agent can query to identify, assess, and remediate Docker container security risks.

## Normative references (Docker Top 6)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Secure User Mapping](references/01-secure-user-mapping.md)
3. [02 Patch Management Strategy](references/02-patch-management-strategy.md)
4. [03 Network Segmentation and Firewalling](references/03-network-segmentation-firewalling.md)
5. [04 Secure Defaults and Hardening](references/04-secure-defaults-hardening.md)
6. [05 Maintain Security Contexts](references/05-maintain-security-contexts.md)
7. [06 Resource Protection](references/06-resource-protection.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the Docker Top 6 normative documents.
  * `00-vulnerability-index.md` — index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `06` — one document per vulnerability aligned with OWASP Docker Security numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
