---
title: 'LLM02: Sensitive Information Disclosure'
description: OWASP LLM Top 10 reference for sensitive information disclosure vulnerabilities including PII leakage and data exfiltration patterns
---

# 02 Sensitive Information Disclosure

Identifier: LLM02:2025
Category: Data Protection

## Description

Sensitive information can affect both the LLM and its application context. This includes
personal identifiable information (PII), financial details, health records, confidential
business data, security credentials, and legal documents. Proprietary models may also have
unique training methods and source code that are considered sensitive, particularly in
closed-source or foundation models.

LLMs risk exposing sensitive data, proprietary algorithms, and confidential details through
their output. This can result in unauthorized access to sensitive data, intellectual property
theft, privacy violations, and security breaches.

The interaction between the consumer and LLM application forms a two-way trust boundary,
where neither the client-to-LLM input nor the LLM-to-client output can be inherently trusted.
Adding restrictions within the system prompt regarding data types the LLM should return
provides some mitigation, but the unpredictable nature of LLMs means such restrictions may
not always be honored and could be circumvented via prompt injection or other vectors.

## Risk

* Unauthorized access to sensitive data through model output exposure.
* Intellectual property theft through proprietary algorithm or source code disclosure.
* Privacy violations from PII leakage in model responses.
* Security breaches from exposed credentials, connection strings, or security tokens.
* Competitive advantage loss from disclosed business strategies or pricing structures.
* Legal liability from unauthorized disclosure of confidential client or partner details.

## Vulnerability checklist

* PII is present in training data and could surface in the LLM's responses.
* Proprietary algorithms, source code, or confidential business strategies are accessible
  through model output due to their presence in training data.
* Sensitive business data such as internally-generated content, partner information, or client
  details can appear in the LLM's responses.
* User data is incorporated into training model data without adequate sanitization.
* The LLM has access to external data sources without strict access controls or least
  privilege enforcement.
* No Terms of Use policies inform users about data processing risks or opt-out options.
* The LLM's infrastructure lacks network segmentation, encryption, or other security measures
  to prevent unauthorized access to sensitive data.

## Prevention controls

1. Implement robust data sanitization techniques to prevent user data from being inadvertently
   incorporated into training model data, including data cleaning and scrubbing before
   training.
2. Apply thorough input validation and sanitization methods to prevent potentially malicious
   or unexpected inputs from impacting the model's behavior, including filtration and data
   masking.
3. Implement strict access controls and the principle of least privilege for LLM access to
   external data sources. Provide the LLM application with only the data necessary for its
   intended function. Establish strong authentication and authorization mechanisms such as
   OAuth and role-based access controls, and use encryption for sensitive data at rest and in
   transit.
4. Maintain detailed logs of data sources and transformations used during LLM training and
   operation, enabling auditing of data access and identification of potential information
   leakage.
5. Employ federated learning techniques that allow the model to learn from distributed data
   sources without centralizing sensitive data.
6. Educate users about the risks of providing sensitive information when interacting with LLMs.
   Provide guidelines for best practices such as avoiding inputting confidential data, and
   implement clear Terms of Use policies.
7. Ensure the LLM's infrastructure is securely configured with network segmentation,
   encryption, and other security measures to prevent unauthorized access to sensitive data.
8. For sensitive applications, consider differential privacy, homomorphic encryption, or
   secure multi-party computation techniques to add additional layers of protection.

## Example attack scenarios

### Scenario A — PII leakage from training data

A user interacts with an LLM application that has been trained on a dataset containing
personal health records. The user asks the model about common side effects of a particular
medication. The model inadvertently includes PII from its training data in its response,
revealing names and medical conditions of other patients.

### Scenario B — Proprietary code exposure

A user asks an LLM for a code snippet to implement a specific algorithm, and the LLM
unintentionally reveals proprietary source code from its training data. An attacker then
uses this disclosed proprietary code to reverse-engineer a company's product, gaining a
competitive advantage.

### Scenario C — Confidential business data in responses

An LLM-based customer support chatbot exposes confidential business data such as internal
pricing strategies, discount structures, or customer segmentation details in its responses.
A competitor or malicious user exploits this information to undercut the company's pricing
or target high-value clients.

## Detection guidance

* Audit data sources and transformations used during LLM training and operation for
  potential sensitive data inclusion.
* Monitor model outputs for PII, proprietary code, or confidential business data in
  responses.
* Review access control logs for unauthorized data access patterns through the LLM.
* Test model responses with targeted queries designed to elicit sensitive information such
  as training data extraction or membership inference attacks.
* Inspect the LLM's infrastructure configuration for adequate network segmentation and
  encryption.

## Remediation

* Implement robust data sanitization to remove sensitive data from training and fine-tuning
  datasets.
* Apply strict access controls and encryption for all external data sources accessible by
  the LLM.
* Deploy input validation and sanitization methods for all user interactions.
* Externalize sensitive data from system prompts and operational contexts.
* Update Terms of Use policies to clearly communicate data processing risks and provide
  opt-out options for users.
* Reconfigure infrastructure with proper network segmentation and encryption where security
  gaps exist.

---

Content derived from works by the OWASP Foundation, licensed under CC BY-SA 4.0
(<https://creativecommons.org/licenses/by-sa/4.0/>).
Modifications: Restructured into agent-consumable reference format with added
detection and remediation guidance.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
