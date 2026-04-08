---
title: 'SBD-10: Continuous Assurance'
description: Secure by Design reference for continuous assurance covering security testing, vulnerability management, and ongoing compliance verification
---

# 10 Continuous Assurance

Identifier: SBD-10
Category: Assurance and Testing

## Source mapping

* **UK Principle 9** — Embed continuous assurance
* **AU Foundation 4** — Testing
* **AU Foundation 5** — Continuous assurance

## Description

Continuous security assurance processes must be implemented to create confidence in the
effectiveness of security controls, both at the point of delivery and throughout the operational
life of the service. Assurance is not a one-off activity but a continual process enacted
throughout the product lifecycle.

Testing must cover both positive and negative use cases and target critical code, security
components, and threats identified in the product's threat model. Identified vulnerabilities must
be analyzed and addressed at the root cause, with analysis fed back into the development process
to prevent recurrence.

## Principle checklist

* Automated security testing (SAST, DAST, SCA) runs in the CI/CD pipeline.
* Security tests cover both positive (expected behavior) and negative (attack) scenarios.
* A vulnerability management process tracks discovery, triage, and remediation.
* Vulnerability disclosure and responsible reporting channels are established.
* Penetration testing is conducted periodically by qualified internal or external testers.
* Security control effectiveness is validated against the current threat model.
* Patches and security updates are applied within defined SLAs.
* Regression testing verifies that previously fixed vulnerabilities do not reappear.
* SBOM monitoring detects newly disclosed vulnerabilities in deployed components.

## Controls and mitigations

1. Integrate SAST, DAST, and SCA into the CI/CD pipeline with quality gates for critical findings.
2. Write security test cases for threats identified during threat modeling.
3. Implement a vulnerability management process with defined SLAs by severity.
4. Establish a vulnerability disclosure program with safe harbor for security researchers.
5. Conduct annual penetration testing; quarterly for high-risk services.
6. Maintain a continuous authority-to-operate model that re-validates controls as risk changes.
7. Monitor deployed SBOMs for newly disclosed component vulnerabilities.
8. Apply patches and security updates within SLA: critical (24h), high (7d), medium (30d).
9. Feed validated vulnerability findings back into developer training and coding standards.
10. Track Secure by Design progress through measurable security maturity metrics.

## Anti-patterns

* Security testing runs only before releases rather than continuously.
* Penetration test findings are logged but not remediated within defined timescales.
* No vulnerability disclosure program exists; security researchers have no safe reporting channel.
* Patching is deferred indefinitely due to compatibility concerns without compensating controls.
* Security testing covers only happy-path scenarios with no negative testing.
* Previously remediated vulnerabilities reappear due to absent regression tests.
* Assurance activities stop after initial deployment with no ongoing validation.

## OWASP cross-references

* A06:2025 Insecure Design — insufficient testing of security controls.
* A03:2025 Software Supply Chain Failures — unmonitored component vulnerabilities.
* A09:2025 Security Logging and Alerting Failures — gaps in assurance monitoring.
* A02:2025 Security Misconfiguration — configuration drift detected too late.

---

Content derived from works by the **UK Government Security Group** (Crown Copyright) licensed
under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
and the **Australian Signals Directorate / ACSC** (© Commonwealth of Australia) licensed under
[CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/).
Modifications: Synthesized into structured principle-checklist format with OWASP cross-references;
merged UK and AU guidance into unified principle areas.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
