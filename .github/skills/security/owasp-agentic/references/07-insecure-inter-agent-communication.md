---
title: 'ASI07: Insecure Inter-Agent Communication'
description: OWASP Agentic Top 10 reference for insecure inter-agent communication vulnerabilities in multi-agent systems
---

# 07 Insecure Inter-Agent Communication

Identifier: ASI07:2026
Category: Communication Security

## Description

Multi-agent systems depend on continuous communication between autonomous agents that coordinate
via APIs, message buses, and shared memory, significantly expanding the attack surface.
Decentralized architecture, varying autonomy, and uneven trust make perimeter-based security
models ineffective.
Weak inter-agent controls for authentication, integrity, confidentiality, or authorization let
attackers intercept, manipulate, spoof, or block messages.

Insecure inter-agent communication occurs when these exchanges lack proper authentication,
integrity, or semantic validation, allowing interception, spoofing, or manipulation of agent
messages and intents.
The threat spans transport, routing, discovery, and semantic layers, including covert or
side-channels where agents leak or infer data through timing or behavioral cues.

This differs from ASI03 (Identity and Privilege Abuse), which focuses on credential and
permissions misuse, and ASI06 (Memory and Context Poisoning), which targets stored knowledge
corruption.
ASI07 focuses on compromising real-time messages between agents.

## Common examples

1. Unencrypted channels enabling semantic manipulation: MITM intercepts unencrypted messages and
   injects hidden instructions altering agent goals and decision logic.
2. Message tampering leading to cross-context contamination: modified or injected messages blur
   task boundaries between agents, leading to data leakage or goal confusion.
3. Replay on trust chains: replayed delegation or trust messages trick agents into granting access
   or honoring stale instructions.
4. Protocol downgrade and descriptor forgery: attackers coerce agents into weaker communication
   modes or spoof agent descriptors, making malicious commands appear as valid exchanges.
5. Message-routing attacks on discovery and coordination: misdirected discovery traffic forges
   relationships with malicious agents or unauthorized coordinators.
6. Metadata analysis for behavioral profiling: traffic patterns reveal decision cycles and
   relationships, enabling prediction and manipulation of agent behavior.

## Attack scenarios

### Scenario A — Semantic injection via unencrypted communications

Over HTTP or other unauthenticated channels, a MITM attacker injects hidden instructions,
causing agents to produce biased or malicious results while appearing normal.

### Scenario B — Trust poisoning via message tampering

In an agentic trading network, altered reputation messages skew which agents are trusted for
decisions.

### Scenario C — Context confusion via replay

Replayed emergency coordination messages trigger outdated procedures and resource misallocation.

### Scenario D — Agent-in-the-Middle via descriptor poisoning

A malicious endpoint advertises spoofed agent descriptors or false capabilities.
When trusted, it routes sensitive data through attacker infrastructure.

### Scenario E — Semantics split-brain

A single instruction is parsed into divergent intents by different agents, producing conflicting
but seemingly legitimate actions.

## Prevention and mitigation

1. Use end-to-end encryption with per-agent credentials and mutual authentication. Enforce PKI
   certificate pinning, forward secrecy, and regular protocol reviews.
2. Digitally sign messages, hash both payload and context, and validate for hidden or modified
   natural-language instructions. Apply natural-language-aware sanitization and intent-diffing.
3. Protect all exchanges with nonces, session identifiers, and timestamps tied to task windows.
   Maintain short-term message fingerprints to detect cross-context replays.
4. Disable weak or legacy communication modes. Require agent-specific trust negotiation and bind
   protocol authentication to agent identity.
5. Reduce the attack surface for traffic analysis by using fixed-size or padded messages where
   feasible, smoothing communication rates, and avoiding deterministic schedules.
6. Define and enforce allowed protocol versions. Reject downgrade attempts or unrecognized schemas
   and validate that both peers advertise matching capability and version fingerprints.
7. Authenticate all discovery and coordination messages using cryptographic identity. Secure
   directories with access controls and verified reputations.
8. Use registries that provide digital attestation of agent identity, provenance, and descriptor
   integrity. Require signed agent cards and continuous verification before accepting messages.
9. Use versioned, typed message schemas with explicit per-message audiences. Reject messages that
   fail validation or attempt schema down-conversion without declared compatibility.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
