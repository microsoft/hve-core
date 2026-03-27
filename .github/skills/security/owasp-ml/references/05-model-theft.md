---
title: 'ML05: Model Theft'
description: OWASP ML Top 10 reference for model theft vulnerabilities including parameter extraction, architecture replication, and intellectual property loss
---

# 05 Model Theft

Identifier: ML05:2023
Category: Intellectual Property

## Description

Model theft attacks occur when an attacker gains access to the model's parameters, architecture,
or training data and replicates the model for unauthorized use. The attacker may reverse-engineer
the model by disassembling binary code, accessing the model's training data and algorithm, or
querying the model API extensively to reconstruct a functionally equivalent copy. This results in
loss of intellectual property, competitive advantage, and potential financial harm to the
organization that developed the model.

## Risk

- Loss of confidentiality of the data used to train the model.
- Financial loss and damage to competitive advantage from unauthorized replication of the model.
- Reputational harm to the organization that developed the model.
- Unsecured model deployment makes it easier for the attacker to access and steal the model.
- Stolen models may be used to discover vulnerabilities or craft adversarial attacks against the
  original system.

## Vulnerability checklist

- The model's code, parameters, and training data are not encrypted.
- Strict access control measures such as two-factor authentication are not implemented.
- Regular backups of the model's code and training data are not maintained.
- The model's code is not obfuscated and is easy to reverse engineer.
- No watermarking is applied to the model to enable theft tracing.
- No legal protections such as patents or trade secrets are in place.
- Monitoring and auditing of model access and usage is insufficient.
- Model API endpoints do not enforce rate limiting or query budgets.

## Prevention controls

1. Encrypt the model's code, training data, and other sensitive information to prevent
   unauthorized access.
2. Implement strict access control measures including two-factor authentication to prevent
   unauthorized individuals from accessing the model.
3. Regularly back up the model's code, training data, and sensitive information to ensure
   recovery in the event of theft.
4. Obfuscate the model's code to make it difficult to reverse engineer.
5. Add watermarks to the model's code and training data to trace the source of a theft and hold
   attackers accountable.
6. Secure legal protections such as patents or trade secrets to make theft more difficult and
   provide a basis for legal action.
7. Regularly monitor and audit model use to detect when an attacker is attempting to access or
   steal the model.
8. Enforce rate limiting and query budgets on model API endpoints to prevent model extraction
   through extensive querying.

## Example attack scenarios

### Scenario A — Stealing a machine learning model from a competitor
A malicious attacker working for a competitor of a company that has developed a valuable machine
learning model wants to steal the model for competitive advantage. The attacker reverse-engineers
the company's model by disassembling the binary code or accessing the model's training data and
algorithm. Once the attacker has reverse-engineered the model, they recreate it and use it for
their own purposes, resulting in significant financial loss and reputational damage to the
original company.

## Detection guidance

- Monitor API query patterns for model extraction attempts characterized by high-volume
  systematic queries across the input space.
- Track model download and access events for unauthorized access.
- Implement canary records or watermarks that can be detected when a stolen model is deployed.
- Audit access logs for unusual access patterns to model artifacts, code, or training data.
- Monitor for the appearance of functionally equivalent models from competitors or public sources.

## Remediation

- Encrypt all model artifacts, parameters, and training data at rest and in transit.
- Enforce multi-factor authentication for access to model code and deployment infrastructure.
- Deploy watermarking in the model to enable detection and attribution of stolen copies.
- Apply rate limiting on prediction APIs to prevent extraction through extensive querying.
- Obfuscate model code and deployment artifacts.
- Secure legal protections for the model and pursue legal action if theft is detected.
- Review and tighten access controls on model storage, versioning, and deployment systems.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
