---
title: 'LLM03: Supply Chain'
description: OWASP LLM Top 10 reference for supply chain vulnerabilities in LLM training data, models, and deployment platforms
author: Microsoft
ms.date: 2026-03-13
ms.topic: reference
keywords:
  - owasp
  - llm
  - supply-chain
  - security
estimated_reading_time: 5
---

# 03 Supply Chain

Identifier: LLM03:2025
Category: Supply Chain

## Description

LLM supply chains are susceptible to various vulnerabilities that can affect the integrity
of training data, ML models, deployment platforms, and operational workflows. These
vulnerabilities can result in biased outcomes, security breaches, or complete system failures.

AI extends traditional software supply chain risks with pre-trained models and training data
supplied by third parties that are susceptible to tampering and poisoning attacks. LLM plugin
extensions can also introduce their own vulnerabilities.

## Common examples

1. Outdated or deprecated components used without verification, including components running
   on top of the model's execution pathway that are not regularly checked for vulnerabilities.
2. Licensing risks from diverse licensing frameworks covering model weights, source code, and
   training data that may include web-scraped or copyrighted material.
3. Using outdated or deprecated models that are no longer maintained.
4. Vulnerable pre-trained models containing hidden biases, backdoors, or other malicious
   features not identified through safety evaluations.
5. Weak model provenance with no strong assurances that the model came from a trustworthy
   source.
6. Vulnerable LoRA adapters from untrusted sources introducing attack vectors into a
   pre-trained base model.
7. Exploiting collaborative development processes such as model merging and Mixture of
   Experts (MOE) processing using poisoned or out-of-date shared models.
8. On-device ML model supply chain risks from supplier compromise, insertion of malicious
   functionality through hardware or software attacks, and side-channel attacks.
9. Unclear terms and conditions and data privacy policies leading to sensitive data being
   used for model training.

## Attack scenarios

### Scenario A — Vulnerable library exploitation

An attacker exploits a vulnerable Python library to compromise an LLM application, leading
to unauthorized data access.

### Scenario B — Malicious LLM plugin

An attacker provides an LLM plugin for flight search that generates fake links leading to
scamming users.

### Scenario C — Poisoned pre-trained model

An attacker poisons a publicly available pre-trained model specializing in economic analysis
to create a backdoor that generates misinformation and deploys it on a model marketplace
for victims to use.

### Scenario D — Compromised LoRA adapter

An attacker exploits a vulnerable LoRA adapter hosted on a public model repository, uploaded
by a seemingly trusted contributor, to inject malicious behavior into any base model that
loads the adapter's weights.

### Scenario E — Model editing attack

An attacker uses a technique such as ROME (Rank-One Model Editing) to modify factual
associations in a base model, embedding triggers or persistent misinformation that is then
offered as a legitimate pre-trained model.

## Prevention and mitigation

1. Carefully vet data sources and suppliers, including terms and conditions and privacy
   policies, only using trusted suppliers.
2. Apply vulnerability scanning, management, and patching of components following OWASP
   A06:2021 guidance.
3. Apply comprehensive AI red teaming on supplied models to verify they have been evaluated
   and checked for vulnerabilities.
4. Maintain an up-to-date inventory of components using a Software Bill of Materials (SBOM)
   to ensure an accurate and signed inventory.
5. Use MLOps best practices and platforms offering secure model repositories with data,
   model, and experiment tracking.
6. Use model and code signing when using external models and suppliers.
7. Implement anomaly detection and adversarial robustness tests on supplied models and data.
8. Implement sufficient monitoring to cover component and environment vulnerabilities,
   unauthorized plugins, and out-of-date components.
9. Implement a patching policy to mitigate vulnerable or outdated components.

## References

* [AML.T0018 - Backdoor ML Model](https://atlas.mitre.org/techniques/AML.T0018) — MITRE ATLAS
* [NIST AI Risk Management Framework](https://www.nist.gov/itl/ai-risk-management-framework)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
