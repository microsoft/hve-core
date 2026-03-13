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

## Common examples

1. Un-scoped privilege inheritance: a high-privilege manager delegates tasks without applying
   least-privilege scoping, passing its full access context to a narrow worker.
2. Memory-based privilege retention and data leakage: agents cache credentials, keys, or retrieved
   data for context and reuse. Without segmentation or clearing between tasks, attackers can
   prompt the agent to reuse cached secrets or leak data from a prior secure session.
3. Cross-agent trust exploitation (confused deputy): in multi-agent systems, a compromised
   low-privilege agent relays valid-looking instructions to a high-privilege agent, which executes
   them without re-checking the original user's intent.
4. Time-of-check to time-of-use (TOCTOU) in agent workflows: permissions validated at workflow
   start change or expire before execution, but the agent continues with outdated authorization.
5. Synthetic identity injection: attackers impersonate internal agents using unverified descriptors
   to gain inherited trust and perform privileged actions under a fabricated identity.

## Attack scenarios

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

## Prevention and mitigation

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
8. Monitor when an agent gains new permissions indirectly through delegation chains and flag cases
   where a low-privilege agent inherits higher-privilege scopes during multi-agent workflows.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
