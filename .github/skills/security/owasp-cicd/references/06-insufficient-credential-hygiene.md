---
title: 'CICD-SEC-6: Insufficient Credential Hygiene'
description: OWASP CI/CD Top 10 reference for credential hygiene vulnerabilities including hardcoded secrets and unrotated credentials in pipelines
---

# 06 Insufficient Credential Hygiene

Identifier: CICD-SEC-6:2025
Category: Credential Management

## Description

Insufficient credential hygiene risks deal with an attacker's ability to obtain and use various
secrets and tokens spread throughout the pipeline due to flaws having to do with access controls
around credentials, insecure secret management, and overly permissive credentials.

CI/CD environments are built of multiple systems communicating and authenticating against each
other, creating challenges around protecting credentials due to the large variety of contexts in
which credentials can exist. Application credentials are used at runtime, credentials to production
systems are used by pipelines to deploy infrastructure, and engineers use credentials in testing
environments and within their code and artifacts.

Major flaws affecting credential hygiene include credentials committed to SCM repositories (remaining
visible in commit history even after deletion), credentials used insecurely inside build and
deployment processes, credentials left in container image layers, credentials printed to console
output and log management systems, and unrotated credentials that accumulate exposure over time.

## Risk

* Credentials are the most sought-after object by adversaries seeking access to high-value
  resources or to deploy malicious code and artifacts.
* Engineering environments provide attackers with multiple avenues to obtain credentials.
* Credentials committed to code repositories persist in commit history indefinitely.
* Secrets printed to build console output are exposed to anyone with access to build results and
  may flow to centralized log management systems.
* Credentials embedded in container image layers are accessible to anyone who can download the
  image.
* Unrotated credentials allow a constantly growing number of people and artifacts to hold valid
  credentials.
* Shared credentials increase exposure footprint and reduce accountability.

## Vulnerability checklist

* Credentials are present in code committed to SCM repository branches, including in commit
  history.
* Secrets are used in CI/CD builds without scoping to specific pipelines and steps.
* Pipeline credentials can be accessed by unreviewed code flowing through the pipeline.
* Credentials are injected into the build in a manner that makes them accessible outside runtime.
* Secrets exist in container image layers.
* Credentials are printed to pipeline console output in cleartext.
* Static credentials exist that have not been rotated within the defined rotation period.
* The same set of credentials is shared across multiple contexts.
* Credentials lack usage conditions such as source IP restrictions or identity binding.
* No automated scanning exists for secrets in code repositories.

## Prevention controls

1. Establish procedures to continuously map credentials across the engineering ecosystem and
   ensure each set follows the principle of least privilege.
2. Avoid sharing the same credentials across multiple contexts.
3. Prefer temporary credentials over static credentials. For static credentials, establish
   periodic rotation procedures and detect stale credentials.
4. Configure credential usage conditions such as scoping to specific source IPs or identities.
5. Detect secrets pushed to code repositories using IDE plugins, push-time scanning, and
   periodic repository scans covering past commits.
6. Scope secrets in CI/CD systems so each pipeline and step accesses only the secrets it
   requires.
7. Use built-in vendor options or third-party tools to prevent secrets from being printed to
   pipeline console outputs and audit existing outputs for secret exposure.
8. Verify that secrets are removed from all artifact types including container image layers,
   binaries, and Helm charts.

## Example attack scenarios

### Scenario A — Credentials in commit history

A developer accidentally commits AWS access keys to a repository. The keys are removed in a
subsequent commit, but remain visible in the commit history. An attacker with read access to the
repository browses the commit history, extracts the keys, and uses them to access the organization's
cloud infrastructure and exfiltrate data from production S3 buckets.

### Scenario B — Secrets exposed in build logs

A CI pipeline prints environment variables to the console output during a debugging step that was
never removed. The build logs, including plaintext credentials for the production database, flow
to the centralized log management system. An attacker who gains access to the logging platform
discovers the credentials and uses them to access the production database.

## Detection guidance

* Scan all repositories for secrets in current branches and historical commits using automated
  secret detection tools.
* Audit CI/CD pipeline configurations for secrets injected as environment variables and assess
  their scope.
* Review pipeline console outputs for exposed credentials.
* Inspect container images layer by layer to detect embedded secrets.
* Monitor credential usage patterns and alert on access from unexpected sources or contexts.
* Track credential rotation dates and alert on credentials that exceed the defined rotation
  period.

## Remediation

* Rotate all credentials known or suspected to have been exposed.
* Remove secrets from repository commit history using history-rewriting tools and invalidate the
  exposed credentials.
* Implement automated secret scanning in pre-commit hooks, CI pipelines, and periodic repository
  scans.
* Re-scope all pipeline secrets to the minimum set of pipelines and steps that require them.
* Mask or redact all secrets in pipeline console outputs.
* Rebuild container images to eliminate secrets from intermediate layers using multi-stage builds.
* Establish and enforce a credential rotation policy with automated tracking and alerting.
* Replace shared credentials with dedicated, individually-scoped credentials.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
