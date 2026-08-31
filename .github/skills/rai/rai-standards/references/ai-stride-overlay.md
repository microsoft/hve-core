---
title: AI STRIDE Overlay
description: Threat-modeling overlay for RAI and security model analysis
---

# AI STRIDE Overlay

This overlay extends STRIDE analysis for AI systems by capturing data, model, inference, feedback-loop, and human-review risks that standard software threat models often omit.

## Core extensions

- Training data stores
- Model artifacts and checkpoints
- Inference endpoints and serving layers
- Feature pipelines and data preparation
- Feedback loops and retraining paths
- Human review queues and escalation paths
- Monitoring dashboards and telemetry pipelines
- Orchestration layers and agentic control flows

## Trust-boundary guidance

Treat each training, inference, and monitoring boundary as a trust boundary. Evaluate whether data provenance, model versioning, telemetry, and human-review outputs can be altered, exfiltrated, or repudiated.

## Dual threat-ID convention

- T-RAI-### for RAI-managed threat IDs
- T-{BUCKET}-AI-### for cross-references that connect to the Security Planner's bucketed analysis

## ML STRIDE matrix

| STRIDE category        | AI-specific concern                                                                    |
|------------------------|----------------------------------------------------------------------------------------|
| Spoofing               | Identity confusion across model endpoints, service identities, and human-review actors |
| Tampering              | Data poisoning, model tampering, feature drift injection                               |
| Repudiation            | Missing audit trails for model decisions and review actions                            |
| Information Disclosure | Training data leakage, explanation leakage, inference exfiltration                     |
| Denial of Service      | Resource exhaustion, adversarial examples, runaway retraining                          |
| Elevation of Privilege | Orchestrator or model-action escalation beyond permitted scope                         |

## Merge protocol

When the Security Planner produces a security model, merge the RAI-specific findings into the existing plan using the dual threat-ID convention and preserve both the RAI-managed and cross-referenced IDs in the output.

## Source attribution

This reference is adapted from the repository's RAI security-model guidance and is intended for reuse by the Security Planner and RAI Planner.
