---
title: 'SBD-09: Defense in Depth'
description: Secure by Design reference for defense in depth covering layered controls, blast radius containment, and redundant security mechanisms
---

# 09 Defense in Depth

Identifier: SBD-09
Category: Layered Defense

## Source mapping

* **UK Principle 8** — Defend in depth
* **AU Foundation 2** — Early and sustained security (defence in depth aspects)

## Description

Layered controls must be created across a service so it is harder for attackers to fully
compromise the system if a single control fails or is overcome. Defense in depth increases the
time, effort, and cost required for an attacker to compromise a service and keeps the impact of
vulnerabilities more contained.

No single security control is infallible. Multiple overlapping controls at different layers—
network, infrastructure, application, and data—ensure that a failure at one layer does not result
in complete compromise.

## Principle checklist

* Multiple independent security controls protect critical assets and data flows.
* A failure or bypass of any single control does not grant full system access.
* Security controls operate at multiple layers: network, infrastructure, application, and data.
* Blast radius containment limits the impact of a compromised component.
* Trust boundaries are enforced between components at different privilege levels.
* Input is validated at every trust boundary, not only at the external perimeter.
* Authentication and authorization are enforced independently at each service layer.

## Controls and mitigations

1. Implement security controls at each architectural layer: network, host, application, and data.
2. Apply input validation at every trust boundary, not only at the edge.
3. Enforce authentication and authorization at each service independently, not via a shared gateway
   alone.
4. Segment networks and use microsegmentation to limit lateral movement.
5. Implement rate limiting and throttling at multiple layers to contain abuse.
6. Apply the principle of least privilege at every layer—network rules, OS permissions, and
   application roles.
7. Use encryption at multiple layers: transport (TLS), storage (disk/volume), and application
   (field-level).
8. Deploy redundant monitoring and detection at different layers to prevent single-point detection
   failure.

## Anti-patterns

* A WAF or API gateway is the only security control; applications assume all input is trusted.
* Authorization is checked only at the frontend or API gateway, not at the service layer.
* All components share the same privilege level or service account.
* A single compromised credential grants access to the entire system.
* Input validation occurs only at the perimeter; internal services accept unvalidated data.
* Monitoring exists at only one layer, allowing attackers to operate undetected at other layers.

## OWASP cross-references

* A05:2025 Injection — lack of layered input validation.
* A01:2025 Broken Access Control — single-layer authorization enforcement.
* A02:2025 Security Misconfiguration — flat network architectures without segmentation.
* A04:2025 Cryptographic Failures — encryption applied at only one layer.

---

Content derived from works by the **UK Government Security Group** (Crown Copyright) licensed
under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
and the **Australian Signals Directorate / ACSC** (© Commonwealth of Australia) licensed under
[CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/).
Modifications: Synthesized into structured principle-checklist format with OWASP cross-references;
merged UK and AU guidance into unified principle areas.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
