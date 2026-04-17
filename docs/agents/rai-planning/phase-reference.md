---
title: Phase Reference
description: Complete specification of the RAI Planner's six assessment phases including NIST AI RMF mapping, artifacts, and state transitions
sidebar_position: 5
sidebar_label: Phase Reference
keywords:
  - RAI phases
  - NIST AI RMF
  - RAI security model
  - RAI review summary
tags:
  - rai-planning
  - reference
  - phases
author: Microsoft
ms.date: 2026-03-11
ms.topic: reference
estimated_reading_time: 8
---

## Phase Summary

| Phase | Name                        | NIST AI RMF      | Key output                                                                      | State fields updated                                    |
|-------|-----------------------------|------------------|---------------------------------------------------------------------------------|---------------------------------------------------------|
| 1     | AI System Scoping           | Govern + Map     | `system-definition-pack.md`, `stakeholder-impact-map.md`                        | `currentPhase`, `entryMode`, `securityPlanRef`          |
| 2     | Risk Classification         | Govern           | Risk classification screening summary (appended to `system-definition-pack.md`) | `riskClassification`                                    |
| 3     | RAI Standards Mapping       | Govern + Measure | `rai-standards-mapping.md`                                                      | `standardsMapped`                                       |
| 4     | RAI Security Model Analysis | Measure          | `rai-security-model-addendum.md`                                                | `securityModelAnalysisStarted`, `raiThreatCount`        |
| 5     | RAI Impact Assessment       | Manage           | `control-surface-catalog.md`, `evidence-register.md`, `rai-tradeoffs.md`        | `impactAssessmentGenerated`, `evidenceRegisterComplete` |
| 6     | Review and Handoff          | Manage           | `rai-review-summary.md`, backlog items                                          | `handoffGenerated`                                      |

## Phase 1: AI System Scoping

> NIST AI RMF alignment: Govern + Map

### Purpose

Establish the AI system's boundaries, identify all AI and ML components, and map stakeholder roles and data flows. This phase provides the foundation for every subsequent assessment phase.

### Inputs

* User answers to scoping questions (capture mode)
* PRD or BRD artifacts (from-prd mode)
* Security plan `state.json` and `aiComponents` array (from-security-plan mode)

### Process

The agent asks up to 7 questions per turn covering:

* AI system purpose and intended outcomes
* Technology stack, model types, and frameworks
* Stakeholder roles (developers, operators, affected individuals, oversight bodies)
* Data inputs, training data sources, and output destinations
* Deployment model (cloud, edge, hybrid, on-device)
* Intended and unintended use contexts

In `from-security-plan` mode, AI components from the security plan are pre-populated and the agent focuses on RAI-specific aspects not covered during security assessment.

### Outputs

* `system-definition-pack.md`: AI system inventory, component catalog, and deployment context
* `stakeholder-impact-map.md`: Stakeholder roles, power dynamics, and impact pathways

### State Transitions

| Field             | Before          | After                        |
|-------------------|-----------------|------------------------------|
| `currentPhase`    | 1               | 2                            |
| `entryMode`       | set during init | unchanged                    |
| `securityPlanRef` | null            | path (if from-security-plan) |

## Phase 2: Risk Classification

> NIST AI RMF alignment: Govern

### Purpose

Screen the AI system for risk using NIST AI RMF 1.0 trustworthiness characteristics to determine the suggested assessment depth tier for subsequent phases. The prohibited uses gate executes first, then three risk indicators derived from NIST subcategories determine the suggested depth tier.

### Inputs

* System definition pack from Phase 1

### Process

The agent evaluates three risk indicators derived from NIST AI RMF 1.0 trustworthiness characteristics:

| Indicator                 | NIST source                                                                   | Method      | Domain                                                                              |
|---------------------------|-------------------------------------------------------------------------------|-------------|-------------------------------------------------------------------------------------|
| `safety_reliability`      | Valid and Reliable, Safe                                                      | Binary      | Physical harm, psychological injury, operational disruption from unreliable outputs |
| `rights_fairness_privacy` | Accountable and Transparent, Privacy-Enhanced, Fair with Harmful Bias Managed | Categorical | Discrimination, rights restriction, equitable access, personal data misuse          |
| `security_explainability` | Secure and Resilient, Explainable and Interpretable                           | Continuous  | Adversarial attacks, data poisoning, model theft, inability to explain decisions    |

Each indicator uses its own assessment method (binary, categorical, or continuous). When the user has supplied custom risk indicator extensions, those are incorporated as additional evaluation criteria alongside the default NIST-derived indicators.

### Depth Tier Assignment

| Activated count | Suggested tier |
|-----------------|----------------|
| 0               | Basic          |
| 1               | Standard       |
| 2+              | Comprehensive  |

### Outputs

* Risk classification screening summary appended to `system-definition-pack.md`

### State Transitions

| Field                | Before | After                              |
|----------------------|--------|------------------------------------|
| `currentPhase`       | 2      | 3                                  |
| `riskClassification` | null   | risk classification results object |

## Phase 3: RAI Standards Mapping

> NIST AI RMF alignment: Govern + Measure

### Purpose

Map each AI component against NIST AI RMF 1.0 trustworthiness characteristics and subcategories. Establish the evaluation framework used in Phases 4 and 5.

### Inputs

* System definition pack from Phase 1

### Process

The agent maps components against seven NIST AI RMF 1.0 trustworthiness characteristics:

| Characteristic                 | Focus area                                                   |
|--------------------------------|--------------------------------------------------------------|
| Valid and Reliable             | Accurate outputs, consistent performance, degradation paths  |
| Safe                           | Physical and psychological harm prevention, failure modes    |
| Secure and Resilient           | Adversarial robustness, data protection, recovery mechanisms |
| Accountable and Transparent    | Oversight mechanisms, audit trails, decision traceability    |
| Explainable and Interpretable  | Model interpretability, decision explanation, disclosure     |
| Privacy-Enhanced               | Data minimization, consent, inference prevention             |
| Fair with Harmful Bias Managed | Bias detection, equitable outcomes, allocation harms         |

For each characteristic-component pair, the agent identifies:

* Applicable NIST AI RMF subcategories
* Regulatory jurisdiction and framework obligations
* Existing compliance posture

The Researcher Subagent is dispatched for runtime lookups of specific regulatory frameworks (WAF, CAF, ISO 42001, EU AI Act) when the assessment requires detail beyond embedded standards.

### Outputs

* `rai-standards-mapping.md`: Characteristic-by-component mapping with NIST subcategory references and compliance gaps

### State Transitions

| Field             | Before | After |
|-------------------|--------|-------|
| `currentPhase`    | 3      | 4     |
| `standardsMapped` | false  | true  |

## Phase 4: RAI Security Model Analysis

> NIST AI RMF alignment: Measure

### Purpose

Identify AI-specific threats across all components using a structured threat taxonomy. Each threat receives a unique identifier and risk rating.

### Inputs

* System definition pack from Phase 1
* RAI standards mapping from Phase 3
* Security plan threat catalog (when using from-security-plan mode)

### Process

The agent applies threat analysis across seven AI-specific categories:

| Category            | Threat focus                                                |
|---------------------|-------------------------------------------------------------|
| Data poisoning      | Manipulation of training or fine-tuning data                |
| Model evasion       | Adversarial inputs designed to cause misclassification      |
| Prompt injection    | Manipulation of LLM prompts to override instructions        |
| Output manipulation | Altering model outputs in transit or post-processing        |
| Bias amplification  | Model behavior that reinforces or amplifies existing biases |
| Privacy leakage     | Extraction of training data, PII, or sensitive information  |
| Misuse escalation   | System capabilities repurposed for unintended harmful uses  |

Each threat receives a sequential identifier in `T-RAI-{NNN}` format. When a threat overlaps with a Security Planner operational bucket, it also receives a `T-{BUCKET}-AI-{NNN}` cross-reference ID. In `from-security-plan` mode, numbering continues from the security plan's threat count to maintain a unified threat registry.

### Concern Level Assessment

Each threat is assigned a concern level based on contextual analysis rather than a fixed matrix:

| Concern level | Meaning                                                        |
|---------------|----------------------------------------------------------------|
| Low           | Threat is unlikely to manifest or impact is minimal            |
| Moderate      | Threat warrants attention and monitoring                       |
| High          | Threat requires active mitigation before production deployment |

### Outputs

* `rai-security-model-addendum.md`: Threat catalog with IDs, categories, descriptions, risk ratings, and recommended mitigations

### State Transitions

| Field                          | Before | After                       |
|--------------------------------|--------|-----------------------------|
| `currentPhase`                 | 4      | 5                           |
| `securityModelAnalysisStarted` | false  | true                        |
| `raiThreatCount`               | 0      | count of identified threats |

## Phase 5: RAI Impact Assessment

> NIST AI RMF alignment: Manage

### Purpose

Explore control surface completeness for each identified threat. Document evidence of existing mitigations, identify gaps, and analyze tradeoffs between competing trustworthiness characteristics.

### Inputs

* RAI security model addendum from Phase 4
* RAI standards mapping from Phase 3
* Evidence provided by the user or discovered in the codebase

### Process

For each threat identified in Phase 4, the agent evaluates:

* Whether a control or mitigation exists
* What evidence supports the control's effectiveness
* Whether the control introduces tradeoffs with other trustworthiness characteristics
* What gaps remain and what remediation is recommended

Common tradeoff examples:

| Tradeoff                 | Example                                                                         |
|--------------------------|---------------------------------------------------------------------------------|
| Transparency vs. Privacy | Explaining model decisions may reveal sensitive training data                   |
| Fairness vs. Performance | Debiasing techniques may reduce model accuracy for some populations             |
| Safety vs. Inclusiveness | Conservative safety filters may disproportionately restrict certain user groups |

### Outputs

* `control-surface-catalog.md`: Control inventory mapped to threats with effectiveness ratings
* `evidence-register.md`: Evidence log documenting existing mitigations, gaps, and collection difficulty
* `rai-tradeoffs.md`: Characteristic conflict analysis with resolution recommendations

The control surface catalog and evidence register are agentic artifacts that include only the AI-content transparency note. RAI tradeoffs is a human-facing artifact that also includes the human review checkbox. See [Handoff Pipeline](handoff-pipeline#artifact-attribution-and-review) for the complete footer classification.

### State Transitions

| Field                       | Before | After |
|-----------------------------|--------|-------|
| `currentPhase`              | 5      | 6     |
| `impactAssessmentGenerated` | false  | true  |
| `evidenceRegisterComplete`  | false  | true  |

## Phase 6: Review and Handoff

> NIST AI RMF alignment: Manage

### Purpose

Generate a review summary covering observations across six dimensions and produce backlog items for identified gaps. Hand off to ADO or GitHub.

### Inputs

* All artifacts from Phases 1-5
* User preferences for backlog format and handoff system

### Process

The agent generates a review summary covering observations across six dimensions:

| Dimension             | What it covers                                                                            |
|-----------------------|-------------------------------------------------------------------------------------------|
| Standards Alignment   | Whether findings map to NIST AI RMF 1.0 trustworthiness characteristics and subcategories |
| Threat Completeness   | Completeness and accuracy of threat identification                                        |
| Control Effectiveness | Coverage and effectiveness of controls for identified threats                             |
| Evidence Quality      | Quality and availability of evidence supporting control effectiveness                     |
| Tradeoff Resolution   | Whether competing characteristic tradeoffs have been analyzed and resolved                |
| Risk Classification   | Whether risk indicators were evaluated with documented mitigations                        |

The review summary presents observations and maturity indicators rather than numeric scores. Findings are organized to support handoff decisions and backlog prioritization.

### Backlog Generation

Gaps identified across Phases 3-5 are converted to work items using the same dual-platform format as the Security Planner:

* ADO work items use `WI-RAI-{NNN}` temporary IDs
* GitHub issues use `{{RAI-TEMP-N}}` temporary IDs
* Default autonomy tier is Partial: items are created but require user confirmation before submission

### Outputs

* `rai-review-summary.md`: Review summary with observations across six dimensions and maturity indicators
* Backlog items in the user's preferred format

All Phase 6 artifacts are human-facing and include the AI-content transparency note and human review checkbox. The handoff summary and compact handoff summary also include the full RAI Planner disclaimer. See [Handoff Pipeline](handoff-pipeline#artifact-attribution-and-review) for the complete footer classification.

### State Transitions

| Field              | Before                              | After                             |
|--------------------|-------------------------------------|-----------------------------------|
| `currentPhase`     | 6                                   | 6 (terminal)                      |
| `handoffGenerated` | `{ "ado": false, "github": false }` | `{ "ado": true, "github": true }` |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
