---
title: 'LLM06: Excessive Agency'
description: OWASP LLM Top 10 reference for excessive agency vulnerabilities where LLM systems perform unintended actions with excessive permissions
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - llm
  - excessive-agency
  - access-control
  - security
estimated_reading_time: 5
---

# 06 Excessive Agency

Identifier: LLM06:2025
Category: Access Control

## Description

An LLM-based system is often granted a degree of agency by its developer — the ability to
call functions or interface with other systems via extensions (tools, skills, or plugins) to
undertake actions in response to a prompt. The decision over which extension to invoke may
also be delegated to an LLM agent to dynamically determine based on input prompt or output.

Excessive Agency is the vulnerability that enables damaging actions to be performed in
response to unexpected, ambiguous, or manipulated outputs from an LLM, regardless of what is
causing the LLM to malfunction. Common triggers include hallucination caused by poorly
engineered prompts, direct or indirect prompt injection from a malicious user, or a
malicious or compromised extension or peer agent.

The root cause is typically one or more of: excessive functionality, excessive permissions,
or excessive autonomy.

## Common examples

1. An LLM agent has access to extensions with functions not needed for the intended system
   operation, such as a read-only tool that also allows modify and delete.
2. An extension trialled during development remains available to the LLM agent after being
   replaced by a better alternative.
3. An LLM plugin with open-ended functionality fails to properly filter input instructions
   for commands outside what is necessary.
4. An LLM extension has permissions on downstream systems not needed for the intended
   operation, such as a read-only extension connecting with UPDATE and DELETE permissions.
5. An extension designed to operate in the context of an individual user accesses downstream
   systems with a generic high-privileged identity.
6. An LLM-based application fails to independently verify and approve high-impact actions,
   performing deletions without user confirmation.

## Attack scenarios

### Scenario A — Email exfiltration via excessive extension

An LLM-based personal assistant is granted mailbox access via an extension that includes
functions for sending messages beyond the needed read capability. A maliciously-crafted
incoming email tricks the LLM into scanning the inbox for sensitive information and
forwarding it to the attacker's email address.

## Prevention and mitigation

1. Limit the extensions that LLM agents are allowed to call to the minimum necessary.
2. Limit the functions implemented in LLM extensions to the minimum necessary.
3. Avoid open-ended extensions (run a shell command, fetch a URL) and use extensions with
   more granular functionality.
4. Limit the permissions that LLM extensions are granted to other systems to the minimum
   necessary.
5. Execute extensions in the user's context, tracking user authorization and security scope
   to ensure actions use minimum privileges.
6. Require human approval for high-impact actions via human-in-the-loop control.
7. Implement authorization in downstream systems rather than relying on the LLM to decide
   if an action is allowed.
8. Follow secure coding best practice, applying OWASP ASVS recommendations with strong
   focus on input sanitization, using SAST, DAST, and IAST in development pipelines.
9. Log and monitor the activity of LLM extensions and downstream systems to identify
   undesirable actions.
10. Implement rate-limiting to reduce the number of undesirable actions within a given time
    period.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
