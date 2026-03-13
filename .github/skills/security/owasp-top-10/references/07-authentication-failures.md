# 07 Authentication Failures

Identifier: A07:2025
Category: Authentication

## Description

Authentication failures occur when an application allows attackers to trick it into recognizing
an invalid or incorrect user as legitimate.
Common weaknesses include permitting automated credential stuffing and brute force attacks,
allowing default or well-known passwords, using weak or ineffective credential recovery
mechanisms, storing passwords in plain text or with weak hashing, missing or ineffective
multi-factor authentication, exposing session identifiers in URLs, reusing session identifiers
after login, and failing to invalidate sessions on logout or after inactivity.
Hybrid password attacks that increment or adjust breached credentials represent an evolving form
of credential stuffing.

## Risk

* Complete account takeover through credential stuffing or brute force attacks.
* Mass compromise of user accounts when breached credential lists are not checked during
  registration or password changes.
* Session hijacking through exposed or non-invalidated session identifiers.
* Persistent unauthorized access when SSO sessions are not properly terminated across all
  federated applications.
* Authentication bypass through weak or ineffective fallback mechanisms when MFA is unavailable.
* Unauthorized access to administrative accounts through unchanged default credentials.

## Vulnerability checklist

* Automated attacks such as credential stuffing and brute force are not blocked or rate limited.
* Default, weak, or well-known passwords are permitted.
* New accounts can be created with known-breached credentials.
* Weak or ineffective credential recovery processes such as knowledge-based answers are used.
* Passwords are stored in plain text, encrypted reversibly, or with weak hash algorithms.
* Multi-factor authentication is missing or has weak fallback options.
* Session identifiers are exposed in URLs or insecure locations.
* Session identifiers are reused after successful login.
* Sessions and authentication tokens are not invalidated on logout or after inactivity.
* JWT scope and audience claims are not validated.

## Prevention controls

1. Implement and enforce multi-factor authentication on all critical systems to prevent
   credential stuffing, brute force, and stolen credential reuse.
2. Do not ship or deploy with default credentials, especially for administrator accounts.
3. Implement weak password checks against the top 10,000 worst passwords list.
4. Validate new and changed passwords against lists of known breached credentials.
5. Align password policies with NIST 800-63b section 5.1.1 guidelines for memorized secrets.
6. Do not force password rotation unless a breach is suspected; force immediate resets on
   suspected breach.
7. Harden registration, credential recovery, and API pathways against account enumeration by
   using identical response messages for all outcomes.
8. Limit and increasingly delay failed login attempts and alert administrators on detected
   attacks.
9. Use a server-side session manager that generates high-entropy random session IDs after login,
   stores them in secure cookies, and invalidates them on logout and after timeouts.
10. Validate JWT audience, issuer, and scope claims on all token-based authentication.
11. Use a well-trusted, hardened identity and session management system.

## Example attack scenarios

### Scenario A — Hybrid credential stuffing

An attacker uses breached username and password lists and applies common password adjustments
such as incrementing numbers or changing seasons.
The application does not implement defenses against automated threats.
The attacker gains unauthorized access to accounts whose users follow predictable password
patterns.

### Scenario B — Missing multi-factor authentication

An organization relies on passwords as the sole authentication factor.
Password rotation and complexity requirements encourage users to reuse weak passwords.
An attacker compromises accounts using credential dumps without encountering a second
authentication factor.

### Scenario C — Incomplete session termination

A user logs out of an SSO-protected application, but the single logout does not terminate
sessions in all federated applications.
An attacker who gains access to the browser accesses the still-authenticated applications and
takes over the victim's accounts.

## Detection guidance

* Test login endpoints for resistance to automated credential stuffing and brute force attacks.
* Verify that default credentials are not present on any deployed component.
* Inspect password storage implementations for use of strong adaptive hashing algorithms.
* Confirm that MFA is enforced on all administrative and high-privilege accounts.
* Check that session identifiers are regenerated after login and invalidated on logout.
* Monitor authentication logs for patterns indicating credential stuffing or brute force attacks.

## Remediation

* Enable MFA on all user-facing and administrative authentication flows.
* Remove all default credentials from deployed systems.
* Migrate password storage to strong adaptive hashing algorithms with appropriate work factors.
* Implement account lockout or progressive delay policies on failed login attempts.
* Regenerate session identifiers on login and ensure complete session invalidation on logout.
* Deploy monitoring and alerting for authentication anomalies and attack patterns.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
