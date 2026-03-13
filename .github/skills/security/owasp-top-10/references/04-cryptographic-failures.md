---
title: 'A04: Cryptographic Failures'
description: OWASP Web Top 10 reference for cryptographic failures including weak algorithms, improper key management, and data exposure
---

# 04 Cryptographic Failures

Identifier: A04:2025
Category: Cryptography

## Description

Cryptographic failures encompass the lack of cryptography, use of insufficiently strong
cryptographic algorithms, leaking of cryptographic keys, and related implementation errors.
All data in transit should be encrypted at the transport layer, and sensitive data at rest
requires encryption appropriate to its classification.
Sensitive data such as passwords, credit card numbers, health records, personal information, and
business secrets require additional protection, especially when subject to privacy laws such as
GDPR or regulations such as PCI DSS.
Common weaknesses include use of old or weak algorithms, default or reused crypto keys, missing
enforcement of encryption via security headers, improper certificate validation, use of insecure
modes of operation, and reliance on deprecated hash functions.

## Risk

* Exposure of sensitive data in transit through downgrade attacks or missing TLS enforcement.
* Mass credential compromise when password databases use unsalted or weak hashing algorithms.
* Cryptographic key leakage through source code repositories or insecure key management.
* Data exposure through cleartext storage of sensitive information at rest.
* Algorithm downgrade or bypass attacks that weaken or eliminate cryptographic protections.
* Side-channel attacks exploiting cryptographic error messages such as padding oracle attacks.
* Future exposure of currently encrypted data when post-quantum cryptography migration is delayed.

## Vulnerability checklist

* Old or weak cryptographic algorithms or protocols are used by default or in legacy code.
* Default crypto keys are in use, weak keys are generated, or proper key rotation is missing.
* Crypto keys are checked into source code repositories.
* Encryption is not enforced through HTTP security headers or directives.
* Server certificate and trust chain validation is missing or incomplete.
* Initialization vectors are ignored, reused, or insufficiently random for the cryptographic mode.
* Insecure modes of operation such as ECB are used, or encryption is used where authenticated
  encryption is required.
* Passwords are used as cryptographic keys without a password-based key derivation function.
* Randomness sources are not cryptographically secure or are seeded with insufficient entropy.
* Deprecated hash functions such as MD5 or SHA1 are used for cryptographic purposes.

## Prevention controls

1. Classify data processed, stored, and transmitted by the application and identify which data is
   sensitive according to privacy laws, regulatory requirements, or business needs.
2. Store the most sensitive keys in hardware or cloud-based HSMs.
3. Use well-trusted implementations of cryptographic algorithms.
4. Discard sensitive data as soon as possible or use PCI DSS compliant tokenization or
   truncation.
5. Encrypt all sensitive data at rest using strong algorithms and proper key management.
6. Encrypt all data in transit with TLS 1.2 or higher with forward secrecy ciphers and enforce
   encryption using HSTS.
7. Disable caching for responses that contain sensitive data.
8. Store passwords using strong adaptive and salted hashing functions such as Argon2, scrypt, or
   PBKDF2-HMAC-SHA-512 with appropriate work factors.
9. Generate initialization vectors appropriate for the mode of operation using a CSPRNG and never
   reuse an IV for a fixed key.
10. Use authenticated encryption instead of encryption alone.
11. Generate keys cryptographically randomly and avoid using deprecated cryptographic functions,
    block modes, and padding schemes.
12. Prepare for post-quantum cryptography migration so that high-risk systems are protected by
    the end of 2030.

## Example attack scenarios

### Scenario A — Missing TLS enforcement

A site does not enforce TLS for all pages or supports weak encryption.
An attacker monitoring network traffic at an insecure wireless network downgrades connections from
HTTPS to HTTP, intercepts requests, and steals the user's session cookie.
The attacker replays the cookie and hijacks the authenticated session.

### Scenario B — Weak password hashing

A password database uses unsalted or simple hashes to store passwords.
An attacker retrieves the password database through a file upload vulnerability.
All unsalted hashes are exposed with a rainbow table of pre-calculated hashes, and weakly salted
hashes are cracked by GPU.

## Detection guidance

* Scan all endpoints for TLS configuration strength and protocol version support.
* Verify that HSTS headers are present and correctly configured on all responses.
* Audit password storage implementations for use of appropriate adaptive hashing algorithms.
* Search source code repositories for committed cryptographic keys or secrets.
* Review cryptographic algorithm and mode selections in application code for deprecated or
  weak choices.
* Test for padding oracle and other side-channel vulnerabilities in cryptographic operations.

## Remediation

* Upgrade all TLS configurations to version 1.2 or higher with forward secrecy ciphers.
* Enable HSTS on all domains and subdomains.
* Rotate all cryptographic keys that may have been exposed and remove keys from source
  repositories.
* Re-hash all passwords using strong adaptive algorithms with appropriate work factors.
* Replace all deprecated cryptographic algorithms and insecure modes of operation.
* Deploy automated scanning for cryptographic configuration weaknesses across all environments.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
