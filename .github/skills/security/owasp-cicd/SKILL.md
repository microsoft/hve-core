---
name: owasp-cicd
description: OWASP CI/CD Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in continuous integration and continuous delivery environments - Brought to you by microsoft/hve-core.
license: CC-BY-SA-4.0
user-invocable: false
metadata:
  authors: "OWASP CI/CD Security Project"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-02-16"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://owasp.org/www-project-top-10-ci-cd-security-risks/"
---

# OWASP® CI/CD Top 10 — Skill Entry

This `SKILL.md` is the **entrypoint** for the OWASP CI/CD Top 10 skill.

The skill encodes the **OWASP Top 10 CI/CD Security Risks** as structured, machine-readable references
that an agent can query to identify, assess, and remediate CI/CD pipeline security risks.

## Normative references (CI/CD Top 10)

1. [00 Vulnerability Index](references/00-vulnerability-index.md)
2. [01 Insufficient Flow Control Mechanisms](references/01-insufficient-flow-control-mechanisms.md)
3. [02 Inadequate Identity and Access Management](references/02-inadequate-identity-access-management.md)
4. [03 Dependency Chain Abuse](references/03-dependency-chain-abuse.md)
5. [04 Poisoned Pipeline Execution](references/04-poisoned-pipeline-execution.md)
6. [05 Insufficient PBAC](references/05-insufficient-pbac.md)
7. [06 Insufficient Credential Hygiene](references/06-insufficient-credential-hygiene.md)
8. [07 Insecure System Configuration](references/07-insecure-system-configuration.md)
9. [08 Ungoverned Usage of 3rd Party Services](references/08-ungoverned-usage-of-3rd-party-services.md)
10. [09 Improper Artifact Integrity Validation](references/09-improper-artifact-integrity-validation.md)
11. [10 Insufficient Logging and Visibility](references/10-insufficient-logging-visibility.md)

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — the CI/CD Top 10 normative documents.
  * `00-vulnerability-index.md` — index of all vulnerability identifiers, categories, and cross-references.
  * `01` through `10` — one document per vulnerability aligned with OWASP CI/CD Security numbering.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
