---
title: 'LLM10: Unbounded Consumption'
description: OWASP LLM Top 10 reference for unbounded consumption vulnerabilities enabling denial-of-service and resource exhaustion attacks
---

# 10 Unbounded Consumption

Identifier: LLM10:2025
Category: Resource Management

## Description

Unbounded Consumption refers to the process where an LLM generates outputs based on input
queries or prompts. Inference is a critical function of LLMs, involving the application of
learned patterns and knowledge to produce relevant responses or predictions.

Attacks designed to disrupt service, deplete financial resources, or steal intellectual
property by cloning a model's behavior all depend on a common class of security
vulnerability. Unbounded Consumption occurs when an LLM application allows users to conduct
excessive and uncontrolled inferences, leading to risks such as denial of service (DoS),
economic losses, model theft, and service degradation.

The high computational demands of LLMs, especially in cloud environments, make them
vulnerable to resource exploitation and unauthorized usage.

## Common examples

1. Attackers overload the LLM with numerous inputs of varying lengths, exploiting processing
   inefficiencies and depleting resources.
2. Attackers exploit the cost-per-use model of cloud-based AI services by initiating high
   volumes of operations, leading to unsustainable financial burdens (Denial of Wallet).
3. Continuously sending inputs that exceed the LLM's context window leads to excessive
   computational resource use.
4. Submitting unusually demanding queries involving complex sequences or intricate language
   patterns drains system resources.
5. Attackers query the model API with crafted inputs and prompt injection techniques to
   collect sufficient outputs to replicate a partial or shadow model.
6. Attackers use the target model to generate synthetic training data to fine-tune another
   foundational model, creating a functional equivalent.
7. Attackers exploit input filtering techniques to execute side-channel attacks, harvesting
   model weights and architectural information.

## Attack scenarios

### Scenario A — Uncontrolled input size

An attacker submits an unusually large input to an LLM application that processes text data,
resulting in excessive memory usage and CPU load, potentially crashing the system.

### Scenario B — Denial of wallet

An attacker generates excessive operations to exploit the pay-per-use model of cloud-based
AI services, causing unsustainable costs for the service provider.

### Scenario C — Functional model replication

An attacker uses the LLM's API to generate synthetic training data and fine-tunes another
model, creating a functional equivalent and bypassing traditional model extraction
limitations.

### Scenario D — Side-channel model extraction

A malicious attacker bypasses input filtering techniques of the LLM to perform a
side-channel attack and retrieve model information to a remote controlled resource.

## Prevention and mitigation

1. Implement strict input validation to ensure inputs do not exceed reasonable size limits.
2. Restrict or obfuscate exposure of logit_bias and logprobs in API responses.
3. Apply rate limiting and user quotas to restrict requests a single source can make in a
   given time period.
4. Monitor and manage resource allocation dynamically to prevent any single user or request
   from consuming excessive resources.
5. Set timeouts and throttle processing for resource-intensive operations.
6. Restrict the LLM's access to network resources, internal services, and APIs using
   sandboxing techniques.
7. Continuously monitor resource usage and implement logging to detect unusual consumption
   patterns.
8. Implement watermarking frameworks to embed and detect unauthorized use of LLM outputs.
9. Design the system to degrade gracefully under heavy load, maintaining partial
   functionality rather than complete failure.
10. Implement restrictions on queued actions and total actions with dynamic scaling and load
    balancing.
11. Train models to detect and mitigate adversarial queries and extraction attempts.
12. Build lists of known glitch tokens and scan output before adding to the context window.
13. Implement strong access controls including RBAC and least privilege for LLM model
    repositories and training environments.
14. Use a centralized ML model inventory or registry for production models with proper
    governance and access control.
15. Implement automated MLOps deployment with governance, tracking, and approval workflows.

## References

* [CWE-400: Uncontrolled Resource Consumption](https://cwe.mitre.org/data/definitions/400.html) — MITRE CWE
* [AML.T0024 - Exfiltration via ML Inference API](https://atlas.mitre.org/tactics/AML.TA0000) — MITRE ATLAS
* [AML.T0029 - Denial of ML Service](https://atlas.mitre.org/techniques/AML.T0029) — MITRE ATLAS
* [AML.T0034 - Cost Harvesting](https://atlas.mitre.org/techniques/AML.T0034) — MITRE ATLAS
* [AML.T0025 - Exfiltration via Cyber Means](https://atlas.mitre.org/techniques/AML.T0025) — MITRE ATLAS
* [API4:2023 - Unrestricted Resource Consumption](https://owasp.org/API-Security/editions/2023/en/0xa4-unrestricted-resource-consumption/) — OWASP API Security

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
