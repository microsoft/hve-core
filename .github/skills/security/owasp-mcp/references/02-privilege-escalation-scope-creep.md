---
title: 'MCP02: Privilege Escalation via Scope Creep'
description: OWASP MCP Top 10 reference for privilege escalation vulnerabilities including scope creep and permission expansion patterns
---

# 02 Privilege Escalation via Scope Creep

Identifier: MCP02:2025
Category: Access Control

## Description

Scope creep occurs when temporary or narrowly scoped permissions granted to an MCP agent or tool
expand over time until the agent holds broad or administrative privileges.
MCP deployments frequently connect models to multiple systems (repositories, cloud APIs, ticketing,
CI/CD), and small cumulative scope increases transform low-risk automation into high-impact attack
surfaces.
Agents act autonomously, so an over-privileged agent can make unlabeled changes, trigger
deployments, or access sensitive data without human review.

## Impact

* Unauthorized modifications to code, IaC manifests, or production configuration.
* Unreviewed deployments and potential introduction of backdoors.
* Full environment control via service account impersonation or credential creation.
* Regulatory and compliance exposure due to uncontrolled data access.
* Amplified incident blast radius through automated, repeatable execution paths.

## Vulnerability checklist

* Permissions are modified manually without automated change logs.
* Service or agent accounts are shared across teams or sessions.
* No enforced expiration for scopes or tokens.
* Ad-hoc testing changes are promoted to production without approval gates.
* Limited visibility into which agent invoked which action.
* No automated entitlement or permission review process exists.

## Prevention controls

1. Define minimal permissions required per agent before deployment.
2. Use fine-grained scopes (e.g., repo:write:branch=feature/* not repo:write).
3. Encode permission policies as code (Rego, OPA, IAM policies) and enforce in CI/CD.
4. Issue time-limited scopes and tokens for sessions.
5. Require revalidation for long-running or recurring tasks.
6. Use JIT elevation workflows with approval gates for higher-risk actions.
7. Assign unique identities to agents and bind credentials to agent and session context.
8. Run periodic entitlement audits to find scope expansions.
9. Implement runtime policy enforcement (PDP/PIP) to block disallowed commands.
10. Separate authority to grant permissions from authority to deploy or change production.

## Example attack scenarios

### Scenario A — Accidental escalation to supply-chain compromise

A developer grants repo:write for a temporary test.
A malicious contributor creates a crafted PR that the over-privileged agent auto-merges.
The merged code introduces a dependency with a malicious payload and CI deploys it automatically.

### Scenario B — Credential harvesting and escalation

An attacker discovers an agent's long-lived token in logs.
Using that token they grant the agent additional scopes via an exposed internal API.
The agent then creates new service accounts and exfiltrates data.

### Scenario C — Automated policy bypass

An attacker gains temporary access to an internal tooling endpoint and updates an agent manifest to
include org:admin, enabling full takeover.

## Detection signals

* Permission modifications without corresponding change requests.
* Agents operating with scopes exceeding documented requirements.
* Token reuse across multiple sessions or environments.
* Sudden increases in privileged API calls from agent identities.

## Remediation

* Revoke excess permissions immediately.
* Enforce per-agent identity and credential binding.
* Implement automated drift detection for entitlements.
* Require multi-party approval for non-routine privilege grants.
* Track all permission changes with immutable, tamper-evident logs.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
