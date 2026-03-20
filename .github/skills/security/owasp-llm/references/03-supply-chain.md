---
title: 'LLM03: Supply Chain'
description: OWASP LLM Top 10 reference for supply chain vulnerabilities in LLM training data, models, and deployment platforms
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

## Risk

* Biased outcomes from poisoned or manipulated training data.
* Security breaches from compromised components, models, or plugins.
* Complete system failures from vulnerable dependencies in the model execution pathway.
* Intellectual property theft from model, code, or data exfiltration by compromised suppliers.
* Legal exposure from unclear licensing terms covering model weights, source code, and
  web-scraped or copyrighted training data.
* Malware distribution through compromised model artifacts such as malicious pickling.
* Backdoor introduction through poisoned LoRA adapters or model merging processes.
* Sensitive data exposure from unclear terms and conditions and data privacy policies.

## Vulnerability checklist

* Outdated or deprecated components are used without regular vulnerability checks, including
  components running on top of the model's execution pathway.
* Licensing risks from diverse frameworks covering model weights, source code, and training
  data are not properly evaluated.
* Outdated or deprecated models that are no longer maintained are in use.
* Pre-trained models are used without safety evaluations for hidden biases, backdoors, or
  other malicious features.
* No strong model provenance verification exists for external models and their associated
  artifacts.
* LoRA adapters from untrusted sources are bolted onto base models without verification.
* Shared model merging or Mixture of Experts processing uses unverified or poisoned community
  models.
* On-device ML models are sourced without verification of supplier integrity or hardware and
  software attack mitigations.
* Terms and conditions and data privacy policies of model operators are unclear or require
  explicit opt-out from data usage for training.

## Prevention controls

1. Carefully vet data sources and suppliers, including terms and conditions and privacy
   policies, only using trusted suppliers. Regularly review and audit supplier security and
   access.
2. Apply vulnerability scanning, management, and patching of components following OWASP
   A06:2021 guidance. For development environments with access to sensitive data, apply these
   controls in those environments as well.
3. Apply comprehensive AI red teaming on supplied models to verify they have been evaluated
   and checked for vulnerabilities.
4. Maintain an up-to-date inventory of components using a Software Bill of Materials (SBOM)
   to ensure an accurate and signed inventory, preventing tampering with deployed packages.
5. Use MLOps best practices and platforms offering secure model repositories with data, model,
   and experiment tracking to ensure supply chain integrity.
6. Use model and code signing when using external models and suppliers.
7. Implement anomaly detection and adversarial robustness tests on supplied models and data
   to detect tampering and poisoning.
8. Implement sufficient monitoring to cover component and environment vulnerabilities,
   unauthorized plugins, and out-of-date components, including the model and its artifacts.
9. Implement a patching policy to mitigate vulnerable or outdated components. Ensure that the
   application relies on a maintained version of APIs and the underlying model.

## Example attack scenarios

### Scenario A — Vulnerable library exploitation

An attacker exploits a vulnerable Python library to compromise an LLM application, leading
to unauthorized data access.

### Scenario B — Malicious LLM plugin

An attacker provides an LLM plugin for flight search that generates fake links leading to
scamming users.

### Scenario C — Poisoned pre-trained model

An attacker poisons a publicly available pre-trained model specializing in economic analysis
and social research to create a backdoor that generates misinformation. They deploy it on a
model marketplace for victims to use.

### Scenario D — Compromised LoRA adapter

An attacker exploits a vulnerable LoRA adapter hosted on a public model repository, uploaded
by a seemingly trusted contributor, to inject malicious behavior into any base model that
loads the adapter's weights.

### Scenario E — Model editing attack

An attacker uses a technique such as ROME (Rank-One Model Editing) to modify factual
associations in a base model, embedding triggers or persistent misinformation that is then
offered as a legitimate pre-trained model.

### Scenario F — Compromised supplier exfiltration

A compromised employee of a supplier such as an outsourcing developer or hosting company
exfiltrates data, model, or code, stealing intellectual property.

### Scenario G — Terms and conditions data exposure

An LLM operator changes its terms and conditions and privacy policy so that it requires an
explicit opt out from using application data for model training, which could lead to
memorization of sensitive data.

## Detection guidance

* Scan all components for known vulnerabilities using automated vulnerability scanning tools.
* Audit model provenance and verify signed artifacts and checksums for all external models.
* Monitor for unauthorized plugins and out-of-date components including the model and its
  artifacts.
* Review terms and conditions and privacy policies of all suppliers regularly for changes.
* Use anomaly detection and adversarial robustness tests on supplied models to detect
  tampering and poisoning.
* Inspect LoRA adapters and model merge contributions from community sources for malicious
  modifications.

## Remediation

* Replace all outdated or deprecated components and models with maintained, patched versions.
* Verify model provenance and apply code and model signing for all external artifacts.
* Update the Software Bill of Materials to include all current components with supply chain
  security analysis.
* Implement a patching policy for all vulnerable or outdated components.
* Apply AI red teaming to all supplied models to identify and remediate vulnerabilities.
* Renegotiate or discontinue use of suppliers with unclear terms and conditions or inadequate
  privacy policies.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
