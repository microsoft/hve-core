---
title: 'SBD-04: Supply Chain Security'
description: Secure by Design reference for supply chain security covering third-party assessment, dependency management, SBOM, and verifiable artifacts
---

# 04 Supply Chain Security

Identifier: SBD-04
Category: Supply Chain

## Source mapping

* **UK Principle 2** — Source secure technology products
* **AU Foundation 3** — Secure product development (supply chain aspects)

## Description

Supply chain security requires performing security due diligence on third-party products by
continually assessing platforms, software, and code for security vulnerabilities. Risks must be
mitigated and findings shared with suppliers to help improve product security.

Technology manufacturers must protect their supply chains, including AI-generated code, open-source
code, and all transitive dependencies. An SBOM (Software Bill of Materials) provides visibility
into all components. Technology consumers should demand products from manufacturers who are open
and transparent about their Secure by Design practices—a concept known as Secure by Demand.

## Principle checklist

* Third-party dependencies are inventoried and tracked through an SBOM.
* Dependencies are pinned to specific versions with integrity verification (checksums or signatures).
* Automated vulnerability scanning runs against all direct and transitive dependencies.
* A process exists for evaluating and approving new third-party components.
* Known vulnerable dependencies are patched or replaced within defined SLAs.
* AI-generated code undergoes the same review and scanning as human-written code.
* Third-party product security risks are assessed before procurement decisions.
* Supplier security practices and attestations are evaluated during due diligence.

## Controls and mitigations

1. Generate and maintain an SBOM for all deployable artifacts.
2. Pin all dependencies to exact versions; verify integrity through checksums or signatures.
3. Run automated dependency vulnerability scanning (SCA) in the CI pipeline.
4. Define SLAs for patching critical (24h), high (7d), medium (30d), and low (90d) vulnerabilities.
5. Establish an approval process for introducing new third-party components.
6. Evaluate supplier security practices, certifications, and vulnerability disclosure programs.
7. Monitor third-party components for newly disclosed vulnerabilities post-deployment.
8. Treat AI-generated code as untrusted input subject to full review and scanning.
9. Produce verifiable build artifacts through reproducible builds and artifact signing.
10. Assess open-source project health (maintenance activity, security responsiveness, bus factor).

## Anti-patterns

* Dependencies are imported without version pinning or integrity checks.
* No inventory exists for third-party components used in the product.
* Vulnerability scanning runs only at build time, not continuously.
* AI-generated code is accepted without review or scanning.
* Third-party components are selected based solely on functionality without security evaluation.
* Known vulnerable dependencies persist without a remediation timeline.
* Transitive dependencies are ignored in security assessments.

## OWASP cross-references

* A03:2025 Software Supply Chain Failures — dependency vulnerabilities and integrity failures.
* A08:2025 Software or Data Integrity Failures — unsigned or unverified third-party components.
* A02:2025 Security Misconfiguration — insecure default configurations in third-party products.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
