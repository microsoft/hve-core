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
economic losses, model theft, and service degradation. The high computational demands of
LLMs, especially in cloud environments, make them vulnerable to resource exploitation and
unauthorized usage.

## Risk

* Denial of service through excessive computational resource consumption rendering the
  system unresponsive.
* Economic losses through exploitation of pay-per-use cloud pricing models leading to
  unsustainable financial burdens (Denial of Wallet).
* Model theft through functional replication via carefully crafted API queries and synthetic
  training data generation.
* Service degradation from continuous input overflow exceeding the LLM's context window.
* Intellectual property theft through side-channel attacks harvesting model weights and
  architectural information.
* System failure from resource-intensive adversarial queries involving complex sequences or
  intricate language patterns.

## Vulnerability checklist

* No input validation restricts the size or complexity of inputs submitted to the LLM.
* Logit bias and logprobs are exposed in API responses without restriction or obfuscation.
* No rate limiting or user quotas restrict the number of requests from a single source.
* Resource allocation is not monitored or managed dynamically per user or request.
* No timeouts or throttling exist for resource-intensive operations.
* The LLM has unrestricted access to network resources, internal services, and APIs.
* No watermarking framework exists to detect unauthorized use of LLM outputs.
* The system lacks graceful degradation capabilities under heavy load.
* No access controls restrict access to LLM model repositories and training environments.
* No centralized ML model inventory or registry exists for production models.

## Prevention controls

1. Implement strict input validation to ensure inputs do not exceed reasonable size limits.
2. Restrict or obfuscate the exposure of logit_bias and logprobs in API responses. Provide
   only the necessary information without revealing detailed probabilities.
3. Apply rate limiting and user quotas to restrict the number of requests a single source
   entity can make in a given time period.
4. Monitor and manage resource allocation dynamically to prevent any single user or request
   from consuming excessive resources.
5. Set timeouts and throttle processing for resource-intensive operations to prevent prolonged
   resource consumption.
6. Restrict the LLM's access to network resources, internal services, and APIs using
   sandboxing techniques.
7. Continuously monitor resource usage and implement logging to detect and respond to unusual
   patterns of resource consumption.
8. Implement watermarking frameworks to embed and detect unauthorized use of LLM outputs.
9. Design the system to degrade gracefully under heavy load, maintaining partial functionality
   rather than complete failure.
10. Implement restrictions on the number of queued actions and total actions with dynamic
    scaling and load balancing to handle varying demands.
11. Train models to detect and mitigate adversarial queries and extraction attempts.
12. Build lists of known glitch tokens and scan output before adding it to the model's
    context window.
13. Implement strong access controls including role-based access control (RBAC) and the
    principle of least privilege for LLM model repositories and training environments.
14. Use a centralized ML model inventory or registry for models used in production, ensuring
    proper governance and access control.
15. Implement automated MLOps deployment with governance, tracking, and approval workflows
    to tighten access and deployment controls within the infrastructure.

## Example attack scenarios

### Scenario A — Uncontrolled input size

An attacker submits an unusually large input to an LLM application that processes text data,
resulting in excessive memory usage and CPU load, potentially crashing the system or
significantly slowing down the service.

### Scenario B — Denial of wallet

An attacker generates excessive operations to exploit the pay-per-use model of cloud-based
AI services, causing unsustainable costs for the service provider.

### Scenario C — Functional model replication

An attacker uses the LLM's API to generate synthetic training data and fine-tunes another
model, creating a functional equivalent and bypassing traditional model extraction
limitations.

### Scenario D — Side-channel model extraction

A malicious attacker bypasses input filtering techniques of the LLM to perform a
side-channel attack, retrieving model information to a remote controlled resource under
their control.

### Scenario E — Resource-intensive adversarial queries

An attacker crafts specific inputs designed to trigger the LLM's most computationally
expensive processes, leading to prolonged CPU usage and potential system failure.

### Scenario F — Repeated request flood

An attacker transmits a high volume of requests to the LLM API, causing excessive
consumption of computational resources and making the service unavailable to legitimate
users.

## Detection guidance

* Monitor resource usage continuously for unusual consumption patterns that may indicate
  denial of service or wallet attacks.
* Implement logging to detect abnormal request volumes or sizes from single sources.
* Analyze API access patterns for indicators of model extraction or replication attempts
  such as systematic querying with varied inputs.
* Track costs against usage baselines to identify Denial of Wallet attacks early.
* Monitor for adversarial queries designed to trigger computationally expensive processing.
* Detect known glitch tokens in inputs before they are processed by the LLM.

## Remediation

* Implement strict input validation with size limits on all inputs to the LLM.
* Restrict or obfuscate exposure of logit_bias and logprobs in API responses.
* Apply rate limiting and user quotas across all API endpoints.
* Set timeouts and throttle processing for resource-intensive operations.
* Restrict LLM access to network resources and APIs using sandboxing techniques.
* Deploy watermarking frameworks to detect unauthorized use of LLM outputs.
* Implement strong access controls with RBAC and least privilege for model repositories
  and training environments.
* Design the system to degrade gracefully under heavy load, maintaining partial
  functionality.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
