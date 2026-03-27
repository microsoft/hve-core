---
title: 'ML03: Model Inversion Attack'
description: OWASP ML Top 10 reference for model inversion vulnerabilities including reverse-engineering of sensitive training data from model outputs
---

# 03 Model Inversion Attack

Identifier: ML03:2023
Category: Privacy

## Description

Model inversion attacks occur when an attacker reverse-engineers the model to extract information
from it. By submitting carefully crafted inputs and analyzing the model's outputs, the attacker
reconstructs sensitive information about the training data or individual records used to train the
model. The attack exploits the fact that model predictions leak information about the underlying
data distribution. This is particularly dangerous for models trained on sensitive data such as
personal information, medical records, or biometric data.

## Risk

- Confidential information about the input data can be compromised through model output analysis.
- The attack has moderate exploitability and is difficult to detect.
- Attackers who have access to the model and input data can submit queries and analyze responses.
- The model's output can be used to infer sensitive information about individuals in the training
  data.
- Privacy violations and regulatory non-compliance may result from successful extraction of
  personal data.

## Vulnerability checklist

- The model is accessible without authentication or access control restrictions.
- Model predictions are returned with full precision without rounding or noise addition.
- No input validation is performed to detect systematic probing queries.
- The model lacks transparency mechanisms to log and audit all inputs and outputs.
- No monitoring is in place to detect anomalous query patterns.
- The model is not regularly retrained to limit the relevance of leaked information.
- Differential privacy techniques are not applied during training.

## Prevention controls

1. Limit access to the model and its predictions by requiring authentication, encryption, or
   other security measures.
2. Validate inputs to the model to prevent attackers from providing malicious data used to invert
   the model by checking format, range, and consistency before processing.
3. Make the model and its predictions transparent by logging all inputs and outputs, providing
   explanations for predictions, or allowing inspection of internal representations.
4. Monitor the model's predictions for anomalies by tracking input and output distributions,
   comparing predictions to ground truth data, or monitoring performance over time.
5. Regularly retrain the model to help prevent information leaked by model inversion attacks from
   remaining current.
6. Apply differential privacy during training to limit the amount of information any single
   record contributes to model parameters.

## Example attack scenarios

### Scenario A — Stealing personal information from a face recognition model
An attacker trains a deep learning model to perform face recognition and uses it to perform a
model inversion attack on a different face recognition model used by a company. The attacker
inputs images of individuals into the target model and recovers personal information from the
model's predictions, such as name, address, or social security number. The attacker exploits a
vulnerability in the model's implementation or accesses the model through an API.

### Scenario B — Bypassing a bot detection model in online advertising
An advertiser trains a deep learning bot detection model and uses it to invert the predictions of
a bot detection model used by an online advertising platform. The advertiser inputs bots into the
model and makes them appear as human users, allowing the bots to bypass detection and
successfully execute automated advertising campaigns. The advertiser accesses the platform's model
through a vulnerability or API.

## Detection guidance

- Monitor API query patterns for systematic probing such as repeated similar queries with small
  variations.
- Track the volume and frequency of model queries per user or API key.
- Log all inputs and outputs to detect reconstruction attempts.
- Compare query distributions against expected usage patterns to identify anomalous behavior.
- Implement rate limiting and query budget controls on model prediction endpoints.

## Remediation

- Restrict model API access to authenticated and authorized users only.
- Add noise or rounding to model outputs to reduce the precision of leaked information.
- Implement query rate limiting and anomaly detection on prediction endpoints.
- Apply differential privacy techniques during model training.
- Retrain the model periodically to reduce the relevance of previously leaked information.
- Audit access logs for evidence of systematic model probing.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
