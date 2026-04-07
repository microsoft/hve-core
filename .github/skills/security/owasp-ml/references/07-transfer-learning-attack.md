---
title: 'ML07: Transfer Learning Attack'
description: OWASP ML Top 10 reference for transfer learning vulnerabilities including malicious knowledge injection via compromised pre-trained models and fine-tuning datasets
---

# 07 Transfer Learning Attack

Identifier: ML07:2023
Category: Model Integrity

## Description

Transfer learning attacks occur when an attacker trains a model on one task and then fine-tunes it
on another task to cause it to behave in an undesirable way. The attacker exploits the transfer of
knowledge between models by injecting malicious knowledge into a pre-trained model or compromising
the training dataset used for fine-tuning. Because transfer learning relies on re-using previously
learned representations, a compromised pre-trained model or dataset can propagate malicious
behavior into any downstream model that builds upon it. The results produced by the compromised
model may appear correct and consistent with expectations, making the attack difficult to detect.

## Risk

* Misleading or incorrect results from the machine learning model.
* Confidentiality breach of sensitive information in the training dataset.
* Reputational harm to the organization.
* Legal or regulatory compliance issues.
* The attack requires a high level of technical expertise in machine learning and a willingness to
  compromise the integrity of the training dataset or pre-trained models.
* The attack may be difficult to detect as compromised model outputs may appear correct.

## Vulnerability checklist

* Pre-trained models are obtained from untrusted or unverified sources.
* Training datasets used for fine-tuning are not validated for integrity or provenance.
* Pre-trained models are stored and shared without secure access controls.
* No data protection measures are applied to pre-trained models or training datasets.
* Training and deployment environments are not isolated from each other.
* Differential privacy is not used to protect individual records in the training dataset.
* Regular security audits of the ML pipeline are not performed.
* No monitoring is in place to detect deviations in fine-tuned model behavior.

## Prevention controls

1. Regularly monitor and update training datasets to prevent the transfer of malicious knowledge
   from an attacker's model to the target model.
2. Use only secure and trusted training datasets and pre-trained models from verified sources.
3. Implement model isolation by separating training and deployment environments to prevent
   attackers from transferring knowledge across environments.
4. Use differential privacy to protect the privacy of individual records in the training dataset
   and prevent transfer of malicious knowledge.
5. Perform regular security audits to identify and prevent transfer learning attacks by addressing
   vulnerabilities in the system.
6. Validate fine-tuned model behavior against known baselines before deployment.

## Example attack scenarios

### Scenario A — Training a model on a malicious dataset for face recognition bypass

An attacker trains a machine learning model on a malicious dataset containing manipulated images
of faces. The attacker targets a face recognition system used by a security firm for identity
verification. The attacker transfers the model's knowledge to the target face recognition system.
The target system starts using the attacker's manipulated model for identity verification. As a
result, the face recognition system makes incorrect predictions, allowing the attacker to bypass
security and gain access to sensitive information. The attacker uses a manipulated image of
themselves and the system identifies them as a legitimate user.

## Detection guidance

* Compare fine-tuned model behavior against baseline metrics established before transfer learning
  was applied.
* Monitor model predictions for unexpected deviations or accuracy drops after fine-tuning.
* Audit the provenance and integrity of all pre-trained models used in the pipeline.
* Test the fine-tuned model with known adversarial inputs to detect transferred malicious behavior.
* Review access logs to pre-trained model storage for unauthorized modifications.

## Remediation

* Replace compromised pre-trained models with verified, trusted versions and retrain.
* Validate all training datasets used for fine-tuning for integrity and provenance.
* Isolate training and deployment environments to prevent cross-contamination.
* Apply differential privacy during fine-tuning to limit per-record influence.
* Conduct security audits of the ML pipeline to identify and close vulnerabilities.
* Implement continuous monitoring of fine-tuned model behavior in production.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
