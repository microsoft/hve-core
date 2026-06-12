---
title: 'ISR07: Insecure Authentication Methods and Default Credentials'
description: OWASP Infrastructure Top 10 reference for authentication vulnerabilities including default credentials and missing multi-factor authentication
---

# 07 Insecure Authentication Methods and Default Credentials

Identifier: ISR07:2024
Category: Credential Hygiene

## Description

Passwords remain a fundamental part of cybersecurity, and many Identity and Access Management
(IAM) systems rely on username and password authentication.
Insecure authentication methods refer to passwords that are easy to guess or crack due to
simplicity, predictability, or insufficient length.
Default credentials preconfigured on hardware devices or software applications by manufacturers
or vendors are often left unchanged by users or administrators, creating a security vulnerability.

## Risk

* Credentials are crucial to restrict access to internal resources to authenticated and
  authorized users only.
* Weak passwords can be exploited through brute-force and dictionary attacks.
* Default credentials can be found in product documentation and exploited by attackers.
* Exploitation of unchanged default settings or stolen passwords can lead to unauthorized access,
  data breaches, and compromise of critical systems.

## Vulnerability checklist

* Default credentials on hardware devices or software applications remain unchanged.
* Password complexity requirements are not enforced.
* Multi-factor authentication (MFA) is not implemented.
* Account lockout policies are absent after multiple failed login attempts.
* Password management tools are not available to employees.

## Prevention controls

1. Enforce password complexity requirements across all systems and accounts.
2. Implement multi-factor authentication (MFA) for all user and administrative access.
3. Change default credentials on all hardware devices and software applications upon installation.
4. Educate employees about the importance of strong, unique passwords.
5. Provide password management tools to help employees manage credentials securely.
6. Implement account lockout after multiple failed login attempts.
7. Restrict access to devices with changed credentials to authorized personnel only.

## Example attack scenarios

### Scenario A — Default printer credentials

Many networked printers are shipped with default usernames and passwords that are widely known.
An attacker exploits this by accessing the printer and viewing printing jobs containing sensitive
information.
Organizations must change default printer credentials upon installation and restrict access to
authorized personnel.

### Scenario B — Weak user passwords

Weak or easily guessable passwords for user accounts are a primary target for attackers.
A malicious employee gains unauthorized access to sensitive information or systems by exploiting
weak user passwords.
Organizations should enforce password policies, implement account lockouts after multiple failed
login attempts, and promote password best practices among users.

## Detection guidance

* Scan for devices and applications still using manufacturer default credentials.
* Audit password policy enforcement across all IAM systems.
* Monitor for brute-force and dictionary attack patterns in authentication logs.
* Check MFA enrollment rates and identify accounts without MFA enabled.

## Remediation

* Change all default credentials immediately on every hardware device and software application.
* Enforce password complexity and length requirements through technical controls.
* Deploy MFA across all user and administrative accounts.
* Implement account lockout and alerting for repeated failed authentication attempts.
* Provide organization-wide password management tooling and security awareness training.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
