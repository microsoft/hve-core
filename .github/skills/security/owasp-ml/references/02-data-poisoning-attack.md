---
title: 'ML02: Data Poisoning Attack'
description: OWASP ML Top 10 reference for data poisoning vulnerabilities including training data manipulation, label corruption, and pipeline compromise
---

# 02 Data Poisoning Attack

Identifier: ML02:2023
Category: Data Integrity

## Description

Data poisoning attacks occur when an attacker manipulates the training data to cause the model to
behave in an undesirable way. The attacker injects malicious data into the training dataset by
compromising the data storage system, exploiting vulnerabilities in data collection pipelines, or
corrupting the data labeling process. The poisoned data causes the model to learn incorrect
patterns, leading to unreliable predictions when deployed. This attack is particularly dangerous
because manipulated training data may be difficult to detect and can persist through multiple
retraining cycles.

## Risk

* The model will make incorrect predictions based on the poisoned data, leading to false decisions
  and potentially serious consequences.
* The attack has moderate exploitability and is difficult to detect.
* Attackers who have access to the training data or the data collection pipeline can execute the
  attack.
* Lack of data validation and insufficient monitoring of the training data increase exposure.
* Poisoned data may persist across retraining cycles if not identified and removed.

## Vulnerability checklist

* Training data is not thoroughly validated or verified before use.
* No data integrity checks such as checksums or digital signatures are applied to training
  datasets.
* Training data is stored without encryption or secure transfer protocols.
* Training data is not separated from production data.
* Access controls do not restrict who can access or modify the training data.
* No anomaly detection is applied to training data to detect sudden distribution changes or
  labeling inconsistencies.
* Multiple independent data labelers are not used to cross-validate labeling accuracy.
* No separate validation set is used to verify model behavior after training.

## Prevention controls

1. Ensure that training data is thoroughly validated and verified before use by implementing data
   validation checks and employing multiple data labelers to validate labeling accuracy.
2. Store training data securely using encryption, secure data transfer protocols, and firewalls.
3. Separate training data from production data to reduce the risk of training data compromise.
4. Implement access controls to limit who can access the training data and when.
5. Regularly monitor the training data for anomalies and conduct audits to detect data tampering.
6. Validate the model using a separate validation set that was not used during training to detect
   poisoning attacks that may have affected the training data.
7. Train multiple models using different subsets of the training data and use an ensemble to make
   predictions, reducing the impact of poisoning attacks.
8. Use anomaly detection techniques to detect abnormal behavior in the training data such as
   sudden changes in data distribution or data labeling.

## Example attack scenarios

### Scenario A — Poisoning a spam classifier

An attacker poisons the training data for a deep learning model that classifies emails as spam or
not spam. The attacker injects maliciously labeled spam emails into the training dataset by
compromising the data storage system, hacking into the network, or exploiting a vulnerability in
the data storage software. The attacker also manipulates the data labeling process by falsifying
labels or bribing data labelers to provide incorrect labels.

### Scenario B — Poisoning a network traffic classifier

An attacker poisons the training data for a deep learning model used to classify network traffic
into categories such as email, web browsing, and video streaming. The attacker introduces a large
number of examples of network traffic incorrectly labeled as a different type of traffic, causing
the model to make incorrect traffic classifications when deployed. This leads to misallocation of
network resources or degradation of network performance.

## Detection guidance

* Apply statistical analysis to training datasets to detect sudden distribution shifts or
  anomalous labeling patterns.
* Use holdout validation sets to compare model behavior against known-clean baselines.
* Monitor model accuracy over retraining cycles for unexpected degradation.
* Cross-validate data labels using multiple independent labelers or automated consistency checks.
* Audit data pipeline access logs for unauthorized modifications to training datasets.

## Remediation

* Remove identified poisoned data from the training dataset and retrain the model.
* Implement data provenance tracking to trace the origin of all training data.
* Enforce strict access controls and audit logging on data storage and labeling systems.
* Deploy anomaly detection on data ingestion pipelines to catch future poisoning attempts.
* Use ensemble models trained on different data subsets to reduce single-point-of-failure risk.
* Conduct periodic audits of data labeling quality and consistency.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
