---
title: 'MCP01: Token Mismanagement and Secret Exposure'
description: OWASP MCP Top 10 reference for token mismanagement and secret exposure vulnerabilities including credential leakage and secret handling patterns
---

# 01 Token Mismanagement and Secret Exposure

Identifier: MCP01:2025
Category: Credential Hygiene

## Description

Tokens and credentials serve as the primary authentication and authorization mechanism between
models, tools, and servers in MCP systems.
Developers frequently mishandle secrets by embedding them in configuration files, environment
variables, prompt templates, or allowing them to persist within model context memory.
MCP enables long-lived sessions, stateful agents, and context persistence, which means tokens
can be inadvertently stored, indexed, or retrieved through user prompts, system recalls, or log
inspection.
This creates contextual secret leakage where the model or protocol layer becomes an unintentional
secret repository.

## Impact

* Complete environment compromise through API or infrastructure access.
* Unauthorized code modifications or repository tampering.
* Lateral movement across integrated services (CI/CD, cloud storage, issue trackers).
* Data exfiltration from vector databases or file stores associated with the MCP server.
* High-impact permissions granted without direct human intervention.

## Vulnerability checklist

* Tokens or API keys are hard-coded in MCP client, server, or tool configurations.
* Models or agents retain conversational memory that includes secrets.
* Logs, telemetry, or vector stores record full prompts or responses without redaction.
* Token lifetimes exceed session duration or lack enforced rotation.
* System relies on shared or static service accounts instead of user-scoped credentials.

## Prevention controls

1. Store secrets in secure vaults (HashiCorp Vault, AWS Secrets Manager).
2. Use environment variable injection only at runtime, never at build time.
3. Issue short-lived, scoped tokens aligned with least privilege principles.
4. Require token renewal for every new MCP session.
5. Bind tokens to the specific agent, tool, or session context.
6. Prevent sensitive data persistence in model memory or context windows.
7. Redact or sanitize inputs and outputs before logging.
8. Use ephemeral contexts for operations involving credentials.
9. Rotate and invalidate all tokens immediately upon suspected exposure.
10. Use HSMs or Secrets Managers for runtime injection.

## Example attack scenarios

### Scenario A — Prompt recall exposure

An attacker interacts with an AI agent previously used by a developer and issues a crafted prompt
requesting stored configuration variables or API tokens from earlier sessions.
The model reproduces a stored API key from memory.

### Scenario B — Log scraping

System debug logs contain raw MCP payloads including tokens passed in tool calls.
An attacker with read access retrieves credentials and pushes unauthorized code to production.

### Scenario C — Context poisoning for secret extraction

A malicious user injects a meta-instruction into shared context memory instructing the model to
include secrets in future responses.
The model complies in a later unrelated session, leaking tokens.

## Detection signals

* Tokens appearing in log files, telemetry, or prompt histories.
* Credentials reused across multiple agents or sessions.
* Long-lived tokens without rotation events.
* Secret patterns detected in context memory or vector stores.

## Remediation

* Revoke all compromised or static tokens immediately.
* Rotate all service credentials and enforce unique per-agent identities.
* Audit MCP configurations, server endpoints, and stored contexts.
* Implement redaction pipelines for logs and telemetry.
* Define organizational policies for credential lifecycle management.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
