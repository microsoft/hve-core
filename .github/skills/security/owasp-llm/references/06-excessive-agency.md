---
title: 'LLM06: Excessive Agency'
description: OWASP LLM Top 10 reference for excessive agency vulnerabilities where LLM systems perform unintended actions with excessive permissions
---

# 06 Excessive Agency

Identifier: LLM06:2025
Category: Access Control

## Description

An LLM-based system is often granted a degree of agency by its developer — the ability to
call functions or interface with other systems via extensions (tools, skills, or plugins) to
undertake actions in response to a prompt. The decision over which extension to invoke may
also be delegated to an LLM agent to dynamically determine based on input prompt or LLM
output. Agent-based systems will typically make repeated calls to an LLM using output from
previous invocations to ground and direct subsequent invocations.

Excessive Agency is the vulnerability that enables damaging actions to be performed in
response to unexpected, ambiguous, or manipulated outputs from an LLM, regardless of what is
causing the LLM to malfunction. Common triggers include hallucination caused by poorly
engineered prompts or a poorly performing model, direct or indirect prompt injection from a
malicious user, or a malicious or compromised extension or peer agent.

The root cause is typically one or more of: excessive functionality, excessive permissions,
or excessive autonomy. Excessive Agency can lead to a broad range of impacts across the
confidentiality, integrity, and availability spectrum, depending on which systems an
LLM-based application is able to interact with.

## Risk

* Unauthorized data access through extensions with excessive read capabilities.
* Data exfiltration via extensions with unnecessary send or write capabilities.
* Modification or deletion of data through excessive permissions on downstream systems.
* Privilege escalation through extensions accessing systems with generic high-privileged
  identities.
* Unintended destructive actions performed without user confirmation or approval.
* Lateral movement across accounts through extensions operating outside the intended user's
  security context.

## Vulnerability checklist

* LLM agents have access to extensions with functions not needed for the intended system
  operation.
* Development-era extensions remain available to the LLM agent after being replaced by
  better alternatives.
* Extensions with open-ended functionality such as shell command execution or URL fetching
  fail to properly filter input instructions.
* Extensions have permissions on downstream systems beyond what is needed for the intended
  operation, such as UPDATE, INSERT, and DELETE when only SELECT is required.
* Extensions access downstream systems with generic high-privileged identities instead of
  executing in the user's security context.
* High-impact actions such as deletions are performed without independent verification or
  user approval.
* Authorization decisions are delegated to the LLM rather than enforced in downstream
  systems.

## Prevention controls

1. Limit the extensions that LLM agents are allowed to call to the minimum necessary for
   intended operation.
2. Limit the functions implemented in LLM extensions to the minimum necessary. Avoid
   extensions that include capabilities beyond their intended purpose.
3. Avoid open-ended extensions such as shell command execution or URL fetching and use
   extensions with more granular, purpose-specific functionality.
4. Limit the permissions that LLM extensions are granted to other systems to the minimum
   necessary. Enforce appropriate database permissions for the identity that the LLM
   extension uses to connect.
5. Execute extensions in the user's context, tracking user authorization and security scope
   to ensure actions use minimum privileges. Require user authentication via OAuth with the
   minimum scope required.
6. Require human approval for high-impact actions via human-in-the-loop control before they
   are taken.
7. Implement authorization in downstream systems rather than relying on the LLM to decide if
   an action is allowed. Enforce the complete mediation principle so all requests made to
   downstream systems via extensions are validated against security policies.
8. Follow secure coding best practices such as applying OWASP ASVS recommendations with
   strong focus on input sanitization. Use SAST, DAST, and IAST in development pipelines.

## Example attack scenarios

### Scenario A — Email exfiltration via excessive extension

An LLM-based personal assistant is granted mailbox access via an extension in order to
summarize incoming emails. The extension includes functions for sending messages beyond the
needed read capability. A maliciously-crafted incoming email tricks the LLM into scanning
the inbox for sensitive information and forwarding it to the attacker's email address. This
could be avoided by using an extension that only implements mail-reading capabilities,
authenticating via an OAuth session with a read-only scope, and requiring the user to
manually review and approve every mail send action.

## Detection guidance

* Audit all LLM extensions for unnecessary functions and permissions beyond their intended
  purpose.
* Review downstream system permissions granted to extension identities for excessive access
  levels.
* Monitor and log LLM extension activity and downstream system interactions for undesirable
  or unauthorized actions.
* Test whether high-impact actions can be triggered without human approval or user
  confirmation.
* Verify that extensions execute in the specific user's security context with minimum
  privileges rather than using generic high-privileged identities.

## Remediation

* Remove unnecessary extensions and functions from LLM agent configurations.
* Restrict extension permissions to the minimum necessary on all downstream systems.
* Replace open-ended extensions with more granular, purpose-specific alternatives.
* Implement human-in-the-loop control for all high-impact actions.
* Enforce authorization in downstream systems rather than relying on LLM decisions.
* Add rate-limiting on extension actions to reduce the impact of undesirable operations and
  increase the opportunity for detection.
* Log and monitor the activity of all LLM extensions and downstream systems to identify and
  respond to undesirable actions.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
