---
title: 'SBD-02: Risk-Driven Approach'
description: Secure by Design reference for risk-driven security covering threat modeling, risk appetite, and dynamic risk management
---

# 02 Risk-Driven Approach

Identifier: SBD-02
Category: Risk Management

## Source mapping

* **UK Principle 3** — Adopt a risk-driven approach
* **AU Foundation 2** — Early and sustained security

## Description

A risk-driven approach establishes the project's risk appetite and maintains an assessment of
cyber security risks to build protections appropriate to the evolving threat landscape. Security
risks, threats, and mitigations must be considered throughout the lifecycle of a product, starting
from inception, design, and architecture phases.

Investing early in security practices avoids the significant cost of reworking inadequate security
or vulnerabilities discovered later. A whole-of-organisation culture ensures that security
requirements are reflected from the earliest stages, eliminating entire classes of vulnerabilities
before development begins.

## Principle checklist

* A documented risk appetite exists for the project or service.
* Threat modeling is performed and maintained for all significant components.
* A dynamic risk register tracks identified threats, likelihood, impact, and mitigations.
* Risk assessments are updated when the threat landscape or system architecture changes.
* Security requirements are captured during design and architecture phases.
* Security controls are proportionate to the identified risks.
* Regulatory and compliance obligations are identified and tracked.

## Controls and mitigations

1. Define and document the project's security risk appetite before development begins.
2. Perform threat modeling (STRIDE, PASTA, or equivalent) for each operational component.
3. Maintain a risk register with ownership, severity, and mitigation status per entry.
4. Conduct periodic threat landscape reviews to identify emerging risks.
5. Map security controls to identified risks and validate coverage.
6. Include security requirements in definition-of-done criteria for user stories.
7. Source threat assessments from relevant national or industry threat intelligence.

## Anti-patterns

* Security controls are implemented without understanding the threats they address.
* Risk assessments are performed once and never revisited.
* Threat modeling is skipped for "internal" or "low-risk" services.
* Security requirements are added only after a vulnerability is discovered.
* Risk appetite is undefined, leading to inconsistent security decisions.
* Compliance obligations are discovered during audit rather than planned proactively.

## OWASP cross-references

* A06:2025 Insecure Design — absent threat modeling leads to architectural vulnerabilities.
* A02:2025 Security Misconfiguration — unassessed risks result in default-insecure configurations.
* A01:2025 Broken Access Control — risk gaps allow unmodeled access paths.

---

Content derived from works by the **UK Government Security Group** (Crown Copyright) licensed
under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
and the **Australian Signals Directorate / ACSC** (© Commonwealth of Australia) licensed under
[CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/).
Modifications: Synthesized into structured principle-checklist format with OWASP cross-references;
merged UK and AU guidance into unified principle areas.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
