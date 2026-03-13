---
title: 'ASI01: Agent Goal Hijack'
description: OWASP Agentic Top 10 reference for agent goal hijack vulnerabilities where adversaries redirect autonomous agent objectives
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - agentic
  - goal-hijack
  - security
estimated_reading_time: 5
---

# 01 Agent Goal Hijack

Identifier: ASI01:2026
Category: Goal Integrity

## Description

AI agents exhibit autonomous ability to execute a series of tasks to achieve a goal.
Attackers can manipulate an agent's objectives, task selection, or decision pathways through
prompt-based manipulation, deceptive tool outputs, malicious artefacts, forged agent-to-agent
messages, or poisoned external data.
Because agents rely on untyped natural-language inputs and loosely governed orchestration logic,
they cannot reliably distinguish legitimate instructions from attacker-controlled content.
Unlike single-model prompt injection that alters one response, agent goal hijack redirects goals,
planning, and multi-step behavior.

Agent goal hijack differs from memory and context poisoning (ASI06) and rogue agents (ASI10).
The attacker directly alters the agent's goals, instructions, or decision pathways regardless
of whether the manipulation occurs interactively or through pre-positioned inputs such as
documents, templates, or external data sources.

## Common examples

1. Indirect prompt injection via hidden instruction payloads embedded in web pages or documents
   in a RAG scenario silently redirect an agent to exfiltrate sensitive data or misuse connected
   tools.
2. Indirect prompt injection through external communication channels (email, calendar, teams)
   hijacks an agent's internal communication capability, sending unauthorized messages under a
   trusted identity.
3. A malicious prompt override manipulates a financial agent into transferring money to an
   attacker's account.
4. Indirect prompt injection overrides agent instructions making it produce fraudulent information
   that impacts business decisions.

## Attack scenarios

### Scenario A — Zero-click indirect prompt injection

An attacker emails a crafted message that silently triggers a copilot to execute hidden
instructions, causing the AI to exfiltrate confidential emails, files, and chat logs without
any user interaction.

### Scenario B — Operator prompt injection via web content

An attacker plants malicious content on a web page that an operator agent processes in search
or RAG scenarios, tricking it into following unauthorized instructions.
The agent then accesses authenticated internal pages and exposes users' private data.

### Scenario C — Goal-lock drift via scheduled prompts

A malicious calendar invite injects a recurring "quiet mode" instruction that subtly reweights
objectives each morning, steering the planner toward low-friction approvals while keeping
actions inside declared policies.

### Scenario D — Inception attack on chat users

A malicious Google Doc injects instructions for a chat assistant to exfiltrate user data and
convinces the user to make an ill-advised business decision.

## Prevention and mitigation

1. Treat all natural-language inputs (user-provided text, uploaded documents, retrieved content)
   as untrusted and route them through input-validation and prompt-injection safeguards before
   they can influence goal selection, planning, or tool calls.
2. Minimize the impact of goal hijacking by enforcing least privilege for agent tools and requiring
   human approval for high-impact or goal-changing actions.
3. Define and lock agent system prompts so that goal priorities and permitted actions are explicit
   and auditable. Changes to goals or reward definitions must go through configuration management
   and human approval.
4. At run time, validate both user intent and agent intent before executing goal-changing or
   high-impact actions. Require confirmation via human approval, policy engine, or platform
   guardrails whenever the agent proposes actions that deviate from the original task or scope.
5. Sanitize and validate any connected data source including RAG inputs, emails, calendar invites,
   uploaded files, external APIs, browsing output, and peer-agent messages using content filtering
   before the data can influence agent goals or actions.
6. Maintain comprehensive logging and continuous monitoring of agent activity, establishing a
   behavioral baseline that includes goal state, tool-use patterns, and invariant properties.
7. Conduct periodic red-team tests simulating goal override and verify rollback effectiveness.
8. Incorporate AI agents into the established insider threat program to monitor prompts intended
   to access sensitive data or alter agent behavior.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
