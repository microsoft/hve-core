---
title: 'A02: Security Misconfiguration'
description: OWASP Web Top 10 reference for security misconfiguration vulnerabilities in application and infrastructure settings
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - web
  - security-misconfiguration
  - security
estimated_reading_time: 5
---

# 02 Security Misconfiguration

Identifier: A02:2025
Category: Configuration Management

## Description

Security misconfiguration occurs when a system, application, or cloud service is set up incorrectly
from a security perspective, creating exploitable vulnerabilities.
This includes missing security hardening across the application stack, unnecessary features or
services left enabled, unchanged default credentials, overly informative error messages exposed to
users, disabled or improperly configured security features in upgraded systems, insecure settings
in application servers, frameworks, libraries, and databases, and missing or weak security headers.
With increasing adoption of highly configurable software and cloud services, misconfiguration has
become one of the most prevalent web application security risks.

## Risk

* Full application or server compromise through unprotected administrative interfaces with
  default credentials.
* Information disclosure through detailed error messages, stack traces, or directory listings
  exposed to users.
* Unauthorized access through unnecessary ports, services, accounts, or privileges left enabled.
* Data exposure through misconfigured cloud storage permissions.
* Weakened defense-in-depth when security features are disabled for backward compatibility.
* Exploitation of known vulnerabilities in components running insecure default configurations.

## Vulnerability checklist

* Security hardening is missing or improperly configured across any part of the application stack.
* Unnecessary features, ports, services, pages, accounts, or privileges are enabled or installed.
* Default accounts and their passwords are still enabled and unchanged.
* Error handling reveals stack traces or overly informative error messages to users.
* Security features in upgraded systems are disabled or not configured securely.
* Security settings in application servers, frameworks, libraries, and databases are not set to
  secure values.
* The server does not send security headers or directives, or they are not set to secure values.
* Cloud storage permissions are overly permissive.
* Static keys or secrets are embedded in code, configuration files, or pipelines.

## Prevention controls

1. Implement a repeatable hardening process that enables fast and consistent deployment of
   locked-down environments across development, QA, and production.
2. Deploy a minimal platform without unnecessary features, components, documentation, or samples.
3. Review and update configurations as part of the patch management process, including cloud
   storage permissions.
4. Implement a segmented application architecture with effective separation between components or
   tenants using containerization or cloud security groups.
5. Send security directives to clients through security headers.
6. Automate verification of configuration effectiveness across all environments.
7. Implement central configuration to intercept excessive error messages.
8. Use identity federation, short-lived credentials, or role-based access mechanisms instead of
   embedding static keys or secrets.

## Example attack scenarios

### Scenario A — Unremoved sample applications

An application server ships with sample applications that are not removed from the production
server.
The sample applications have known security flaws that an attacker exploits to compromise the
server.
The admin console retains default credentials, and the attacker logs in and takes over.

### Scenario B — Directory listing exposure

Directory listing is not disabled on the server.
An attacker discovers the listing, downloads compiled Java class files, decompiles them, and
finds a severe access control flaw in the application source code.

### Scenario C — Detailed error messages

The application server returns detailed error messages including stack traces to users.
The error output exposes component versions known to be vulnerable and internal system
information that the attacker uses to craft targeted exploits.

### Scenario D — Permissive cloud storage

A cloud service provider defaults to sharing permissions open to the internet.
Sensitive data stored in cloud storage is accessible to anyone without authentication.

## Detection guidance

* Run automated configuration scanners against all environments to detect deviations from
  hardened baselines.
* Check for the presence of default accounts and credentials on all application components.
* Verify that error messages returned to users do not contain stack traces or internal system
  details.
* Inspect HTTP response headers for missing or misconfigured security directives.
* Review cloud storage permissions for public or overly permissive access policies.
* Audit application servers, frameworks, and libraries for insecure default settings.

## Remediation

* Remove all unnecessary features, components, sample applications, documentation, and default
  accounts from production environments.
* Apply hardened configuration baselines to all application servers, frameworks, and libraries.
* Configure error handling to return generic messages to users and log detailed errors internally.
* Enable and properly configure all security headers and directives.
* Restrict cloud storage permissions to authorized principals only.
* Automate configuration verification and schedule recurring audits to detect drift.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
