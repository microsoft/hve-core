---
title: 'MCP03: Tool Poisoning'
description: OWASP MCP Top 10 reference for tool poisoning vulnerabilities including schema tampering and contract manipulation patterns
---

# 03 Tool Poisoning

Identifier: MCP03:2025
Category: Supply Chain / Integrity

## Description

Schema poisoning occurs when an adversary tampers with contract or schema definitions governing
agent-to-tool interactions in an MCP ecosystem.
Schemas define the shape, types, and semantics of requests and responses.
If an attacker modifies a schema so that a benign-sounding operation maps to a destructive action,
agents that trust the schema may execute dangerous commands while passing superficial validation.
This is a supply-chain style compromise: the attacker changes the contract so legitimate agents
behave incorrectly.

## Impact

* Data loss or corruption when benign workflows cause irreversible deletion.
* Privilege abuse when schema fields map to higher-risk operations.
* Silent policy bypass when validation checks match a malicious schema.
* Widespread compromise when a single poisoned schema propagates across agents and tenants.
* Erosion of trust and auditability when logs show valid actions per a malicious contract.

## Vulnerability checklist

* Schemas or tool descriptors are fetched dynamically without integrity checks.
* Writable schema registry lacks RBAC, code review, or approvals.
* Schema edits are promoted to production automatically without signed commits.
* Agents accept schema changes at runtime without operator confirmation.
* No provenance or version binding is stored with the schema.
* No testing asserts semantic invariants (e.g., archive must not map to DELETE).

## Prevention controls

1. Digitally sign schemas and tool manifests (JWS, COSE, PKI-backed signatures).
2. Use content-addressable identifiers (hashes) for schema versions.
3. Store schemas in immutable version-controlled systems with signed commits.
4. Enforce branch protections, required code review, and multi-person approval.
5. Apply least-privilege RBAC to schema registries.
6. Encode semantic invariants as policy-as-code checks (OPA/Rego).
7. Include provenance metadata (author, signature, hash, timestamp) per schema version.
8. Require schema attestation binding the hash to agent identity and session.
9. Implement runtime sanity checks for destructive verbs or high data-volume operations.
10. Pause execution and require human approval when impact thresholds are exceeded.

## Example attack scenarios

### Scenario A — Compromised CI pipeline promotes malicious schema

An attacker compromises a CI/CD runner and pushes a schema remapping archive to DELETE.
Agents across production begin issuing destructive calls.

### Scenario B — Dependency supply-chain tampering

A dependency providing tool manifests is trojaned.
Consumers fetch tampered schemas during startup that alter semantics for a widely used tool.

### Scenario C — Insider abuse via registry write access

An insider with write access modifies a schema to escalate an agent's abilities, enabling
unauthorized data access and exfiltration.

### Scenario D — Man-in-the-middle rewriting schemas in transit

Schemas served over unsecured channels are rewritten in transit, altering operation verbs so
benign requests become destructive.

## Detection signals

* Unexpected changes to schema hashes or versions in deployment logs.
* Agents performing operations inconsistent with documented tool semantics.
* Schema fetches from untrusted or unsigned sources.
* Destructive operations triggered by benign workflow invocations.

## Remediation

* Revoke or block the promoted schema version.
* Roll back agents to the last known-good schema hash and force revalidation.
* Rotate tokens or credentials that may have been abused.
* Conduct forensic analysis of affected agents, actions, and data changes.
* Patch CI/CD and registry processes to require signed commits and multi-party approvals.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
