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

Data poisoning can target different stages of the LLM lifecycle: pre-training (learning from
general data), fine-tuning (adapting the model to specific tasks), embedding (converting text
to numerical vectors), and Retrieval Augmented Generation (fetching relevant data to
supplement responses).

Data poisoning is considered an integrity attack because tampering with training data impacts
the model's ability to make accurate predictions. The risks are especially high with external
data sources that may contain unverified or malicious content.

Models distributed through shared repositories or open-source platforms can carry risks beyond
data poisoning, such as malware embedded through techniques like malicious pickling.

## Common examples

1. An attacker or unverified source contributes files containing hidden biases, misleading
   associations, or embedded instructions that subtly influence outputs during pre-training,
   fine-tuning, or embedding stages.
2. An adversary inserts manipulated content into the model's ongoing learning sources
   (web-crawled data, user-generated feedback, or curated datasets).
3. An attacker targets components of the data pipeline such as data collection tools,
   preprocessing workflows, or storage systems.
4. An adversary fine-tunes a model on a poisoned dataset with specific triggers, enabling
   the model to behave differently when certain keywords are present.
5. In RAG systems, an attacker poisons the external knowledge base documents, causing
   subtly inaccurate or biased responses.

## Attack scenarios

### Scenario A — Corrupted training data

An attacker corrupts training data by inserting records containing biased, false, or
misleading content, leading the model to generate factually wrong and biased outputs in
healthcare, legal, or financial contexts.

### Scenario B — RAG knowledge base poisoning

An attacker poisons a retrieval data source in a RAG-based system by injecting harmful or
misleading information, causing the model to spread misinformation or make harmful
recommendations.

### Scenario C — Backdoor via fine-tuning

An attacker fine-tunes a model with poisoned data that includes backdoor triggers. The model
behaves normally unless a specific keyword is present, at which point it generates malicious
content.

### Scenario D — Pipeline compromise

An attacker compromises the data pipeline by injecting malicious content into a web-crawled
dataset, introducing subtle biases or vulnerabilities that go unnoticed until they cause
real-world damage.

## Prevention and mitigation

1. Track data provenance using tools like OWASP CycloneDX or ML BOM to verify data has not
   been tampered with at each stage.
2. Perform integrity checks on all datasets used in pre-training, fine-tuning, and embedding
   with checksums, audits, or similar methods.
3. Employ adversarial training methods including federated learning and constraints to minimize
   sensitivity to outliers and poisoned inputs.
4. Use statistical methods and anomaly detection tools to identify unusual patterns or outliers
   in training data.
5. Apply input validation, curated datasets, and sandboxing to filter out potentially harmful
   data during pre-training, fine-tuning, and RAG retrieval.
6. Regularly evaluate model outputs through red teaming exercises and adversarial testing to
   identify signs of poisoning.
7. Conduct regular bias and fairness audits on model outputs.
8. Use models from reputable, security-verified sources with signed model artifacts and
   validated checksums.
9. Monitor changes in data files and model artifacts using version control with cryptographic
   hashing.
10. Implement quality checks on user-generated content and real-time data feeds to prevent
    poisoned data from being incorporated during retraining.

## References

* [AML.T0018 - Backdoor ML Model](https://atlas.mitre.org/techniques/AML.T0018) — MITRE ATLAS
* [AML.T0020 - Poison Training Data](https://atlas.mitre.org/techniques/AML.T0020) — MITRE ATLAS

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
