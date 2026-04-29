---
title: 'MCP10: Context Injection and Over-Sharing'
description: OWASP MCP Top 10 reference for context injection vulnerabilities including data over-sharing and insufficient context isolation patterns
---

# 10 Context Injection and Over-Sharing

Identifier: MCP10:2025
Category: Data Isolation

## Description

In MCP systems, context acts as working memory for agents, storing prompts, retrieved documents,
intermediate reasoning, and interaction history.
When context is shared, persistently stored, or insufficiently scoped, sensitive information from
one session, agent, or user can leak into another.
Context Injection occurs when malicious or unintended content is embedded into shared memory,
influencing how future requests are processed.
Over-Sharing occurs when context is reused across agents or workflows that should be isolated.
Together these issues cause private or sensitive information to propagate beyond intended
boundaries.

## Impact

* Cross-agent and cross-user data leakage.
* Violation of privacy regulations (GDPR, HIPAA, PCI DSS).
* Unauthorized exposure of trade secrets and internal strategy.
* Persistent contamination of model behavior due to injected context.
* Loss of trust in AI systems and internal tools.
* Legal, financial, and reputational damage.

## Vulnerability checklist

* Agents or services share a common context buffer or vector store.
* Context memory persists across multiple users or sessions.
* Context is reused for performance optimization without revalidation.
* Sensitive data enters context without classification or tagging.
* No policy defines context lifetime (no TTL or expiry rule).
* Context or embeddings are reused for multi-agent reasoning.
* The same context store is accessible across teams or departments.
* Agents can access each other's memory without access checks.

## Prevention controls

1. Make context windows short-lived and per-session by default.
2. Enforce automatic context deletion after task completion.
3. Assign unique context namespaces per user, agent, workflow, and tenant.
4. Prevent agents from accessing another agent's memory directly.
5. Isolate retrieval indexes and vector stores in multi-tenant setups.
6. Tag all inputs and retrieved data with classification levels (Public, Internal, Confidential, Restricted).
7. Define TTL policies (session end, 30 minutes, 24 hours max) and auto-purge expired contexts.
8. Scan and redact PII, secrets, tokens, and internal identifiers before storing in context.
9. Require approval before sensitive context is exported, summarized, or shared across agents.
10. Detect and block instruction-like content attempting to persist in memory.

## Example attack scenarios

### Scenario A — Cross-team data leak

Support and marketing teams share the same MCP agent infrastructure.
The marketing agent retrieves support transcripts containing sensitive customer disputes and
internal policy details.

### Scenario B — Multi-tenant context bleed

A cloud MCP platform fails to isolate vector stores between tenants.
Tenant A's internal documents appear in Tenant B's retrieval outputs.

## Detection signals

* Context data appearing in sessions for unrelated users or agents.
* Instruction-like patterns detected in stored context memory.
* Shared vector store queries returning cross-tenant results.
* Context TTL violations or stale entries persisting beyond policy limits.

## Remediation

* Purge existing shared contexts and caches.
* Enforce per-agent and per-user segmentation.
* Introduce TTL policies and auto-purge logic.
* Rotate keys and invalidate context stores if contamination is confirmed.
* Review access control around vector databases and embeddings.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-NC-SA 4.0
(<https://creativecommons.org/licenses/by-nc-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
