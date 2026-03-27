---
title: 'SBD-08: Minimize Attack Surface'
description: Secure by Design reference for attack surface minimization covering least privilege, component reduction, and unnecessary capability removal
---

# 08 Minimize Attack Surface

Identifier: SBD-08
Category: Attack Surface

## Source mapping

* **UK Principle 7** — Minimise the attack surface
* **AU Foundation 3** — Secure product development (surface reduction aspects)

## Description

Only the capabilities, software, data, and hardware components necessary for a service to achieve
its intended use should be deployed. Reducing the attack surface mitigates cyber security risks,
reduces opportunities for exploitation, and makes the service more cost-effective to operate and
maintain.

Every component, port, protocol, service, and user account that is not necessary for the
system's function represents potential exposure. Attack surface minimization applies at all layers:
network, infrastructure, application, and data.

## Principle checklist

* Only necessary services, ports, and protocols are enabled in production environments.
* Default accounts, sample data, and unnecessary features are removed before deployment.
* File metadata, backup files, and source control directories are not present in deployed artifacts.
* Least privilege is enforced for all user accounts, service accounts, and API keys.
* Network segmentation isolates components with different trust levels.
* Unused API endpoints are disabled or removed.
* Debug modes, diagnostic endpoints, and development tools are disabled in production.
* Administrative interfaces are restricted to authorized networks or require additional authentication.

## Controls and mitigations

1. Conduct regular attack surface reviews to identify and remove unnecessary components.
2. Enforce the principle of least privilege for all accounts and service identities.
3. Remove default accounts, sample applications, and documentation from production deployments.
4. Disable unnecessary ports, protocols, and services at the infrastructure level.
5. Segment networks to isolate components with different security requirements.
6. Strip file metadata, build artifacts, and source control directories from deployable packages.
7. Disable debug modes, verbose error output, and diagnostic endpoints in production.
8. Restrict administrative interfaces behind VPN, IP allowlisting, or additional MFA.
9. Regularly review and remove unused API endpoints, routes, and features.
10. Document the intended attack surface and validate it against the deployed state.

## Anti-patterns

* Default accounts or sample data ship with production deployments.
* Debug mode or verbose error output is enabled in production.
* Unused API endpoints remain active because "they might be needed later."
* Service accounts run with administrative privileges.
* Network segmentation is absent; all components share a flat network.
* Source maps, `.git` directories, or backup files are accessible from the web root.
* All ports are open by default; only explicitly blocked ports are closed.

## OWASP cross-references

* A02:2025 Security Misconfiguration — unnecessary features, default accounts, verbose errors.
* A01:2025 Broken Access Control — excessive privileges and missing least-privilege enforcement.
* A07:2025 Authentication Failures — default credentials and administrative interface exposure.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
