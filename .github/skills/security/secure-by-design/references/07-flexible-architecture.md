---
title: 'SBD-07: Flexible Architecture'
description: Secure by Design reference for flexible architecture covering modular design, security upgradability, and component isolation
---

# 07 Flexible Architecture

Identifier: SBD-07
Category: Architecture

## Source mapping

* **UK Principle 6** — Design flexible architectures

## Description

Digital services must be implemented with architectures that allow for easier integration of new
security controls in response to changes in business requirements, cyber threats, and
vulnerabilities. Legacy components must be updatable without compromising security.

Flexible architectures enable faster response to evolving cyber threats by allowing security
controls to be added, modified, or replaced without redesigning the entire system. This requires
modular design, well-defined interfaces, and loose coupling between components.

## Principle checklist

* Architecture supports adding or replacing security controls without full redesign.
* Components are loosely coupled with well-defined interfaces and security boundaries.
* Security-critical components can be updated independently of the broader system.
* Cryptographic algorithms and protocols can be swapped without architectural changes.
* Infrastructure components support rolling updates and blue-green deployments.
* Service boundaries align with trust zones and data classification levels.
* Configuration is externalized to support environment-specific security settings.

## Controls and mitigations

1. Design modular architectures with clear component boundaries and defined interfaces.
2. Abstract cryptographic operations behind interfaces to enable algorithm rotation.
3. Implement infrastructure patterns that support zero-downtime security updates.
4. Define trust zones and enforce security controls at zone boundaries.
5. Externalize security configuration (TLS versions, cipher suites, auth providers) from code.
6. Design APIs with versioning to support backward-compatible security enhancements.
7. Document architectural decision records for security-relevant design choices.
8. Plan for cryptographic agility, including post-quantum readiness where applicable.

## Anti-patterns

* Security controls are hardcoded into application logic rather than externalized.
* Cryptographic algorithms are embedded throughout the codebase without abstraction.
* Monolithic architectures prevent independent security updates to components.
* Trust boundaries are not defined, allowing lateral movement between components.
* Security changes require full system redeployment.
* Legacy components cannot be updated and are left with known vulnerabilities.

## OWASP cross-references

* A06:2025 Insecure Design — inflexible architectures that cannot adapt to threats.
* A04:2025 Cryptographic Failures — inability to rotate algorithms or keys.
* A02:2025 Security Misconfiguration — hardcoded configurations preventing security updates.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
