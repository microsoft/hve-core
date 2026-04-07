---
title: 'ASI06: Memory and Context Poisoning'
description: OWASP Agentic Top 10 reference for memory and context poisoning attacks targeting agent state and retrieval systems
---

# 06 Memory and Context Poisoning

Identifier: ASI06:2026
Category: Data Integrity

## Description

Agentic systems rely on stored and retrievable information which can be a snapshot of
conversation history, a memory tool, or expanded context, supporting continuity across tasks
and reasoning cycles.
Context includes any information an agent retains, retrieves, or reuses, such as summaries,
embeddings, and RAG stores, but excludes one-time input prompts.

In memory and context poisoning, adversaries corrupt or seed this context with malicious or
misleading data, causing future reasoning, planning, or tool use to become biased, unsafe, or
aid exfiltration.
Ingestion sources such as uploads, API feeds, user input, or peer-agent exchanges may be
untrusted or only partially validated.

This risk is distinct from ASI01 (Goal Hijack), which captures direct goal manipulation, and
ASI08 (Cascading Failures), which describes degradation after poisoning occurs.
However, memory poisoning frequently leads to goal hijacking as corrupted context or long-term
memory can alter goal interpretation, reasoning path, or tool-selection logic.

## Risk

* Biased or unsafe future reasoning and planning from corrupted stored context.
* Data exfiltration through poisoned memory that alters agent tool-use behavior.
* Unauthorized escalation of permissions through context window exploitation across sessions.
* Evasion of security detection systems through memory retraining to label malicious activity
  as normal.
* Financial losses and business disputes from agents acting on fabricated policies stored in
  shared memory.
* Cross-tenant data leakage through vector namespace exploitation and cosine similarity attacks.
* Long-term behavioral drift from incremental exposure to subtly tainted data or peer-agent
  feedback.

## Vulnerability checklist

* Malicious or manipulated data can enter vector databases via poisoned sources, direct uploads,
  or over-trusted pipelines.
* Reused or shared contexts allow attackers to inject data through normal chats that influence
  later sessions.
* Crafted content injected into ongoing conversations can be summarized or persisted in memory,
  contaminating future reasoning.
* Incremental exposure to subtly tainted data or peer-agent feedback can gradually shift stored
  knowledge or goal weighting.
* Poisoned memory can shift the agent's persona and plant trigger-based backdoors that execute
  hidden instructions.
* Contaminated context or shared memory can spread between cooperating agents, compounding
  corruption.

## Prevention controls

1. Encryption in transit and at rest combined with least-privilege access.
2. Scan all new memory writes and model outputs (rules and AI) for malicious or sensitive content
   before commit.
3. Isolate user sessions and domain contexts to prevent knowledge and sensitive data leakage.
4. Allow only authenticated, curated sources. Enforce context-aware access per task. Minimize
   retention by data sensitivity.
5. Prevent automatic re-ingestion of an agent's own generated outputs into trusted memory to
   avoid self-reinforcing contamination.
6. Perform adversarial tests, use snapshots and rollback and version control, and require human
   review for high-risk actions. Use per-tenant namespaces and trust scores for entries, decaying
   or expiring unverified memory over time.

## Example attack scenarios

### Scenario A — Travel booking memory poisoning

An attacker keeps reinforcing a fake flight price, the assistant stores it as truth, then
approves bookings at that price and bypasses payment checks.

### Scenario B — Context window exploitation

The attacker splits attempts across sessions so earlier rejections drop out of context, and the
AI eventually grants escalating permissions up to admin access.

### Scenario C — Security system memory poisoning

The attacker retrains a security AI's memory to label malicious activity as normal, letting
attacks slip through undetected.

### Scenario D — Shared memory poisoning

The attacker inserts bogus refund policies into shared memory, other agents reuse them, and the
business suffers bad decisions, losses, and disputes.

### Scenario E — Cross-tenant vector bleed

Near-duplicate content seeded by an attacker exploits loose namespace filters, pulling another
tenant's sensitive chunk into retrieval by high cosine similarity.

## Detection guidance

* Require source attribution for all memory entries and detect suspicious update patterns or
  frequencies.
* Monitor for anomalous memory write patterns that may indicate poisoning attempts.
* Expire unverified memory entries to limit poison persistence and detect stale or untrusted data.
* Weight retrieval by trust and tenancy, requiring two factors to surface high-impact memory and
  decaying low-trust entries over time.
* Detect cross-tenant vector bleed by monitoring namespace boundary enforcement in shared vector
  stores.

## Remediation

* Quarantine and roll back suspected poisoned memory entries using version-controlled snapshots.
* Isolate affected user sessions and domain contexts to prevent further propagation.
* Re-scan all memory stores for malicious or sensitive content after a poisoning incident.
* Enforce per-tenant namespaces and trust scores for all shared memory and vector stores.
* Deploy content validation on all memory write paths including peer-agent exchanges.
* Expire unverified memory to limit the persistence window of poisoned entries.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
