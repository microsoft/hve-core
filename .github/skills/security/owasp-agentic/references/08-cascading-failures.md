---
title: 'ASI08: Cascading Failures'
description: OWASP Agentic Top 10 reference for cascading failure vulnerabilities where single agent failures propagate through multi-agent systems
---

# 08 Cascading Failures

Identifier: ASI08:2026
Category: Resilience

## Description

Agentic cascading failures occur when a single fault (hallucination, malicious input, corrupted
tool, or poisoned memory) propagates across autonomous agents, compounding into system-wide harm.
Because agents plan, persist, and delegate autonomously, a single error can bypass stepwise human
checks and persist in a saved state.
As agents form emergent links to new tools or peers, these latent faults chain into privileged
operations that compromise confidentiality, integrity, and availability.

Cascading failures describes the propagation and amplification of an initial fault, not the
initial vulnerability itself, across agents, tools, and workflows, turning a single error into
system-wide impact.

Observable symptoms include rapid fan-out where one faulty decision triggers many downstream
agents, cross-domain or tenant spread beyond the original context, oscillating retries or
feedback loops between agents, and downstream queue storms or repeated identical intents.

## Common examples

1. Planner-executor coupling: a hallucinating or compromised planner emits unsafe steps that the
   executor automatically performs without validation, multiplying impact across agents.
2. Corrupted persistent memory: poisoned long-term goals or state entries continue influencing
   new plans and delegations, propagating error even after the original source is gone.
3. Inter-agent cascades from poisoned messages: a single corrupted update causes peer agents to
   act on false alerts or reboot instructions, spreading disruption across regions.
4. Cascading tool misuse and privilege escalation: one agent's misuse of an integration or
   elevated credential leads downstream agents to repeat unsafe actions.
5. Auto-deployment cascade from tainted update: a poisoned release pushed by an orchestrator
   propagates automatically to all connected agents.
6. Governance drift cascade: human oversight weakens after repeated success. Bulk approvals or
   policy relaxations propagate unchecked configuration drift across agents.
7. Feedback-loop amplification: two or more agents rely on each other's outputs, creating a
   self-reinforcing loop that magnifies initial errors.

## Attack scenarios

### Scenario A — Financial trading cascade

Prompt injection poisons a market analysis agent, inflating risk limits.
Position and execution agents auto-trade larger positions while compliance stays blind to
within-parameter activity.

### Scenario B — Healthcare protocol propagation

Supply chain tampering corrupts drug data. Treatment auto-adjusts protocols, and care
coordination spreads them network-wide without human review.

### Scenario C — Cloud orchestration breakdown

Poisoning in resource planning adds unauthorized permissions.
Security applies them, and deployment provisions backdoored, costly infrastructure without
per-change approval.

### Scenario D — Auto-remediation feedback loop

A remediation agent suppresses alerts to meet latency SLAs.
A planning agent interprets fewer alerts as success and widens automation, compounding blind
spots across regions.

### Scenario E — Agentic cyber defense hallucination

Propagation of a hallucinated imminent attack is propagated in underlying multi-agent systems,
causing unnecessary but catastrophic defensive actions such as shutdowns, denials, and network
disconnects.

## Prevention and mitigation

1. Design systems with zero-trust fault tolerance that assumes availability failure of agentic
   function components and external sources.
2. Sandbox agents with least privilege, network segmentation, scoped APIs, and mutual auth to
   contain failure propagation.
3. Issue short-lived, task-scoped credentials for each agent run and validate every high-impact
   tool invocation against a policy-as-code rule before executing it.
4. Separate planning and execution via an external policy engine to prevent corrupt planning from
   triggering harmful actions.
5. Implement checkpoints, governance agents, or human review for high-risk actions before agent
   outputs are propagated downstream.
6. Detect fast-spreading commands and throttle or pause on anomalies.
7. Implement blast-radius guardrails such as quotas, progress caps, and circuit breakers between
   planner and executor.
8. Track decisions against baselines and alignment. Flag gradual degradation.
9. Re-run recorded agent actions in an isolated clone to test whether sequences trigger cascading
   failures. Gate policy expansion on replay tests passing predefined blast-radius caps.
10. Record all inter-agent messages, policy decisions, and execution outcomes in tamper-evident,
    time-stamped logs bound to cryptographic agent identities. Maintain lineage metadata for
    every propagated action you can trace.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
