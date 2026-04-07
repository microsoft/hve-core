---
title: 'LLM04: Data and Model Poisoning'
description: OWASP LLM Top 10 reference for data and model poisoning attacks targeting training data integrity and model behavior
---

# 04 Data and Model Poisoning

Identifier: LLM04:2025
Category: Data Integrity

## Description

Data poisoning occurs when pre-training, fine-tuning, or embedding data is manipulated to
introduce vulnerabilities, backdoors, or biases. This can compromise model security,
performance, and ethical behavior, leading to harmful outputs or impaired capabilities.
Common risks include degraded model performance, biased or toxic content, and exploitation
of downstream systems.

Data poisoning can target different stages of the LLM lifecycle: pre-training (learning from
general data), fine-tuning (adapting the model to specific tasks), embedding (converting text
to numerical vectors), and Retrieval Augmented Generation (fetching relevant data to
supplement responses). Data poisoning is considered an integrity attack because tampering with
training data impacts the model's ability to make accurate predictions. The risks are
especially high with external data sources that may contain unverified or malicious content.

Models distributed through shared repositories or open-source platforms can carry risks beyond
data poisoning, such as malware embedded through techniques like malicious pickling, where the
model's serialized format is used to distribute and execute harmful code on loading.

## Risk

* Degraded model performance leading to factually incorrect outputs in critical domains such
  as healthcare, legal decisions, or financial recommendations.
* Biased or toxic content generation from poisoned training data.
* Exploitation of downstream systems through manipulated model outputs.
* Backdoor activation through triggered keywords or patterns embedded during fine-tuning.
* Integrity compromise of RAG knowledge bases leading to misinformation or harmful
  recommendations.
* Malware distribution through compromised model serialization formats.
* Covert attacker control of model behavior through hidden triggers.

## Vulnerability checklist

* Training data is sourced from unverified or potentially malicious third parties without
  integrity checks.
* Adversarial content is inserted into web-crawled data, user-generated feedback, or curated
  datasets used for model learning.
* Data pipeline components such as collection tools, preprocessing workflows, or storage
  systems lack integrity controls.
* Fine-tuning datasets are not verified for backdoor triggers or malicious patterns.
* RAG knowledge base documents are not validated for hidden or manipulated content.
* External models are used without signed artifacts or validated checksums.
* Version control and cryptographic hashing are not applied to data files and model artifacts.
* User-generated content and real-time data feeds are incorporated into retraining without
  quality checks.

## Prevention controls

1. Track data provenance using tools like OWASP CycloneDX or ML BOM to verify data has not
   been tampered with at each stage of pre-training, fine-tuning, and embedding.
2. Perform integrity checks on all datasets used in pre-training, fine-tuning, and embedding.
   Validate data with checksums, audits, or similar methods to detect tampering early.
3. Employ adversarial training methods including federated learning and constraints to minimize
   sensitivity to outliers and defend against extreme data perturbations.
4. Use statistical methods and anomaly detection tools to identify unusual patterns or outliers
   in training data. Monitor for signs of poisoning through analysis of model behavior on test
   datasets.
5. Apply input validation, curated datasets, and sandboxing to filter out potentially harmful
   data during pre-training, fine-tuning, and RAG retrieval.
6. Regularly evaluate model outputs through red teaming exercises and adversarial testing to
   identify signs of poisoning. Use automated monitoring to detect unusual or harmful outputs
   in real-time.
7. Conduct regular bias and fairness audits on model outputs to ensure poisoned data has not
   introduced or reinforced undesirable biases.
8. Use models from reputable, security-verified sources with signed model artifacts and
   validated checksums. Apply strict access controls for model repositories.
9. Monitor changes in data files and model artifacts using version control with cryptographic
   hashing to verify integrity and detect unauthorized modifications.
10. Implement quality checks on user-generated content and real-time data feeds to prevent
    poisoned data from being incorporated during retraining or fine-tuning.

## Example attack scenarios

### Scenario A — Corrupted training data

An attacker corrupts the training data of an LLM by inserting records that contain biased,
false, or misleading content. This leads the model to generate outputs that are factually
wrong and biased, which can have significant consequences in areas such as healthcare, legal
decisions, or financial recommendations.

### Scenario B — RAG knowledge base poisoning

An attacker poisons a retrieval data source in a RAG-based system by injecting harmful or
misleading information into the documents used for augmenting model responses. When the model
retrieves these poisoned documents, the outputs could spread misinformation or make harmful
recommendations.

### Scenario C — Backdoor via fine-tuning

An attacker fine-tunes a model with poisoned data that includes backdoor triggers. The model
may behave normally unless a specific keyword or pattern is included in the prompt, at which
point it generates malicious or harmful content. This creates a covert mechanism for the
attacker to control when the malicious behavior is activated.

### Scenario D — Pipeline compromise

An attacker compromises the data pipeline by injecting malicious content into a web-crawled
dataset used for pre-training or fine-tuning. The malicious data introduces subtle biases or
vulnerabilities in the model, which might go unnoticed until they cause real-world damage.

### Scenario E — RAG poisoning via prompt injection

An attacker uses prompt injection techniques to insert malicious content into a document that
is subsequently indexed in a RAG system. When a user queries the system, the poisoned data is
retrieved and used to generate a harmful or misleading response.

## Detection guidance

* Use statistical methods and anomaly detection tools to identify unusual patterns or outliers
  in training data that may indicate poisoning.
* Evaluate model outputs through red teaming exercises for signs of poisoning such as biased,
  factually incorrect, or unexpected responses.
* Conduct regular bias and fairness audits on model outputs to detect changes introduced by
  poisoned data.
* Monitor changes in data files and model artifacts using version control with cryptographic
  hashing for unauthorized modifications.
* Analyze model behavior on test datasets for outputs indicating bias or unexpected patterns
  that were not present before data updates.
* Inspect RAG knowledge base documents for hidden codes, injected content, or contradictory
  information.

## Remediation

* Perform integrity checks on all datasets with checksums, audits, or similar methods and
  remove identified poisoned data.
* Apply input validation, curated datasets, and sandboxing to filter out harmful data from
  all pipeline stages.
* Replace compromised models with versions from reputable, security-verified sources using
  signed artifacts and validated checksums.
* Retrain or fine-tune affected models on verified clean datasets after removing poisoned
  content.
* Implement quality checks on user-generated content and real-time data feeds before
  incorporation into retraining.
* Deploy adversarial training methods to minimize sensitivity to identified poisoning patterns.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
