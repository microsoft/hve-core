---
title: Phase Reference
description: Complete specification of the RAI Planner's five assessment phases including NIST AI RMF mapping, artifacts, and state transitions
sidebar_position: 5
sidebar_label: Phase Reference
keywords:
  - RAI phases
  - NIST AI RMF
  - RAI security model
  - RAI scorecard
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

| Phase | Name                        | NIST AI RMF      | Key output                                                               | State fields updated                                                                       |
|-------|-----------------------------|------------------|--------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| 1     | AI System Scoping           | Govern + Map     | `system-definition-pack.md`, `stakeholder-impact-map.md`                 | `currentPhase`, `entryMode`, `securityPlanRef`                                             |
| 2     | RAI Standards Mapping       | Govern + Measure | `rai-standards-mapping.md`                                               | `standardsMapped`                                                                          |
| 3     | RAI Security Model Analysis | Measure          | `rai-security-model-addendum.md`                                         | `raiRiskSurfaceStarted`, `raiThreatCount`                                                  |
| 4     | RAI Impact Assessment       | Manage           | `control-surface-catalog.md`, `evidence-register.md`, `rai-tradeoffs.md` | `impactAssessmentGenerated`, `evidenceRegisterComplete`                                    |
| 5     | Review and Handoff          | Manage           | `rai-scorecard.md`, backlog items                                        | `handoffGenerated`, `scoredDimensions`                                                     |

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

## Phase 2: RAI Standards Mapping

> NIST AI RMF alignment: Govern + Measure

### Purpose

Map each AI component against applicable RAI principles and NIST AI RMF subcategories. Establish the evaluation framework used in Phases 3 and 4.

### Inputs

* System definition pack from Phase 1

### Process

The agent maps components against six RAI principles:

| Principle              | Focus area                                               |
|------------------------|----------------------------------------------------------|
| Fairness               | Bias detection, equitable outcomes, allocation harms     |
| Reliability and Safety | Consistent performance, failure modes, degradation paths |
| Privacy and Security   | Data protection, consent, inference prevention           |
| Inclusiveness          | Accessibility, diverse populations, language equity      |
| Transparency           | Explainability, disclosure, decision traceability        |
| Accountability         | Oversight mechanisms, audit trails, remediation channels |

For each principle-component pair, the agent identifies:

* Applicable NIST AI RMF subcategories
* Regulatory jurisdiction and framework obligations
* Existing compliance posture

The Researcher Subagent is dispatched for runtime lookups of specific regulatory frameworks (WAF, CAF, ISO 42001, EU AI Act) when the assessment requires detail beyond embedded standards.

### Outputs

* `rai-standards-mapping.md`: Principle-by-component mapping with NIST subcategory references and compliance gaps

### State Transitions

| Field             | Before | After |
|-------------------|--------|-------|
| `currentPhase`    | 2      | 3     |
| `standardsMapped` | false  | true  |

## Phase 3: RAI Security Model Analysis

> NIST AI RMF alignment: Measure

### Purpose

Identify AI-specific threats across all components using a structured threat taxonomy. Each threat receives a unique identifier and risk rating.

### Inputs

* System definition pack from Phase 1
* RAI standards mapping from Phase 2
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

Each threat receives an identifier in `RAI-T-{CATEGORY}-{NNN}` format. In `from-security-plan` mode, numbering continues from the security plan's threat count to maintain a unified threat registry.

### Severity Matrix

Risk is calculated using a likelihood-impact matrix:

| Likelihood \ Impact | Low    | Medium | High     | Critical |
|---------------------|--------|--------|----------|----------|
| Very likely         | Medium | High   | Critical | Critical |
| Likely              | Low    | Medium | High     | Critical |
| Possible            | Low    | Medium | Medium   | High     |
| Unlikely            | Low    | Low    | Medium   | Medium   |
| Rare                | Low    | Low    | Low      | Medium   |

### Outputs

* `rai-security-model-addendum.md`: Threat catalog with IDs, categories, descriptions, risk ratings, and recommended mitigations

### State Transitions

| Field                   | Before | After                       |
|-------------------------|--------|-----------------------------|
| `currentPhase`          | 3      | 4                           |
| `raiRiskSurfaceStarted` | false  | true                        |
| `raiThreatCount`        | 0      | count of identified threats |

## Phase 4: RAI Impact Assessment

> NIST AI RMF alignment: Manage

### Purpose

Evaluate control surface completeness for each identified threat. Document evidence of existing mitigations, identify gaps, and analyze tradeoffs between competing RAI principles.

### Inputs

* RAI security model addendum from Phase 3
* RAI standards mapping from Phase 2
* Evidence provided by the user or discovered in the codebase

### Process

For each threat identified in Phase 4, the agent evaluates:

* Whether a control or mitigation exists
* What evidence supports the control's effectiveness
* Whether the control introduces tradeoffs with other RAI principles
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
* `rai-tradeoffs.md`: Principle conflict analysis with resolution recommendations

### State Transitions

| Field                       | Before | After |
|-----------------------------|--------|-------|
| `currentPhase`              | 4      | 5     |
| `impactAssessmentGenerated` | false  | true  |
| `evidenceRegisterComplete`  | false  | true  |

## Phase 5: Review and Handoff

> NIST AI RMF alignment: Manage

### Purpose

Produce the RAI scorecard summarizing assessment quality across five scored dimensions. Generate backlog items for unresolved gaps and hand off to ADO or GitHub.

### Inputs

* All artifacts from Phases 1-4
* User preferences for backlog format and handoff system

### Process

The agent scores the assessment across five dimensions on a 1-5 scale:

| Dimension                   | What it measures                                                      |
|-----------------------------|-----------------------------------------------------------------------|
| Scope Boundary Clarity      | How well the AI system boundaries and components are defined          |
| Risk Identification Quality | Completeness and accuracy of threat identification                    |
| Control Surface Adequacy    | Coverage and effectiveness of controls for identified threats         |
| Evidence Sufficiency        | Quality and availability of evidence supporting control effectiveness |
| Future Work Governance      | Clarity of plans for ongoing monitoring, audit, and remediation       |

#### Scoring

* Each dimension: 1-5 scale
* Total: sum of all dimensions (maximum 25)
* Outcomes:
  * **Approved** (20-25): Assessment is comprehensive; proceed with identified mitigations
  * **Conditional** (15-19): Assessment has gaps; proceed with conditions and timeline for remediation
  * **Remediation Required** (below 15): Significant gaps identified; remediation before proceeding

### Backlog Generation

Gaps identified across Phases 2-4 are converted to work items using the same dual-platform format as the Security Planner:

* ADO work items use `WI-RAI-{NNN}` temporary IDs
* GitHub issues use `{{RAI-TEMP-N}}` temporary IDs
* Default autonomy tier is Partial: items are created but require user confirmation before submission

### Outputs

* `rai-scorecard.md`: Five-dimension scoring with total, outcome, and summary narrative
* Backlog items in the user's preferred format

### State Transitions

| Field                      | Before | After                                          |
|----------------------------|--------|------------------------------------------------|
| `currentPhase`             | 5      | 5 (terminal)                                   |
| `handoffGenerated`         | false  | true                                           |
| `scoredDimensions.*`       | null   | scored values                                  |
| `scoredDimensions.total`   | null   | sum                                            |
| `scoredDimensions.outcome` | null   | Approved, Conditional, or Remediation Required |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
