---
title: 'ML09: Output Integrity Attack'
description: OWASP ML Top 10 reference for output integrity vulnerabilities including post-inference tampering and model output manipulation
---

# 09 Output Integrity Attack

Identifier: ML09:2023
Category: Output Security

## Description

In an Output Integrity Attack, an attacker aims to modify or manipulate the output of a machine
learning model in order to change its behavior or cause harm to the system it is used in. The
attacker targets the communication channel between the model and the interface responsible for
displaying results, or tampers with the model's outputs after inference. This can lead to
incorrect decisions, financial loss, or security risks when the model is used in critical
applications such as medical diagnosis, financial fraud detection, or cybersecurity.

## Risk

- Loss of confidence in the model's predictions and results.
- Financial loss or damage to reputation if the model's predictions are used to make important
  decisions.
- Security risks if the model is used in a critical application such as financial fraud detection
  or cybersecurity.
- Malicious attackers or insiders who have access to model inputs and outputs can execute this
  attack.
- Third-party entities with access to inputs and outputs may tamper with them to achieve a
  desired outcome.

## Vulnerability checklist

- Communication channels between the model and the result display interface are not secured with
  protocols such as SSL/TLS.
- No cryptographic methods such as digital signatures or secure hashes are used to verify output
  authenticity.
- Input validation is not performed on results to check for unexpected or manipulated values.
- Tamper-evident logs of input and output interactions are not maintained.
- Regular software updates and security patches are not applied.
- Monitoring and auditing of results and model interactions is insufficient.
- No authentication or authorization measures are in place to ensure input and output integrity.

## Prevention controls

1. Use cryptographic methods such as digital signatures and secure hashes to verify the
   authenticity of results.
2. Secure communication channels between the model and the interface responsible for displaying
   results using protocols such as SSL/TLS.
3. Perform input validation on results to check for unexpected or manipulated values.
4. Maintain tamper-evident logs of all input and output interactions to detect and respond to
   output integrity attacks.
5. Apply regular software updates to fix vulnerabilities and security patches to reduce the risk
   of output integrity attacks.
6. Regularly monitor and audit the results and interactions between the model and the interface
   to detect suspicious activities.

## Example attack scenarios

### Scenario A — Modification of patient health records
An attacker gains access to the output of a machine learning model being used to diagnose diseases
in a hospital. The attacker modifies the model's output, making it provide incorrect diagnoses for
patients. As a result, patients are given incorrect treatments, leading to further harm and
potentially death.

## Detection guidance

- Monitor communication channels between the model and display interfaces for tampering or
  man-in-the-middle activity.
- Verify output integrity using cryptographic signatures at the point of consumption.
- Review tamper-evident logs for discrepancies between recorded model outputs and displayed
  results.
- Track output distributions over time for sudden shifts that may indicate tampering.
- Audit access logs for unauthorized access to model output endpoints or display systems.

## Remediation

- Encrypt and sign all model outputs using cryptographic methods before transmission.
- Secure all communication channels between the model and consuming systems with SSL/TLS.
- Implement tamper-evident logging for all input and output interactions.
- Apply pending software updates and security patches to model serving infrastructure.
- Restrict access to model output endpoints to authenticated and authorized consumers only.
- Conduct a forensic review of tampered outputs and restore correct results from logs.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
