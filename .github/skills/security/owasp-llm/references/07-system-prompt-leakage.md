---
title: 'LLM07: System Prompt Leakage'
description: OWASP LLM Top 10 reference for system prompt leakage risks exposing sensitive configuration and behavioral instructions
---

# 07 System Prompt Leakage

Identifier: LLM07:2025
Category: Configuration Security

## Description

The system prompt leakage vulnerability refers to the risk that the system prompts or
instructions used to steer the model's behavior can contain sensitive information not
intended to be discovered. System prompts are designed to guide the model's output based
on the requirements of the application, but may inadvertently contain secrets. When
discovered, this information can be used to facilitate other attacks.

The system prompt should not be considered a secret, nor should it be used as a security
control. Sensitive data such as credentials, connection strings, and similar must not be
contained within the system prompt.

The fundamental security risk is not the disclosure of the prompt wording itself. The risk
lies in the underlying elements: sensitive information disclosure, system guardrails bypass,
and improper separation of privileges. Even if exact wording is not disclosed, attackers
interacting with the system can determine many guardrails and formatting restrictions by
observing the model's behavior.

## Risk

* Exposure of sensitive system architecture, API keys, database credentials, or user tokens
  enabling unauthorized access.
* Disclosure of internal decision-making processes allowing attackers to exploit weaknesses
  or bypass controls such as transaction limits or loan amounts.
* Revelation of content filtering criteria enabling attackers to craft targeted bypass
  attempts.
* Disclosure of internal role structures or permission levels enabling privilege escalation
  attacks.
* Facilitation of further attacks such as remote code execution through extracted guardrail
  bypass information.

## Vulnerability checklist

* System prompt contains sensitive information such as API keys, database credentials,
  connection strings, or user tokens.
* System prompt reveals internal decision-making processes or business logic that should be
  kept confidential.
* System prompt contains content filtering criteria that could be extracted and exploited by
  attackers.
* System prompt reveals role structures or permission levels of the application.
* Security controls such as privilege separation and authorization checks depend on system
  prompt instructions rather than deterministic external enforcement.
* Behavior control relies on system prompt instructions rather than independent guardrail
  systems outside the LLM.

## Prevention controls

1. Separate sensitive data from system prompts by externalizing API keys, authentication
   keys, database names, user roles, and permission structures to systems the model does not
   directly access.
2. Avoid reliance on system prompts for strict behavior control. Since LLMs are susceptible
   to prompt injection which can alter the system prompt, rely on systems outside the LLM to
   ensure behavior control, such as external systems for detecting and preventing harmful
   content.
3. Implement a system of guardrails outside of the LLM itself. An independent system that
   inspects output to determine compliance is preferable to system prompt instructions.
4. Ensure security controls are enforced independently from the LLM. Critical controls such
   as privilege separation, authorization bounds checks, and similar must not be delegated to
   the LLM. These controls need to occur in a deterministic, auditable manner. In cases where
   an agent is performing tasks requiring different access levels, use multiple agents each
   configured with least privileges.

## Example attack scenarios

### Scenario A — Credential extraction

An LLM has a system prompt containing credentials for a tool it has been given access to.
The system prompt is leaked to an attacker, who then uses these credentials for other
purposes.

### Scenario B — Guardrail bypass

An LLM has a system prompt prohibiting the generation of offensive content, external links,
and code execution. An attacker extracts this system prompt and then uses a prompt injection
attack to bypass these instructions, facilitating a remote code execution attack.

## Detection guidance

* Test whether system prompt content can be extracted through direct queries or prompt
  injection techniques designed to elicit system instructions.
* Review system prompts for embedded sensitive data such as credentials, API keys, or
  connection strings.
* Observe model behavior patterns to determine if guardrails and formatting restrictions
  can be inferred without direct prompt disclosure.
* Inspect LLM outputs for inadvertent disclosure of system prompt content or internal
  decision-making logic.
* Audit whether security controls depend on system prompt instructions rather than
  independent external enforcement.

## Remediation

* Remove all sensitive data from system prompts, externalizing API keys, authentication
  credentials, database names, and permission structures to systems the model does not
  directly access.
* Implement independent guardrail systems outside the LLM that inspect output for compliance
  rather than relying on system prompt instructions.
* Enforce security controls such as privilege separation and authorization bounds checks
  independently from the LLM in deterministic, auditable systems.
* Use multiple agents with least privileges when tasks require different access levels rather
  than embedding role information in system prompts.
* Rotate any credentials or API keys that were previously embedded in system prompts.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
