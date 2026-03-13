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

## Common examples

1. The system prompt reveals sensitive information such as system architecture, API keys,
   database credentials, or user tokens that can be extracted by attackers.
2. The system prompt reveals internal decision-making processes, allowing attackers to
   exploit weaknesses or bypass controls, such as transaction limits or loan amounts.
3. A system prompt asks the model to filter or reject sensitive content, revealing the
   filtering criteria to potential attackers.
4. The system prompt reveals internal role structures or permission levels, enabling
   privilege escalation attacks.

## Attack scenarios

### Scenario A — Credential extraction

An LLM has a system prompt containing credentials for a tool it has been given access to.
The system prompt is leaked to an attacker, who then uses these credentials for other
purposes.

### Scenario B — Guardrail bypass

An LLM has a system prompt prohibiting the generation of offensive content, external links,
and code execution. An attacker extracts this system prompt and then uses a prompt injection
attack to bypass these instructions, facilitating a remote code execution attack.

## Prevention and mitigation

1. Separate sensitive data from system prompts by externalizing API keys, auth keys, database
   names, user roles, and permission structures to systems the model does not directly access.
2. Avoid reliance on system prompts for strict behavior control. Rely on systems outside the
   LLM to enforce behavior, such as external systems for detecting and preventing harmful
   content.
3. Implement a system of guardrails outside of the LLM itself. An independent system that
   inspects output to determine compliance is preferable to system prompt instructions.
4. Ensure security controls are enforced independently from the LLM. Critical controls such
   as privilege separation and authorization bounds checks must not be delegated to the LLM.
   Use multiple agents with least privileges when tasks require different access levels.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
