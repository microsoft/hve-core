---
title: STRIDE Model and Threat Analysis
description: STRIDE categories, AI-specific extensions, risk matrix guidance, and threat-analysis conventions for security planning.
---

# STRIDE Model and Threat Analysis

This reference captures the STRIDE methodology, AI-specific extensions, and threat table conventions used during security planning.

## STRIDE categories

* Spoofing — identity claims and impersonation
* Tampering — unauthorized modification of data or code
* Repudiation — lack of attributable evidence
* Information Disclosure — sensitive data exposure
* Denial of Service — resource exhaustion or interruption
* Elevation of Privilege — unauthorized access or privilege increase

## AI-specific STRIDE extensions

When `raiEnabled` is true, add AI-guiding questions to each STRIDE category for ai-ml components and AI-integrated components in other buckets.

Examples:

* Spoofing: Can adversarial inputs cause the model to impersonate legitimate outputs?
* Tampering: Can training data be poisoned to alter model behavior?
* Repudiation: Can model decisions be traced to specific inputs and model versions?
* Information Disclosure: Can model weights or training data be extracted through query patterns?
* Denial of Service: Can adversarial inputs cause model resource exhaustion?
* Elevation of Privilege: Can prompt injection bypass content safety guardrails?

## Threat ID pattern

Use `T-{BUCKET_ABBREV}-{NNN}` for standard buckets and `T-{BUCKET_ABBREV}-AI-{NNN}` for AI-specific threats in existing buckets when `raiEnabled` is true.

## Threat table format

| ID          | STRIDE    | Description                           | Component    | Likelihood | Impact | Risk     | Mitigation                                | Standards          |
|-------------|-----------|---------------------------------------|--------------|------------|--------|----------|-------------------------------------------|--------------------|
| T-INFRA-001 | Tampering | Config drift via unauthorized changes | IaC pipeline | High       | High   | Critical | Immutable infrastructure, drift detection | CIS 5.1, NIST CM-3 |

## Risk matrix

Use the bucketed likelihood/impact matrix to derive directional priority ratings:

|                    | Impact: Low   | Impact: Medium | Impact: High |
|--------------------|---------------|----------------|--------------|
| Likelihood: High   | Low           | High           | Critical     |
| Likelihood: Medium | Low           | Medium         | High         |
| Likelihood: Low    | Informational | Low            | Low          |

## Data-flow analysis guidance

For each bucket, capture inbound, internal, and outbound flows, identify trust boundaries, and note sensitive paths that need extra control coverage.

### AI element types

* ML Model
* Training Pipeline
* Inference Endpoint
* Vector Store
* RAG Pipeline
* Agent Orchestrator
* Content Filter
* Model Registry
