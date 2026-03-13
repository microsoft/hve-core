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

## Common examples

1. RAG and embeddings poisoning: malicious or manipulated data enters the vector DB via poisoned
   sources, direct uploads, or over-trusted pipelines. This results in false answers and targeted
   payloads.
2. Shared user context poisoning: reused or shared contexts let attackers inject data through
   normal chats, influencing later sessions with misinformation, unsafe code execution, or
   incorrect tool actions.
3. Context-window manipulation: an attacker injects crafted content into an ongoing conversation
   or task so that it is later summarized or persisted in memory, contaminating future reasoning
   even after the original session ends.
4. Long-term memory drift: incremental exposure to subtly tainted data, summaries, or peer-agent
   feedback gradually shifts stored knowledge or goal weighting, producing behavioral or policy
   deviations over time.
5. Systemic misalignment and backdoors: poisoned memory shifts the model's persona and plants
   trigger-based backdoors that execute hidden instructions.
6. Cross-agent propagation: contaminated context or shared memory spreads between cooperating
   agents, compounding corruption and enabling long-term data leakage or coordinated drift.

## Attack scenarios

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

## Prevention and mitigation

1. Encryption in transit and at rest combined with least-privilege access.
2. Scan all new memory writes and model outputs (rules and AI) for malicious or sensitive content
   before commit.
3. Isolate user sessions and domain contexts to prevent knowledge and sensitive data leakage.
4. Allow only authenticated, curated sources. Enforce context-aware access per task. Minimize
   retention by data sensitivity.
5. Require source attribution and detect suspicious updates or frequencies.
6. Prevent automatic re-ingestion of an agent's own generated outputs into trusted memory to
   avoid self-reinforcing contamination.
7. Perform adversarial tests, use snapshots and rollback and version control, and require human
   review for high-risk actions. Use per-tenant namespaces and trust scores for entries, decaying
   or expiring unverified memory over time.
8. Expire unverified memory to limit poison persistence.
9. Weight retrieval by trust and tenancy. Require two factors to surface high-impact memory and
   decay low-trust entries over time.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
