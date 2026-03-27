---
title: 'SBD-05: Usable Security Controls'
description: Secure by Design reference for usable security controls covering secure defaults, user friction minimization, and security UX design
---

# 05 Usable Security Controls

Identifier: SBD-05
Category: Usability

## Source mapping

* **UK Principle 4** — Design usable security controls
* **AU Foundation 3** — Secure product development (Secure by Default)

## Description

Security controls must be designed to minimize friction for users while maintaining strong
protection. Regular user research must inform service design so security processes are fit for
purpose and easy to understand. Insecure practices are avoided by removing incentives for users to
find workarounds.

Products must be Secure by Default—secure to use out of the box with little to no additional
configuration required. All built-in security measures such as multi-factor authentication,
auditing, and event logging must be included in the base product at no additional cost. Users must
be made aware of the risks that may be realized if settings deviate from secure defaults.

## Principle checklist

* The most secure configuration is the default configuration.
* Security features (MFA, audit logging, encryption) are included in the base product.
* Security controls do not require specialist knowledge to use correctly.
* Users are warned when deviating from secure defaults with clear risk explanations.
* Security UX is validated through user research or usability testing.
* Configuration options that weaken security are clearly labeled with risk context.
* Strong authentication methods are enabled by default.
* Session management uses secure defaults (timeouts, token rotation, secure cookies).

## Controls and mitigations

1. Ship with the most restrictive secure configuration as the default.
2. Include MFA, audit logging, and encryption as standard features without premium tiers.
3. Provide clear, actionable guidance when users change settings that reduce security posture.
4. Design authentication flows that guide users toward the strongest available method.
5. Implement secure session defaults: HTTPS-only cookies, appropriate timeouts, sameSite flags.
6. Use progressive disclosure for security settings—simple defaults, advanced options available.
7. Conduct usability testing specifically for security-sensitive workflows.
8. Display security status indicators so users understand their current protection level.

## Anti-patterns

* Security features require paid upgrades or separate licenses.
* Default configurations are insecure and require manual hardening.
* Security warnings use technical jargon that users cannot act on.
* Users must navigate complex settings to enable basic protections like MFA or HTTPS.
* Security controls are so burdensome that users circumvent them.
* Session tokens never expire or use overly permissive cookie settings.
* No feedback is provided when users adopt insecure configurations.

## OWASP cross-references

* A07:2025 Authentication Failures — weak default authentication configurations.
* A02:2025 Security Misconfiguration — insecure defaults requiring manual hardening.
* A01:2025 Broken Access Control — permissive default access policies.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
