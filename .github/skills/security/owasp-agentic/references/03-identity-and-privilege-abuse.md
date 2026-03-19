---
title: 'ASI03: Identity and Privilege Abuse'
description: OWASP Agentic Top 10 reference for identity and privilege abuse where agents escalate or misuse granted permissions
---

# 03 Identity and Privilege Abuse

Identifier: ASI03:2026
Category: Access Control

## Description

Identity and privilege abuse exploits dynamic trust and delegation in agents to escalate access
and bypass controls by manipulating delegation chains, role inheritance, control flows, and agent
context.
Context includes cached credentials or conversation history across interconnected systems.
Identity refers both to the agent's defined persona and to any authentication material that
represents it.
Agent-to-agent trust or inherited credentials can be exploited to escalate access, hijack
privileges, or execute unauthorized actions.

This risk arises from the architectural mismatch between user-centric identity systems and
agentic design.
Without a distinct, governed identity of its own, an agent operates in an attribution gap that
makes enforcing true least privilege impossible.

This differs from ASI02 (Tool Misuse) which covers unintended or unsafe use of already granted
privilege by a principal misusing its own tools.

## Risk

* Escalation of access through manipulation of delegation chains, role inheritance, and agent
  context.
* Unauthorized data exfiltration through inherited privileges that exceed the intended scope.
* Fraudulent financial transactions executed through cross-agent trust exploitation.
* Creation of unauthorized accounts or credentials through memory-based privilege retention.
* Completion of unauthorized transactions due to workflow authorization drift where permissions
  change after initial validation.
* System-level command execution through forged agent personas in internal registries.
* Attribution gap preventing forensic tracing of privileged actions to their true origin.

## Vulnerability checklist

* A high-privilege agent delegates tasks without applying least-privilege scoping, passing its
  full access context to a narrow worker.
* Agents cache credentials, keys, or retrieved data for context and reuse without segmentation
  or clearing between tasks.
* In multi-agent systems, a compromised low-privilege agent can relay valid-looking instructions
  to a high-privilege agent without re-checking the original user's intent.
* Permissions validated at workflow start change or expire before execution, but the agent
  continues with outdated authorization.
* Attackers impersonate internal agents using unverified descriptors to gain inherited trust and
  perform privileged actions under a fabricated identity.

## Prevention controls

1. Issue short-lived, narrowly scoped tokens per task and cap rights with permission boundaries
   using per-agent identities and short-lived credentials to limit blast radius.
2. Run per-session sandboxes with separated permissions and memory, wiping state between tasks to
   prevent memory-based escalation.
3. Re-verify each privileged step with a centralized policy engine that checks external data,
   stopping cross-agent trust exploitation.
4. Require human approval for high-privilege or irreversible actions.
5. Bind OAuth tokens to a signed intent that includes subject, audience, purpose, and session.
   Reject any token use where the bound intent does not match the current request.
6. Evaluate agentic identity management platforms that treat agents as managed non-human
   identities with scoped credentials, audit trails, and lifecycle controls.
7. Bind permissions to subject, resource, purpose, and duration. Require re-authentication on
   context switch. Prevent privilege inheritance across agents unless the original intent is
   re-validated.

## Example attack scenarios

### Scenario A — Delegated privilege abuse

A finance agent delegates to a DB query agent but passes all its permissions.
An attacker steering the query prompts uses the inherited access to exfiltrate HR and legal data.

### Scenario B — Memory-based escalation

An IT admin agent caches SSH credentials during a patch.
Later a non-admin reuses the same session and prompts it to use those credentials to create an
unauthorized account.

### Scenario C — Cross-agent trust exploitation

A crafted email from IT instructs an email sorting agent to instruct a finance agent to move
money to a specific account.
The sorter agent forwards it, and the finance agent, trusting an internal agent, processes the
fraudulent payment without verification.

### Scenario D — Workflow authorization drift

A procurement agent validates approval at the start of a purchase sequence.
Hours later, the user's spending limit is reduced, but the workflow proceeds with the old
authorization token, completing the now-unauthorized transaction.

### Scenario E — Forged agent persona

An attacker registers a fake "Admin Helper" agent in an internal registry with a forged agent
card.
Other agents, trusting the descriptor, route privileged maintenance tasks to it.
The attacker-controlled agent then issues system-level commands under assumed internal trust.

## Detection guidance

* Monitor when an agent gains new permissions indirectly through delegation chains and flag cases
  where a low-privilege agent inherits higher-privilege scopes during multi-agent workflows.
* Detect abnormal cross-agent privilege elevation and device-code style phishing flows by
  monitoring when agents request new scopes or reuse tokens outside their original signed intent.
* Track permission boundaries and alert when task-scoped tokens are used beyond their intended
  duration or context.
* Audit agent identity registries for unverified or suspicious agent descriptors.

## Remediation

* Enforce task-scoped, time-bound permissions with per-agent identities and short-lived
  credentials.
* Isolate agent identities and contexts with per-session sandboxes that wipe state between tasks.
* Implement per-action authorization with centralized policy engine verification for each
  privileged step.
* Deploy human-in-the-loop approval for high-privilege or irreversible actions.
* Bind OAuth tokens to signed intents and reject mismatched token usage.
* Remove unverified agent descriptors from internal registries and require cryptographic
  attestation.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
