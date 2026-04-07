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

## Risk

* System-wide harm from propagation of a single fault across autonomous agents and workflows.
* Compromised confidentiality, integrity, and availability through latent fault chains reaching
  privileged operations.
* Automated execution of unsafe steps without validation due to planner-executor coupling.
* Persistent error propagation through corrupted long-term memory that influences new plans and
  delegations.
* Governance drift from weakened human oversight after repeated success leading to unchecked
  configuration changes.
* Feedback-loop amplification where agents relying on each other's outputs magnify initial errors.
* Catastrophic defensive actions from propagation of hallucinated or injected false alerts across
  multi-agent systems.

## Vulnerability checklist

* A hallucinating or compromised planner emits unsafe steps that the executor automatically
  performs without validation.
* Poisoned long-term goals or state entries continue influencing new plans and delegations after
  the original source is removed.
* A single corrupted update can cause peer agents to act on false alerts or reboot instructions
  across regions.
* One agent's misuse of an integration or elevated credential leads downstream agents to repeat
  unsafe actions.
* A poisoned or faulty release pushed by an orchestrator propagates automatically to all
  connected agents.
* Human oversight weakens after repeated success and bulk approvals propagate unchecked
  configuration drift.
* Two or more agents rely on each other's outputs, creating a self-reinforcing loop that
  magnifies initial errors.

## Prevention controls

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
6. Implement blast-radius guardrails such as quotas, progress caps, and circuit breakers between
   planner and executor.
7. Re-run recorded agent actions in an isolated clone to test whether sequences trigger cascading
   failures. Gate policy expansion on replay tests passing predefined blast-radius caps.

## Example attack scenarios

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

## Detection guidance

* Detect fast-spreading commands across agent networks and throttle or pause on anomalies.
* Track decisions against baselines and alignment and flag gradual degradation.
* Monitor for rapid fan-out where one faulty decision triggers many downstream agents in a short
  time.
* Detect cross-domain or tenant spread of faults beyond the original context.
* Identify oscillating retries or feedback loops between agents and downstream queue storms.
* Record all inter-agent messages, policy decisions, and execution outcomes in tamper-evident,
  time-stamped logs bound to cryptographic agent identities.

## Remediation

* Deploy circuit breakers between planner and executor to halt cascading propagation.
* Isolate affected agents with least privilege and network segmentation to contain failure spread.
* Roll back corrupted persistent memory and state entries using version-controlled snapshots.
* Revoke task-scoped credentials for compromised agent runs and re-validate all downstream
  actions.
* Restore human oversight checkpoints for any governance drift identified during the cascade.
* Maintain lineage metadata for every propagated action to support forensic traceability and
  rollback validation.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
