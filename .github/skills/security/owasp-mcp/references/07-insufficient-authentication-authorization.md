---
title: 'MCP07: Insufficient Authentication and Authorization'
description: OWASP MCP Top 10 reference for authentication and authorization vulnerabilities including identity verification and access control enforcement patterns
---

# 07 Insufficient Authentication and Authorization

Identifier: MCP07:2025
Category: Access Control

## Description

Inadequate authentication and authorization occur when MCP servers, tools, or agents fail to verify
identities or enforce access controls during interactions.
MCP ecosystems involve multiple agents, users, and services exchanging data and executing actions.
Weak or missing identity validation exposes critical attack paths.
Insecure authentication manifests as missing or optional token validation, hard-coded shared
secrets, static credentials, and insecure token issuance.
Authorization flaws occur when agents perform actions beyond intended privileges, access controls
rely on client-side enforcement, or tool endpoints do not validate permission scopes.

## Impact

* Unauthorized actions or data access (triggering deployment, retrieving confidential data).
* Privilege escalation through token reuse or misconfigured scopes.
* Cross-agent impersonation where one agent acts as another.
* Data leakage via over-permissive APIs or shared context tokens.
* Service compromise allowing attackers to chain actions through trusted connectors.
* Regulatory and compliance exposure when sensitive data is accessed without audit trails.

## Vulnerability checklist

* MCP servers do not require mutual authentication between agents and tools.
* Tokens or API keys are shared, static, or long-lived.
* Authorization decisions rely on client input rather than server-side checks.
* Tools do not validate caller identity or scope before execution.
* No RBAC or ABAC model exists.
* Access logs lack identity correlation between agent and user actions.
* Agents can reuse tokens or credentials issued to others.
* No expiration or rotation policies for authentication credentials.

## Prevention controls

1. Require mutual TLS (mTLS) between MCP clients, agents, and servers.
2. Use short-lived, scoped tokens (JWT/OAuth2) tied to specific sessions and permissions.
3. Enforce token binding to agent identity via signed agent attestation.
4. Validate every token on the server side.
5. Adopt RBAC or ABAC models with per-request permission evaluation.
6. Apply deny-by-default for unrecognized agents or scopes.
7. Enforce expiration, rotation, and revocation policies for all tokens.
8. Store tokens securely (vaulted or encrypted).
9. Integrate MCP authentication with organizational IAM or OIDC providers.
10. Disable guest or anonymous access in all MCP endpoints.

## Example attack scenarios

### Scenario A — Token replay attack

An attacker intercepts a static API token and reuses it to perform admin-level actions on another
server because the token is not bound to a specific identity.

### Scenario B — Cross-agent privilege escalation

A misconfigured Testing agent shares the same authorization scope as Production.
A developer unintentionally executes tool commands against production data.

### Scenario C — Spoofed identity in unverified agent

A malicious service registers as a fake MCP agent using an unprotected onboarding endpoint.
Without certificate validation it is treated as a legitimate internal agent.

### Scenario D — Inherited context tokens

An assistant agent inherits parent credentials through shared context, allowing it to execute
privileged functions intended only for admins.

## Detection signals

* Tokens reused across multiple agents or IP addresses.
* Failed authentication attempts followed by successful privileged actions.
* Actions performed by unknown or unregistered agent IDs.
* Sudden increase in unauthorized 403 responses in logs.
* Tokens used after expiry timestamps.

## Remediation

* Revoke all compromised or static tokens immediately.
* Rotate all service credentials and enforce unique per-agent identities.
* Enable mTLS and strict API key binding.
* Audit existing agents, tools, and connectors for excessive privileges.
* Patch authorization middleware to enforce scope validation.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
