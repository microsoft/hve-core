# 02 Sensitive Information Disclosure

Identifier: LLM02:2025
Category: Data Protection

## Description

Sensitive information can affect both the LLM and its application context. This includes
personal identifiable information (PII), financial details, health records, confidential
business data, security credentials, and legal documents. Proprietary models may also have
unique training methods and source code that are considered sensitive.

LLMs risk exposing sensitive data, proprietary algorithms, and confidential details through
their output. This can result in unauthorized access to sensitive data, intellectual property
theft, privacy violations, and security breaches.

The interaction between the consumer and LLM application forms a two-way trust boundary,
where neither the client-to-LLM input nor the LLM-to-client output can be inherently trusted.
Adding restrictions within the system prompt regarding data types the LLM should return
provides some mitigation, but the unpredictable nature of LLMs means such restrictions may
not always be honored and could be circumvented via prompt injection.

## Common examples

1. PII surfaces in the LLM's responses due to having been present in training data or
   provided through prompting or connected systems.
2. A poorly configured LLM output exposes proprietary algorithms, source code, or
   confidential business strategies, risking competitive advantage and intellectual
   property theft.
3. The LLM's responses include sensitive business data such as internally-generated content,
   partner information, or client details.

## Attack scenarios

### Scenario A — PII leakage from training data

A user interacts with an LLM application trained on a dataset containing personal health
records. The user asks about medication side effects and the model inadvertently includes
PII from its training data, revealing names and medical conditions of other patients.

### Scenario B — Proprietary code exposure

A user asks an LLM for a code snippet to implement a specific algorithm., The LLM
unintentionally reveals proprietary source code from its training data. An attacker then
uses this to reverse-engineer a company's product.

### Scenario C — Confidential business data in responses

An LLM-based customer support chatbot exposes confidential business data such as internal
pricing strategies, discount structures, or customer segmentation details. A competitor
exploits this information to undercut the company's pricing.

## Prevention and mitigation

1. Implement robust data sanitization to prevent user data from being incorporated into
   training model data, including data cleaning and scrubbing before training.
2. Apply thorough input validation and sanitization methods to prevent malicious or unexpected
   inputs from impacting the model's behavior.
3. Implement strict access controls and the principle of least privilege for LLM access to
   external data sources, with strong authentication, authorization, and encryption.
4. Maintain detailed logs of data sources and transformations used during LLM training and
   operation, enabling auditing of data access.
5. Employ federated learning techniques that allow the model to learn from distributed data
   sources without centralizing sensitive data.
6. Educate users about the risks of providing sensitive information when interacting with
   LLMs and provide clear Terms of Use policies.
7. Ensure the LLM's infrastructure is securely configured with network segmentation,
   encryption, and other security measures.
8. For sensitive applications, consider differential privacy, homomorphic encryption, or
   secure multi-party computation techniques.

## References

* [AML.T0024.000 - Infer Training Data Membership](https://atlas.mitre.org/techniques/AML.T0024.000) — MITRE ATLAS
* [AML.T0024.002 - Infer Training Data](https://atlas.mitre.org/techniques/AML.T0024.002) — MITRE ATLAS
* [AML.T0058 - Model Inversion](https://atlas.mitre.org/techniques/AML.T0058) — MITRE ATLAS
