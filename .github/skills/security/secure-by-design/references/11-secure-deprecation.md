---
title: 'SBD-11: Secure Deprecation'
description: Secure by Design reference for secure deprecation covering end-of-life management, data destruction, credential cleanup, and legacy system retirement
---

# 11 Secure Deprecation

Identifier: SBD-11
Category: Deprecation

## Source mapping

* **UK Principle 7** — Minimise the attack surface (retire service components securely)
* **AU Foundation 6** — Secure deprecation

## Description

Security does not end when a product or feature is decommissioned, is no longer required, or
becomes legacy. Both technology manufacturers and technology consumers must consider how they will
manage products through the end-of-life stage of the lifecycle.

Exploitation of deprecated or legacy systems is common and can be used to perform lateral movement,
data exfiltration, or credential compromise that affects other active systems. All data controlled
by a deprecated product must be securely archived or destroyed; accounts and access must be removed
or updated; and deprecated software must be removed completely to prevent living-off-the-land
attacks.

## Principle checklist

* A documented deprecation plan exists for each service or component approaching end-of-life.
* Data retention and destruction policies are applied during deprecation.
* Service accounts, API keys, and credentials associated with deprecated components are revoked.
* Deprecated software is fully removed from environments to prevent living-off-the-land attacks.
* Users and consumers are notified of deprecation timelines and migration paths.
* Regulatory and legislative data retention requirements are met before data destruction.
* Network access to deprecated components is removed from firewalls and security groups.
* Feature removal follows the same security review process as feature addition.

## Controls and mitigations

1. Create a deprecation plan for every component at the design phase, not only when retirement
   begins.
2. Securely archive data that must be retained; securely destroy data that must not be kept.
3. Revoke all credentials, API keys, certificates, and service accounts tied to the deprecated
   component.
4. Remove or uninstall deprecated software completely from all environments.
5. Update network rules to remove access paths to decommissioned services.
6. Communicate deprecation timelines, migration guidance, and data handling details to consumers.
7. Verify compliance with right-to-be-forgotten and data retention regulations before proceeding.
8. Conduct a final access review to confirm no active accounts retain permissions to retired
   resources.
9. For SaaS or managed services, provide transparency to consumers about data deletion or
   retention post-deprecation.

## Anti-patterns

* Deprecated services remain running "just in case" with no maintenance or patching.
* Credentials for decommissioned systems are not revoked and remain valid.
* Data from retired services is left in place without classification or retention review.
* Network rules for deprecated services are not cleaned up, leaving attack paths open.
* Deprecation is treated as simply "turning off" without data, credential, or access cleanup.
* Legacy systems are exempted from security patching with no compensating controls.
* No communication is provided to consumers about how their data is handled post-deprecation.

## OWASP cross-references

* A02:2025 Security Misconfiguration — stale configurations and unused components.
* A07:2025 Authentication Failures — unrevoled credentials for deprecated services.
* A01:2025 Broken Access Control — residual access paths to retired components.
* A08:2025 Software or Data Integrity Failures — unmanaged data from deprecated systems.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
