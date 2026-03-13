---
name: owasp-top-10
description: OWASP Top 10 for Web Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in web application environments - Brought to you by microsoft/hve-core.
license: MIT
user-invocable: false
metadata:
  authors: "OWASP Web Application Security Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-13"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://owasp.org/Top10/2025/"
---

# Web Vulnerabilities — Skill Entry

This `SKILL.md` is the **entrypoint** for the Web Vulnerabilities skill.

The skill encodes the **OWASP Top 10 for Web Applications (2025)** as structured, machine-readable
references that an agent can query to identify, assess, and remediate web application security
risks.

## Normative references (Web Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Broken Access Control](references/01-broken-access-control.md)
3. [02 Security Misconfiguration](references/02-security-misconfiguration.md)
4. [03 Software Supply Chain Failures](references/03-software-supply-chain-failures.md)
5. [04 Cryptographic Failures](references/04-cryptographic-failures.md)
6. [05 Injection](references/05-injection.md)
7. [06 Insecure Design](references/06-insecure-design.md)
8. [07 Authentication Failures](references/07-authentication-failures.md)
9. [08 Software or Data Integrity Failures](references/08-software-data-integrity-failures.md)
10. [09 Security Logging and Alerting Failures](references/09-security-logging-alerting-failures.md)
11. [10 Mishandling of Exceptional Conditions](references/10-mishandling-exceptional-conditions.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the Web Top 10 normative documents.
  * `00-vulnerability-index.md` — master index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP Web Application Security numbering.
* `assets/` — reusable format and constants blocks.
  * `constants/` — vulnerability catalog and category definitions.
    * `constants-web-catalog-v1.0.0.md`
  * `formats/` — output contract examples.
    * `format-vulnerability-assessment-v1.0.0.md`
    * `format-remediation-checklist-v1.0.0.md`
