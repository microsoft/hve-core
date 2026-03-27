---
title: 'ML10: Model Poisoning'
description: OWASP ML Top 10 reference for model poisoning vulnerabilities including direct manipulation of model weights, biases, and architecture
---

# 10 Model Poisoning

Identifier: ML10:2023
Category: Model Integrity

## Description

Model poisoning attacks occur when an attacker manipulates the model's parameters to cause it to
behave in an undesirable way. Unlike data poisoning which targets training data, model poisoning
directly modifies the model's weights, biases, or architecture. The attacker may alter parameters
to reprogram the model's behavior, such as causing it to misidentify specific inputs. This is
possible when the attacker gains access to the model's code, parameters, or storage through
insufficient access controls, insecure coding practices, or insider threats. Malicious individuals
or organizations with knowledge and resources to manipulate deep learning models can execute this
attack.

## Risk

- The model's predictions can be manipulated to achieve attacker-desired results.
- Confidential information within the model can be extracted.
- Decisions based on the model's predictions can be negatively impacted.
- Reputation and credibility of the organization can be affected.
- Insufficient access controls to the model's code and parameters increase susceptibility.
- Inadequate monitoring and logging of model activity allows the attack to go undetected.

## Vulnerability checklist

- Access controls to the model's code and parameters are insufficient.
- Secure coding practices are not followed in model development and deployment.
- Monitoring and logging of the model's activity is inadequate.
- No cryptographic techniques are used to secure the model's parameters and weights.
- Regularization techniques such as L1 or L2 are not applied to reduce overfitting and poisoning
  susceptibility.
- Model architectures do not incorporate robust design against parameter manipulation.
- No integrity checks are performed on model parameters before deployment.
- Model storage and versioning systems lack access controls and audit trails.

## Prevention controls

1. Add regularization techniques such as L1 or L2 regularization to the loss function to prevent
   overfitting and reduce the chance of model poisoning attacks.
2. Design models with robust architectures and activation functions to reduce the chances of
   successful model poisoning attacks.
3. Use cryptographic techniques to secure the parameters and weights of the model and prevent
   unauthorized access or manipulation.
4. Implement strict access controls on model code, parameters, and storage systems.
5. Follow secure coding practices in model development and deployment.
6. Enable comprehensive monitoring and logging of all model activity.
7. Perform integrity checks on model parameters before deployment to detect unauthorized
   modifications.

## Example attack scenarios

### Scenario A — Financial gain through model poisoning
A bank uses a machine learning model to identify handwritten characters on cheques to automate
their clearing process. The model has been trained on a large dataset of handwritten characters
and accurately identifies them based on parameters such as size, shape, slant, and spacing. An
attacker manipulates the model's parameters by altering images in the training dataset or directly
modifying the parameters. This results in the model being reprogrammed to identify characters
differently — for example, identifying the character "5" as "2", leading to incorrect amounts
being processed. The attacker exploits this by introducing forged cheques which the model
processes as valid due to the manipulated parameters, resulting in significant financial loss to
the bank.

## Detection guidance

- Perform integrity checks on model parameters by comparing checksums or hashes against known
  good baselines before each deployment.
- Monitor model predictions for unexpected behavior changes or accuracy degradation.
- Audit access logs for model code, parameter files, and storage systems for unauthorized access.
- Compare model weights across versions to detect unauthorized modifications.
- Track model performance metrics in production for sudden shifts that may indicate parameter
  tampering.

## Remediation

- Restore model parameters from verified, clean backups and redeploy.
- Implement cryptographic signing and integrity verification for all model parameter files.
- Enforce strict access controls on model code, parameters, and storage with multi-factor
  authentication.
- Enable comprehensive audit logging on all model storage and versioning systems.
- Apply regularization to reduce the model's sensitivity to parameter manipulation.
- Conduct a forensic review of parameter changes to identify the scope and method of the attack.
- Retrain the model from clean data if parameter integrity cannot be verified.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
