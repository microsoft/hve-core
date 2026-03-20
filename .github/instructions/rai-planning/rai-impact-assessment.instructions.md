---
description: 'RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Impact Assessment and Controls

Phase 5 evaluates control surface completeness for each identified threat, documents evidence of existing mitigations, identifies coverage gaps, and analyzes tradeoffs between competing RAI principles. This file defines the taxonomy, templates, and rules that govern those activities.

## Control Surface Taxonomy

The taxonomy maps six Microsoft RAI Standard v2 principles against three control types. Each cell represents a control surface that may contain one or more mitigations.

| Principle              | Prevent                                                              | Detect                                                              | Respond                                                     |
|------------------------|----------------------------------------------------------------------|---------------------------------------------------------------------|-------------------------------------------------------------|
| Fairness               | Bias testing, balanced training data, algorithmic audits             | Demographic parity monitoring, disparate impact alerts              | Retraining pipelines, model rollback, remediation workflows |
| Reliability and Safety | Input validation, adversarial robustness testing, failsafe defaults  | Drift detection, performance degradation alerts, anomaly monitoring | Graceful degradation, fallback models, incident response    |
| Privacy and Security   | Differential privacy, data minimization, access controls             | Data leakage detection, membership inference monitoring             | Breach response, data deletion, re-anonymization            |
| Inclusiveness          | Accessibility testing, diverse user research, multi-language support | Usage gap analysis, accessibility compliance monitoring             | Content adaptation, alternative interaction modes           |
| Transparency           | Model cards, explanation interfaces, decision audit trails           | Explanation quality monitoring, user comprehension testing          | Explanation correction, model documentation updates         |
| Accountability         | Role-based access, approval workflows, audit logging                 | Compliance monitoring, audit trail verification                     | Escalation procedures, corrective action tracking           |

### Prevent Controls

Prevent controls stop harm before it occurs. They apply during design, training, and deployment stages. Evaluate each prevent control against the threat it addresses and confirm that the control operates before the threat materializes.

### Detect Controls

Detect controls identify harm during operation. They apply after deployment through monitoring, alerting, and periodic assessment. Evaluate each detect control for coverage of the associated threat and confirm that detection latency meets acceptable thresholds.

### Respond Controls

Respond controls mitigate harm after detection. They apply through incident response, remediation pipelines, and corrective actions. Evaluate each respond control for time-to-remediation and confirm that response procedures are documented and tested.

## Evidence Register

The evidence register catalogs all mitigations, their coverage status, and supporting documentation. Each entry maps a control to the threat it addresses and the principle it serves.

### Evidence Fields

Each evidence entry requires these fields:

* Evidence ID: format `EV-{PRINCIPLE_ABBR}-{NNN}` where abbreviations are FAIR, REL, PRIV, INCL, TRAN, ACCT
* Threat ID: the `T-RAI-{NNN}` identifier from Phase 4 security model analysis
* Cross-Reference Threat ID: the `T-{BUCKET}-AI-{NNN}` identifier when a Security Planner threat exists
* Principle: one of the six MS RAI Standard v2 principles
* Control Type: Prevent, Detect, or Respond
* Control Description: what the mitigation does and how it operates
* Coverage Status: Full, Partial, or Gap
* Evidence Source: document, test result, audit log, or other artifact that demonstrates the control exists
* Verification Status: Verified, Unverified, Partially Verified, or N/A. Tracks whether the control has been tested and confirmed to work, distinct from Coverage Status which tracks whether the control exists.
* Notes: additional context including dependencies, assumptions, or known limitations

### Evidence Register Rules

* Assign a unique Evidence ID to every control entry.
* Reference exactly one Threat ID per entry. Controls that address multiple threats require separate entries.
* Set Coverage Status to Gap when no evidence source exists for the control.
* Review all Gap entries during work item generation.

### Evidence Summary Table

| Evidence ID | Threat ID | Principle              | Control Type | Coverage Status |
|-------------|-----------|------------------------|--------------|-----------------|
| EV-FAIR-001 | T-RAI-001 | Fairness               | Prevent      | Full            |
| EV-REL-001  | T-RAI-002 | Reliability and Safety | Detect       | Partial         |
| EV-PRIV-001 | T-RAI-003 | Privacy and Security   | Respond      | Gap             |

## Guardrail Verification Checklist

The guardrail verification checklist confirms that cataloged controls function as intended, not only that they exist. Walk through each category with the user and record verification findings in the evidence register using the Verification Status field.

### Input Guardrails

* Prompt injection filters: Are injection attempts detected and blocked before reaching the model? What test cases validate filter coverage?
* Input schema validation: Does the system enforce expected input formats, types, and length constraints? What happens when malformed input bypasses validation?
* Adversarial input detection: Are adversarial perturbations (jailbreaks, encoding tricks, indirect injection via retrieved content) tested against the system's input pipeline?

### Output Guardrails

* Content filters: Are output moderation filters active and tested against known harmful content categories? What is the false-positive rate?
* Grounding checks: Does the system verify that generated outputs are grounded in provided context? How are hallucinated claims detected?
* Output format validation: Are structured outputs validated against expected schemas before delivery to users or downstream systems?
* PII redaction: Does the system detect and redact personally identifiable information in outputs? What PII categories are covered and what detection method is used?

### Verification Recording

For each guardrail evaluated, update the corresponding evidence register entry:

* Set Verification Status to Verified when testing confirms the control works as documented.
* Set Verification Status to Partially Verified when some test cases pass but coverage is incomplete.
* Set Verification Status to Unverified when no testing has been performed.
* Create new evidence entries for guardrails discovered during verification that lack existing catalog entries.

## Appropriate Reliance Assessment

Appropriate reliance ensures users neither over-trust nor under-trust AI-generated outputs. This assessment evaluates whether the system's design calibrates user trust to match the system's actual reliability. Findings produce evidence register entries using the standard `EV-{PRINCIPLE_ABBR}-{NNN}` format under Reliability and Safety or Transparency principles.

### Trust Calibration

* How does the system communicate its confidence level for individual outputs? Are uncertainty indicators (confidence scores, probability ranges, hedging language) visible to users?
* When the system operates outside its training distribution or encounters novel inputs, does the interface signal reduced reliability?
* Do confidence indicators correlate with actual accuracy? Has calibration been measured?

### Human-in-the-Loop Design

* Which decisions require human review before the system takes action? Document the boundary between automated and human-gated decisions.
* For high-stakes outputs (safety-critical, financially significant, legally binding), what review checkpoints exist before action?
* Can users override or modify AI recommendations before they take effect?

### UX Patterns for AI Transparency

* Does the interface clearly communicate that outputs are AI-generated?
* Are the system's capabilities and limitations described where users encounter AI outputs?
* When the system produces explanations or reasoning, are those explanations faithful to the actual decision process?

### Over-Reliance Prevention

* What mechanisms prevent users from accepting AI outputs without critical evaluation? Consider friction patterns (confirmation steps, mandatory review periods) and cognitive prompts ("Did you verify this output?").
* Does the system present alternative outputs or counterarguments to encourage independent assessment?
* For repetitive tasks, does the interface vary its presentation to prevent automation complacency?

### Under-Reliance Detection

* How does the system detect when users systematically ignore AI recommendations? Are override rates or dismissal patterns monitored?
* When under-reliance is detected, what intervention is available (contextual guidance, accuracy demonstrations, workflow adjustments)?
* Is there a feedback mechanism for users to report why they distrust specific outputs?

## Fairness-Weighted Difficulty Assessment

The FWD assessment scores each threat-control pairing on two dimensions: difficulty of implementation and fairness impact. The product of these scores determines remediation priority.

### FWD Scoring

| Dimension                 | Score 1                               | Score 2                                     | Score 3                                  |
|---------------------------|---------------------------------------|---------------------------------------------|------------------------------------------|
| Implementation Difficulty | Low: standard tooling, minimal effort | Medium: custom development, moderate effort | High: novel research, significant effort |
| Fairness Impact           | Low: limited demographic effect       | Medium: measurable disparate impact         | High: systemic exclusion or harm         |

The combined FWD score ranges from 1 to 9. Higher scores indicate greater urgency.

| FWD Score Range | Priority |
|-----------------|----------|
| 7-9             | Critical |
| 4-6             | High     |
| 2-3             | Medium   |
| 1               | Low      |

### FWD Assessment Table

| Evidence ID | Threat ID | Implementation Difficulty | Fairness Impact | FWD Score |
|-------------|-----------|---------------------------|-----------------|-----------|
| EV-FAIR-001 | T-RAI-001 | 2                         | 3               | 6         |
| EV-REL-001  | T-RAI-002 | 1                         | 2               | 2         |

## Tradeoff Documentation

Tradeoffs arise when mitigating one RAI principle creates tension with another. Document each tradeoff with its competing principles, the decision rationale, and any compensating controls.

### Tradeoff Entry Template

Each tradeoff entry includes:

* Tradeoff ID: format `TO-{NNN}`
* Competing Principles: the two principles in tension
* Description: what creates the tension and why both principles cannot be fully satisfied simultaneously
* Decision: which principle takes priority and under what conditions
* Compensating Controls: mitigations that reduce the impact on the deprioritized principle
* Residual Risk: remaining exposure after compensating controls are applied

### Common Tradeoffs

#### TO-001: Privacy vs. Accuracy

Differential privacy techniques reduce model accuracy by adding noise to training data. In systems where prediction accuracy affects safety, this tradeoff requires explicit threshold negotiation between privacy guarantees and acceptable accuracy loss.

#### TO-002: Interpretability vs. Performance

Simpler, interpretable models often underperform complex models. When transparency requirements mandate explainable outputs, document the performance delta and confirm that the accuracy reduction falls within acceptable bounds.

#### TO-003: Fairness vs. Complexity

Fairness constraints (demographic parity, equalized odds) increase model complexity and may reduce overall accuracy. Document the specific fairness metric chosen, the accuracy impact, and the stakeholder approval for the selected operating point.

#### TO-004: Safety vs. Utility

Conservative safety thresholds (input filtering, output clamping) reduce system utility by rejecting valid inputs or constraining outputs. Document the threshold values, false-positive rates, and conditions under which thresholds may be adjusted.

#### TO-005: Transparency vs. Security

Detailed model explanations can expose proprietary logic or create adversarial attack vectors. When explanation depth conflicts with security requirements, document the information boundary and the approved level of explanation granularity.

#### TO-006: Monitoring vs. Privacy

Comprehensive monitoring generates usage data that may conflict with data minimization requirements. Document the monitoring scope, data retention policies, and any anonymization applied to monitoring outputs.

## Per-Principle Rubrics

Score each principle from 1 to 5 based on control surface coverage, evidence completeness, and tradeoff documentation. The rubric below defines thresholds for each score level.

| Score | Fairness                                                          | Reliability and Safety                                                          | Privacy and Security                                                      | Inclusiveness                                                                 | Transparency                                                                                   | Accountability                                                                             |
|-------|-------------------------------------------------------------------|---------------------------------------------------------------------------------|---------------------------------------------------------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| 1     | No bias testing or fairness metrics defined                       | No input validation or failsafe mechanisms                                      | No privacy controls or data minimization                                  | No accessibility testing or diverse user research                             | No model documentation or explanation capability                                               | No audit logging or approval workflows                                                     |
| 2     | Bias testing planned but not yet executed                         | Basic input validation only                                                     | Data minimization policy exists but is not enforced                       | Accessibility guidelines documented but not tested                            | Model card exists but lacks explanation interfaces                                             | Audit logging exists but is not monitored                                                  |
| 3     | Bias testing executed with partial demographic coverage           | Input validation and basic drift detection in place                             | Data minimization enforced with periodic access reviews                   | Accessibility testing on primary interaction modes                            | Model card and basic explanation interface available                                           | Audit logging with periodic review cycles                                                  |
| 4     | Comprehensive bias testing with ongoing monitoring                | Full input validation, drift detection, and anomaly alerts                      | Differential privacy applied with continuous monitoring                   | Multi-modal accessibility tested with diverse user groups                     | Detailed model card, explanation interface, and decision trails                                | Role-based access with automated compliance monitoring                                     |
| 5     | Continuous fairness monitoring with automated retraining triggers | Adversarial robustness testing, failsafe defaults, and tested incident response | Full privacy stack with breach response tested and data deletion verified | Inclusive design validated through ongoing diverse user research and feedback | Complete transparency stack with user comprehension testing and explanation quality monitoring | Full accountability chain with escalation procedures tested and corrective actions tracked |

### Scoring Rules

* Score each principle independently based on the rubric thresholds.
* Use evidence from the evidence register to justify the assigned score.
* A score of 3 represents the minimum acceptable baseline for production deployment.
* Principles scoring below 3 require work items with Critical or High priority.
* Document the rationale for each score in the assessment output.

## Work Item Generation

Generate work items from the evidence register for entries with Coverage Status of Gap or Partial and for principles scoring below 3 on the rubric.

### Generation Rules

* Create one work item per evidence register entry with Coverage Status of Gap.
* Create one work item per evidence register entry with Coverage Status of Partial when the associated principle scores below 3.
* Include the Evidence ID, Threat ID, Principle, Control Type, and Control Description in the work item body.
* Reference the Tradeoff ID when the work item involves a documented tradeoff.
* Map the FWD score to the priority using the FWD priority table.

### Priority Mapping

| FWD Score Range | Work Item Priority                     |
|-----------------|----------------------------------------|
| 7-9             | Critical: address before deployment    |
| 4-6             | High: address within current iteration |
| 2-3             | Medium: schedule for next iteration    |
| 1               | Low: add to backlog                    |

### Work Item Fields

* Title: `[RAI] {Principle}: {Control Description summary}`
* Priority: mapped from FWD score
* Evidence ID: the associated evidence register entry
* Threat ID: the associated threat from Phase 4
* Principle: the RAI principle
* Control Type: Prevent, Detect, or Respond
* Acceptance Criteria: the condition that moves Coverage Status from Gap or Partial to Full

## Artifact Templates

Phase 5 produces three artifacts. Use these templates to structure the output files.

### Control Surface Catalog

The control surface catalog documents all evaluated controls per principle and control type.

```markdown
---
title: Control Surface Catalog
rai-plan: '{plan-id}'
phase: 5
---

# Control Surface Catalog

## {Principle}

### Prevent

* {Control Description} (Coverage: {Full|Partial|Gap})

### Detect

* {Control Description} (Coverage: {Full|Partial|Gap})

### Respond

* {Control Description} (Coverage: {Full|Partial|Gap})

<!-- Repeat for each principle -->
```

### Evidence Register

The evidence register artifact provides the full listing of all evidence entries with supporting details.

```markdown
---
title: Evidence Register
rai-plan: '{plan-id}'
phase: 5
---

# Evidence Register

| Evidence ID | Threat ID   | Cross-Ref ID      | Principle   | Control Type | Control Description | Coverage | Evidence Source | Verification | Notes   |
|-------------|-------------|-------------------|-------------|--------------|---------------------|----------|-----------------|--------------|---------|
| {EV-ID}     | {T-RAI-NNN} | {T-BUCKET-AI-NNN} | {Principle} | {Type}       | {Description}       | {Status} | {Source}        | {Status}     | {Notes} |
```

### RAI Tradeoffs

The tradeoff artifact documents all identified tensions between principles and the decisions made to resolve them.

```markdown
---
title: RAI Tradeoffs
rai-plan: '{plan-id}'
phase: 5
---

# RAI Tradeoffs

## {TO-NNN}: {Principle A} vs. {Principle B}

* Competing Principles: {Principle A}, {Principle B}
* Description: {what creates the tension}
* Decision: {which principle takes priority and conditions}
* Compensating Controls: {mitigations for the deprioritized principle}
* Residual Risk: {remaining exposure}
```
