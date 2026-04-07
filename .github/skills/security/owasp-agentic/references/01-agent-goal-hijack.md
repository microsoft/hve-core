---
title: 'ASI01: Agent Goal Hijack'
description: OWASP Agentic Top 10 reference for agent goal hijack vulnerabilities where adversaries redirect autonomous agent objectives
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

## Risk

* Exfiltration of confidential data including emails, files, and chat logs without user interaction.
* Hijacking of internal communication capabilities to send unauthorized messages under a trusted
  identity.
* Financial fraud through manipulated agent decisions such as unauthorized fund transfers.
* Production of fraudulent information that impacts business decisions.
* Silent redirection of agent planning and multi-step behavior toward attacker-controlled
  objectives.
* Exposure of private user data through manipulation of agents processing web content in search
  or RAG scenarios.

## Vulnerability checklist

* Hidden instruction payloads embedded in web pages or documents in RAG scenarios can silently
  redirect the agent to exfiltrate sensitive data or misuse connected tools.
* External communication channels such as email, calendar, or teams can inject instructions that
  hijack the agent's internal communication capability and send unauthorized messages under a
  trusted identity.
* Malicious prompt overrides can manipulate a financial agent into executing unauthorized actions
  such as transferring money to an attacker's account.
* Indirect prompt injection can override agent instructions to produce fraudulent information
  that impacts business decisions.

## Prevention controls

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
6. Conduct periodic red-team tests simulating goal override and verify rollback effectiveness.
7. Incorporate AI agents into the established insider threat program to monitor prompts intended
   to access sensitive data or alter agent behavior.

## Example attack scenarios

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

## Detection guidance

* Maintain comprehensive logging and continuous monitoring of agent activity, establishing a
  behavioral baseline that includes goal state, tool-use patterns, and invariant properties.
* Track a stable identifier for the active goal and alert on deviations such as unexpected goal
  changes, anomalous tool sequences, or shifts from the established baseline.
* Conduct periodic red-team tests simulating goal override scenarios to verify detection and
  rollback effectiveness.
* Monitor for insider prompts intended to access sensitive data or alter agent behavior through
  the established insider threat program.

## Remediation

* Implement input-validation and prompt-injection safeguards on all natural-language inputs that
  can influence agent goals.
* Lock agent system prompts and enforce configuration management for any goal or reward definition
  changes.
* Enforce least privilege for all agent tools and restrict tool access to the minimum required
  scope.
* Deploy content filtering on all connected data sources including RAG inputs, emails, and
  external APIs.
* Require human approval for any actions that deviate from the original task scope.
* Establish behavioral baselines and deploy automated alerting for goal drift or anomalous tool
  sequences.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
