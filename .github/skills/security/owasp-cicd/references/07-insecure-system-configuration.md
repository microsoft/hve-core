---
title: 'CICD-SEC-7: Insecure System Configuration'
description: OWASP CI/CD Top 10 reference for insecure system configuration vulnerabilities including unpatched CI/CD infrastructure and debug exposure
---

# 07 Insecure System Configuration

Identifier: CICD-SEC-7:2025
Category: Configuration Management

## Description

Insecure system configuration risks stem from flaws in the security settings, configuration, and
hardening of the different systems across the pipeline (SCM, CI, artifact repository), often
resulting in low-effort attack vectors for adversaries looking to expand their foothold in the
environment.

CI/CD environments are comprised of multiple systems provided by a variety of vendors. These
systems involve various security settings and configurations at the application, network, and
infrastructure levels that have a major influence on security posture and susceptibility to
compromise.

Examples of potential hardening flaws include self-managed systems running outdated versions or
lacking security patches, systems with overly permissive network access controls, self-hosted
systems that have administrative permissions on the underlying OS, systems with insecure default
configurations around authorization, access controls, and logging, and systems with inadequate
credential hygiene such as default credentials that are not disabled.

While SaaS CI/CD solutions eliminate some risks associated with system hardening and lateral
movement, organizations remain responsible for securely configuring their SaaS solutions, each
of which has unique security configurations and best practices.

## Risk

* Security flaws in CI/CD systems may be leveraged to obtain unauthorized access or compromise
  the system and access the underlying OS.
* Flaws may be abused to manipulate legitimate CI/CD flows, obtain sensitive tokens, and
  potentially access production environments.
* Lateral movement within the environment and outside the context of CI/CD systems becomes
  possible through compromised nodes.
* Self-managed systems left accessible from the internet with default credentials expose source
  code and secrets.
* Debug permissions on execution nodes may allow engineers to access all secrets loaded into
  memory and use the node's identity.

## Vulnerability checklist

* Self-managed CI/CD systems run outdated versions or lack security patches.
* CI/CD systems have overly permissive network access controls, including internet-facing
  instances without access restrictions.
* Self-hosted systems have administrative permissions on the underlying OS.
* Default system configurations have not been reviewed and hardened for security.
* Default credentials exist that are not disabled or changed.
* Overly permissive programmatic tokens are in use.
* Engineers have debug permissions on execution nodes, granting access to secrets in memory.
* No inventory exists of CI/CD systems, versions, and designated owners.
* No periodic review process exists for system security configurations.

## Prevention controls

1. Maintain an inventory of all CI/CD systems and versions in use, with a designated owner for
   each system.
2. Continuously check for known vulnerabilities and apply security patches when available. If a
   patch is not available, consider removing the component or restricting access.
3. Ensure network access to CI/CD systems is aligned with the principle of least access.
4. Establish a process to periodically review all system configurations that affect security
   posture, ensuring all settings are optimal.
5. Ensure permissions to pipeline execution nodes follow the principle of least privilege.
6. Restrict debug permissions on execution nodes, recognizing that users with debug access can
   expose secrets loaded in memory and use the node's identity.
7. Disable default credentials and replace them with properly managed credentials.
8. Ensure all SaaS CI/CD solution configurations are reviewed against vendor-specific security
   best practices.

## Example attack scenarios

### Scenario A — Internet-exposed SCM with default credentials

A self-managed Bitbucket instance is left accessible from the internet with default credentials
enabled. An attacker discovers the instance through an internet scan, logs in with default
credentials, and gains access to all hosted source code repositories including those containing
secrets and production deployment configurations.

### Scenario B — Unpatched build server compromise

A self-managed Jenkins instance runs an outdated version with a known remote code execution
vulnerability. The system is accessible from the internet. An attacker exploits the vulnerability
to gain shell access on the Jenkins server, accesses stored pipeline credentials, and uses them
to deploy malicious code to production through legitimate deployment pipelines.

## Detection guidance

* Scan all CI/CD system instances for known vulnerabilities and outdated versions.
* Audit network access controls to identify internet-facing or overly permissive CI/CD systems.
* Check for the presence of default credentials across all CI/CD systems.
* Review system configurations against hardening baselines and vendor security best practices.
* Monitor for debug sessions on pipeline execution nodes.
* Enumerate and audit all programmatic tokens for excessive permissions.

## Remediation

* Patch or upgrade all CI/CD systems to current, supported versions.
* Restrict network access to CI/CD systems, removing internet exposure where not required and
  implementing IP allowlisting.
* Disable all default credentials and replace with properly managed alternatives.
* Conduct a comprehensive security configuration review of all CI/CD systems against hardening
  baselines.
* Remove administrative OS permissions from self-hosted CI/CD systems.
* Restrict debug permissions on execution nodes to only those who require them, with appropriate
  monitoring.
* Establish a vulnerability management cadence for all CI/CD infrastructure components.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
