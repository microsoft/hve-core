---
title: 'SBD-03: Secure Product Development'
description: Secure by Design reference for secure development practices covering secure coding, code review, cryptography, and change management
---

# 03 Secure Product Development

Identifier: SBD-03
Category: Secure Development

## Source mapping

* **UK Principle 10** — Make changes securely
* **AU Foundation 3** — Secure product development

## Description

Secure product development requires embedding security into design, development, and deployment
processes so that the security impact of changes is considered alongside other factors. Quality
design and considered architecture form the foundation, along with an understanding of the attack
surface and threats that a product must be protected against.

Technology manufacturers must develop products to be Secure by Default, meaning security features
are included with the most secure settings configured by default. A secure development environment
protects products from unauthorized, vulnerable, or malicious changes throughout the development
lifecycle. By maturing development environments, teams can automate and shift security assurance
to enhance both productivity and security.

## Principle checklist

* Secure coding standards are documented and enforced through automated tooling.
* Code reviews include security-focused review criteria.
* Security and audit logging is implemented for sensitive operations.
* Cryptographic implementations use established libraries and current algorithms.
* Data flows, storage locations, and classification are documented.
* Data is protected in all three states: at-rest, in-transit, and in-use.
* Authentication and authorization mechanisms use established frameworks.
* Error handling does not expose sensitive information or stack traces.
* Source code scanning (SAST) runs in the CI pipeline.
* Changes undergo security impact evaluation before deployment.
* Memory-safe language use is preferred where feasible.
* Development environments are hardened against unauthorized access.

## Controls and mitigations

1. Adopt and enforce secure coding standards appropriate to the language and framework.
2. Require security-focused code review for changes affecting authentication, authorization,
   cryptography, input handling, and data access.
3. Implement SAST in the CI/CD pipeline with blocking thresholds for critical findings.
4. Use established cryptographic libraries; prohibit custom cryptographic implementations.
5. Document data flows including classification, boundaries, and retention policies.
6. Encrypt data at rest and in transit using current standards (TLS 1.2+, AES-256).
7. Implement structured logging for security events with tamper-evident storage.
8. Ensure error responses use generic messages; log detailed errors server-side only.
9. Evaluate the security impact of all changes through a defined change management process.
10. Prefer memory-safe languages for new components; create roadmaps for migrating unsafe code.
11. Protect development environments with access controls, MFA, and audit logging.
12. Generate and maintain architectural blueprints documenting security boundaries.

## Anti-patterns

* Security reviews are skipped for "minor" or "internal" changes.
* Custom cryptographic algorithms or homegrown authentication schemes are used.
* Error messages expose stack traces, database queries, or internal paths to end users.
* Secrets, credentials, or API keys are committed to source control.
* Data classification is unknown or undocumented.
* SAST findings are suppressed without risk-based justification.
* Development environments share credentials or lack access controls.
* Changes are deployed without evaluating their security impact.

## OWASP cross-references

* A04:2025 Cryptographic Failures — weak or custom cryptography.
* A05:2025 Injection — absent input validation in code.
* A06:2025 Insecure Design — missing security architecture and threat models.
* A08:2025 Software or Data Integrity Failures — unsigned or unverified artifacts.
* A10:2025 Mishandling of Exceptional Conditions — information leakage through error handling.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
