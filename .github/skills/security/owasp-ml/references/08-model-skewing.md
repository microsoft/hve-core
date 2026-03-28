---
title: 'ML08: Model Skewing'
description: OWASP ML Top 10 reference for model skewing vulnerabilities including feedback loop manipulation and training data distribution attacks
---

# 08 Model Skewing

Identifier: ML08:2023
Category: Data Integrity

## Description

Model skewing attacks occur when an attacker manipulates the distribution of the training data to
cause the model to behave in an undesirable way. The attacker targets feedback loops in MLOps
systems by providing fake feedback data that is used to update the model's training data. This
causes the model's predictions to become skewed toward outcomes desired by the attacker. The
skewing may not be easily noticeable during the testing phase and manipulation of the training
data distribution is a technically complex task requiring knowledge of the machine learning
process.

## Risk

* Incorrect decisions being made based on the output of the skewed model.
* Financial loss, damage to reputation, and potential harm to individuals if the model is used for
  critical applications such as medical diagnosis or criminal justice.
* The model's inability to accurately reflect the underlying distribution of the training data.
* Data bias, incorrect sampling, or deliberate manipulation of the data or training process by an
  attacker.
* Malicious actors or third parties with a vested interest in manipulating model outcomes can
  execute this attack.

## Vulnerability checklist

* Feedback loops in the MLOps system are not protected by access controls.
* Feedback data received by the system is not verified for authenticity using digital signatures
  or checksums.
* Feedback data is not validated or cleaned before being used to update training data.
* No anomaly detection is applied to feedback data to detect potential manipulation.
* The model's performance is not continuously monitored and compared against actual outcomes.
* The model is not regularly retrained using updated and verified training data.
* Activities in the MLOps system and feedback loops are not logged and audited.

## Prevention controls

1. Implement robust access controls ensuring only authorized personnel have access to the MLOps
   system and its feedback loops, and that all activities are logged and audited.
2. Verify the authenticity of feedback data using techniques such as digital signatures and
   checksums, and reject data that does not match the expected format.
3. Use data validation and cleaning techniques on feedback data before using it to update training
   data, to minimize the risk of incorrect or malicious data being used.
4. Implement anomaly detection using statistical and machine learning-based methods to detect and
   alert on anomalies in feedback data that could indicate an attack.
5. Continuously monitor the model's performance and compare predictions with actual outcomes to
   detect deviation or skewing.
6. Regularly retrain the model using updated and verified training data to ensure it reflects the
   latest information and trends.

## Example attack scenarios

### Scenario A — Financial gain through model skewing

A financial institution uses a machine learning model to predict the creditworthiness of loan
applicants, with the model's predictions integrated into the loan approval process. An attacker
wants to increase their chances of getting a loan approved and manipulates the feedback loop in
the MLOps system. The attacker provides fake feedback data indicating that high-risk applicants
have been approved for loans in the past. This feedback is used to update the model's training
data. As a result, the model's predictions become skewed toward low-risk classifications and the
attacker's chances of loan approval are significantly increased. This compromises the accuracy and
fairness of the model, leading to unintended consequences and potential harm to the financial
institution and its customers.

## Detection guidance

* Monitor feedback data ingestion pipelines for sudden distribution shifts or anomalous patterns.
* Compare model predictions against actual outcomes over time to detect drift or systematic bias.
* Track changes in training data distributions across retraining cycles.
* Audit access logs for the MLOps system and feedback loops for unauthorized activity.
* Implement statistical drift detection to flag when model outputs deviate from historical
  baselines.

## Remediation

* Remove identified malicious feedback data from the training dataset and retrain the model.
* Implement authentication and authorization on all feedback data submission channels.
* Deploy anomaly detection on feedback data pipelines to catch future manipulation attempts.
* Enforce digital signature verification on all feedback data before it enters the training loop.
* Continuously monitor model performance and compare against ground truth to detect skewing.
* Audit and tighten access controls on the MLOps system and feedback infrastructure.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
