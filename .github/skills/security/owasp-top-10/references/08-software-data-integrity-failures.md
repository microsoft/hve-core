---
title: 'A08: Software or Data Integrity Failures'
description: OWASP Web Top 10 reference for software and data integrity failures including insecure deserialization and CI/CD pipeline compromise
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - web
  - data-integrity
  - deserialization
  - security
estimated_reading_time: 5
---

# 08 Software or Data Integrity Failures

Identifier: A08:2025
Category: Data Integrity

## Description

Software or data integrity failures occur when code and infrastructure do not protect against
invalid or untrusted code or data being treated as trusted and valid.
This includes applications that rely on plugins, libraries, or modules from untrusted sources,
repositories, or content delivery networks without verifying integrity.
Insecure CI/CD pipelines that do not consume and provide software integrity checks introduce
potential for unauthorized access, malicious code, or system compromise.
Auto-update functionality that downloads and applies updates without sufficient integrity
verification is another common vector.
Insecure deserialization, where objects or data encoded into a structure that an attacker can see
and modify, allows tampering with application state or achieving remote code execution.

## Risk

* Remote code execution through insecure deserialization of untrusted data.
* System compromise through unsigned or unverified software updates applied automatically.
* Session hijacking through inclusion of functionality from untrusted control spheres such as
  third-party domains sharing the application cookie scope.
* Supply chain compromise through code or artifacts pulled from untrusted sources without
  integrity verification.
* Data tampering when serialized data is exchanged with untrusted clients without integrity
  checks.
* Malicious code introduction through packages downloaded from unofficial sources without
  signature verification.

## Vulnerability checklist

* The application relies on plugins, libraries, or modules from untrusted sources without
  verifying integrity.
* The CI/CD pipeline does not verify the integrity of code or artifacts before use.
* Auto-update functionality downloads and applies updates without sufficient integrity
  verification.
* Unsigned or unencrypted serialized data is received from untrusted clients without integrity
  checks.
* Code or configuration changes are not subject to a review process to prevent malicious
  introduction.
* The application includes functionality loaded from untrusted third-party domains.
* Digital signatures or checksums are not used to verify software or data authenticity.
* The CI/CD pipeline lacks proper segregation, access control, and configuration hardening.

## Prevention controls

1. Use digital signatures or similar mechanisms to verify that software or data is from the
   expected source and has not been altered.
2. Consume libraries and dependencies only from trusted repositories and consider hosting an
   internal vetted repository for higher-risk profiles.
3. Ensure a review process exists for code and configuration changes to minimize introduction
   of malicious code.
4. Ensure the CI/CD pipeline has proper segregation, configuration, and access control to
   maintain code integrity through build and deploy processes.
5. Do not receive unsigned or unencrypted serialized data from untrusted clients without
   integrity checks or digital signatures to detect tampering or replay.
6. Verify the integrity of all externally sourced packages and updates through signature
   validation before use.

## Example attack scenarios

### Scenario A — Third-party domain cookie theft

A company maps a third-party support provider to a subdomain of its main domain.
Authentication cookies set on the main domain are sent to the third-party provider.
Anyone with access to the provider's infrastructure can steal user cookies and perform session
hijacking.

### Scenario B — Unsigned firmware updates

A device downloads firmware updates without verifying digital signatures.
An attacker intercepts the update process and distributes a modified firmware image containing a
backdoor.
There is no mechanism to remediate other than waiting for a signed update to replace the
compromised version.

### Scenario C — Insecure deserialization

An application serializes user state and passes it with each request.
An attacker recognizes the serialized Java object signature, uses a deserialization scanner to
identify a vulnerable gadget chain, and gains remote code execution on the application server.

## Detection guidance

* Verify that digital signatures are required and validated for all externally sourced packages,
  libraries, and updates.
* Inspect CI/CD pipeline configurations for integrity verification steps on all consumed
  artifacts.
* Audit auto-update mechanisms for signature validation before application of updates.
* Review application code for deserialization of data from untrusted sources.
* Check that code and configuration changes require review before merge and deployment.
* Monitor for inclusion of resources from untrusted third-party domains.

## Remediation

* Implement digital signature verification for all externally sourced software and data.
* Add integrity checks to all CI/CD pipeline stages for consumed and produced artifacts.
* Replace insecure deserialization with safer data exchange formats or add integrity validation
  to serialized data.
* Restrict auto-update functionality to accept only signed updates from trusted sources.
* Enforce mandatory code review for all changes before deployment.
* Remove or replace functionality loaded from untrusted third-party domains.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
