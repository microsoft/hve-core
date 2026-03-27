---
title: 'ML01: Input Manipulation Attack'
description: OWASP ML Top 10 reference for input manipulation and adversarial attack vulnerabilities including crafted perturbations that cause incorrect model outputs
---

# 01 Input Manipulation Attack

Identifier: ML01:2023
Category: Input Security

## Description

Input Manipulation Attacks is an umbrella term which includes Adversarial Attacks, a type of attack
in which an attacker deliberately alters input data to mislead the model. The attacker crafts
inputs with small, carefully designed perturbations that cause the model to produce incorrect
outputs while appearing legitimate to human observers. This category affects any machine learning
system that accepts external input, including image classifiers, intrusion detection systems, and
natural language processing models.

## Risk

- Misclassification of inputs leading to security bypass or harm to the system.
- The manipulated input may not be noticeable to the naked eye, making the attack difficult to
  detect.
- Exploitation requires technical knowledge of deep learning and input processing techniques.
- Attackers with knowledge of the model's architecture can craft targeted perturbations.
- Cascading failures when misclassified inputs trigger downstream actions in automated pipelines.

## Vulnerability checklist

- The model lacks adversarial training and has not been exposed to adversarial examples during
  training.
- No input validation is performed to detect anomalies, unexpected values, or patterns.
- The model is not designed with robust architectures or defense mechanisms against manipulative
  inputs.
- Model predictions are consumed directly without downstream verification or confidence
  thresholding.
- No monitoring is in place to detect distribution shifts or anomalous input patterns at inference
  time.
- The model's architecture and parameters are accessible to potential attackers.

## Prevention controls

1. Train the model on adversarial examples to improve robustness against manipulated inputs.
2. Use models designed with robust architectures and activation functions that incorporate defense
   mechanisms against adversarial perturbations.
3. Implement input validation to check input data for anomalies such as unexpected values or
   patterns and reject inputs that are likely to be malicious.
4. Apply confidence thresholding to flag or reject predictions below a confidence threshold.
5. Use ensemble methods that combine multiple models to reduce the likelihood that a single
   adversarial perturbation fools all models.
6. Restrict access to model internals to prevent attackers from crafting targeted attacks.

## Example attack scenarios

### Scenario A — Image classification bypass
A deep learning model is trained to classify images into categories such as dogs and cats. An
attacker manipulates an image that is visually similar to a legitimate image of a cat but contains
small, carefully crafted perturbations that cause the model to misclassify it as a dog. When the
model is deployed in a real-world setting, the attacker uses the manipulated image to bypass
security measures or cause harm to the system.

### Scenario B — Network intrusion detection evasion
A deep learning model is trained to detect intrusions in a network. An attacker manipulates
network traffic by carefully crafting packets that evade the model's intrusion detection system.
The attacker alters features of the network traffic such as the source IP address, destination IP
address, or payload in a way that avoids detection. The attacker may hide their source IP address
behind a proxy server or encrypt the payload. This leads to data theft, system compromise, or
other forms of damage.

## Detection guidance

- Monitor input distributions at inference time for statistical anomalies or distribution shifts
  compared to training data.
- Log all inputs and outputs to detect patterns of adversarial probing.
- Implement anomaly detection on incoming data to flag inputs that deviate significantly from
  expected distributions.
- Compare model confidence scores over time to detect sudden drops or unusual prediction patterns.
- Use gradient-based detection methods to identify inputs that produce unusually large gradients.

## Remediation

- Retrain the model with adversarial examples incorporated into the training dataset.
- Deploy input validation filters to reject or quarantine suspicious inputs before inference.
- Implement robust model architectures that are inherently resistant to small perturbations.
- Add confidence-based gating to suppress low-confidence predictions.
- Restrict public access to model APIs and internals to limit attacker reconnaissance.
- Continuously monitor model performance in production for accuracy degradation that may indicate
  ongoing adversarial attacks.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
