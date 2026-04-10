---
description: 'RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Impact Assessment and Controls

Phase 5 evaluates control surface completeness for each identified threat, documents evidence of existing mitigations, identifies coverage gaps, and analyzes tradeoffs between competing trustworthiness characteristics. This file defines the taxonomy, templates, and rules that govern those activities.

## Control Surface Taxonomy

The taxonomy maps seven NIST AI RMF 1.0 trustworthiness characteristics against three control types. Each cell represents a control surface that may contain one or more mitigations.

| Characteristic                  | Prevent                                                                                    | Detect                                                                                  | Respond                                                                                       |
|---------------------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| Valid and Reliable              | Input validation, adversarial robustness testing, failsafe defaults                        | Drift detection, performance degradation alerts, anomaly monitoring                     | Graceful degradation, fallback models, incident response                                      |
| Safe                            | Safety boundary enforcement, hazard analysis, fail-safe design                             | Safety event monitoring, operational limit alerts                                       | Emergency shutdown procedures, safety incident response                                       |
| Secure and Resilient            | Differential privacy, data minimization, access controls, adversarial robustness           | Data leakage detection, membership inference monitoring, intrusion detection            | Breach response, data deletion, re-anonymization, system recovery                             |
| Accountable and Transparent     | Model cards, decision audit trails, role-based access, approval workflows                  | Compliance monitoring, audit trail verification, explanation quality monitoring          | Escalation procedures, corrective action tracking, documentation updates                      |
| Explainable and Interpretable   | Explanation interfaces, interpretable model selection, decision documentation               | User comprehension testing, explanation fidelity monitoring                             | Explanation correction, model documentation updates                                           |
| Privacy-Enhanced                | Differential privacy, data minimization, consent management, PII controls                  | Data leakage detection, membership inference monitoring, consent compliance             | Breach response, data deletion, re-anonymization, consent revocation                          |
| Fair with Harmful Bias Managed  | Bias testing, balanced training data, algorithmic audits, demographic analysis              | Demographic parity monitoring, disparate impact alerts, usage gap analysis              | Retraining pipelines, model rollback, remediation workflows, content adaptation               |

### Prevent Controls

Prevent controls stop harm before it occurs. They apply during design, training, and deployment stages. Evaluate each prevent control against the threat it addresses and confirm that the control operates before the threat materializes.

### Detect Controls

Detect controls identify harm during operation. They apply after deployment through monitoring, alerting, and periodic assessment. Evaluate each detect control for coverage of the associated threat and confirm that detection latency meets acceptable thresholds.

### Respond Controls

Respond controls mitigate harm after detection. They apply through incident response, remediation pipelines, and corrective actions. Evaluate each respond control for time-to-remediation and confirm that response procedures are documented and tested.

## Evidence Register

The evidence register catalogs all mitigations, their coverage status, and supporting documentation. Each entry maps a control to the threat it addresses and the characteristic it serves.

### Evidence Fields

Each evidence entry requires these fields:

* Evidence ID: format `EV-{CHARACTERISTIC_ABBR}-{NNN}` where abbreviations are VR, SAFE, SR, AT, EI, PRIV, FAIR
* Threat ID: the `T-RAI-{NNN}` identifier from Phase 4 security model analysis
* Cross-Reference Threat ID: the `T-{BUCKET}-AI-{NNN}` identifier when a Security Planner threat exists
* Characteristic: one of the seven NIST AI RMF 1.0 trustworthiness characteristics
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

### Output Detail Levels

When `userPreferences.outputDetailLevel` is set, adjust the evidence register output:

* **summary** - Evidence register captures Evidence ID, Evidence Source, and one-line summary per entry.
* **standard** - Default behavior. Full evidence fields as defined above.
* **comprehensive** - Full evidence register plus chain-of-custody tracking (who provided the evidence, when, and verification chain) and cross-references to external documents.

### Evidence Summary Table

| Evidence ID  | Threat ID | Characteristic                  | Control Type | Coverage Status |
|--------------|-----------|----------------------------------|--------------|------------------|
| EV-FAIR-001  | T-RAI-001 | Fair with Harmful Bias Managed  | Prevent      | Full            |
| EV-VR-001    | T-RAI-002 | Valid and Reliable              | Detect       | Partial         |
| EV-PRIV-001  | T-RAI-003 | Privacy-Enhanced                | Respond      | Gap             |

## Guardrail Verification Checklist

The guardrail verification checklist evaluates whether cataloged controls function as intended, not only that they exist. Walk through each category with the user and record verification findings in the evidence register using the Verification Status field.

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

Appropriate reliance helps ensure users neither over-trust nor under-trust AI-generated outputs. This assessment evaluates whether the system's design calibrates user trust to match the system's actual reliability. Findings produce evidence register entries using the standard `EV-{CHARACTERISTIC_ABBR}-{NNN}` format under Valid and Reliable or Accountable and Transparent characteristics.

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

## Suggested Priority Derivation

Priority is derived from the combination of concern levels, trigger severity, and principleTracker observations. Never derive priority from numerical scores.

### Priority Levels

| Priority  | Criteria                                                                                                                                                        | Suggested Action                            |
|-----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| Immediate | Prohibited use trigger fired, or High concern level on safety-critical threat, or multiple characteristics show Foundational maturity | Warrants prompt attention before deployment |
| Near-term | Moderate concern level with partial control coverage, or single characteristic shows Foundational maturity                            | Recommended for upcoming development cycles |
| Planned   | Low-to-Moderate concern level with identified improvement opportunities                                                                 | Consider for future iterations              |
| Backlog   | Low concern level with existing controls in place                                                                                       | Note for long-term consideration            |

### Derivation Rules

* Prohibited use triggers (from Phase 2 risk classification screening) automatically suggest Immediate priority.
* Concern levels from Phase 4 security model inform priority: High concern → Immediate or Near-term; Moderate concern → Near-term or Planned; Low concern → Planned or Backlog.
* principleTracker observations provide supporting evidence for priority selection.
* When multiple signals conflict, select the higher priority and document the reasoning.
* Present all priorities as suggestions for user review - the user makes final priority decisions.

## Tradeoff Documentation

Tradeoffs arise when mitigating one trustworthiness characteristic creates tension with another. Document each tradeoff with its competing characteristics, the decision rationale, and any compensating controls.

### Tradeoff Entry Template

Each tradeoff entry includes:

* Tradeoff ID: format `TO-{NNN}`
* Competing Characteristics: the two characteristics in tension
* Description: what creates the tension and why both characteristics cannot be fully satisfied simultaneously
* Decision: which characteristic takes priority and under what conditions
* Compensating Controls: mitigations that reduce the impact on the deprioritized characteristic
* Residual Risk: remaining exposure after compensating controls are applied

### Audience Adaptation

When `userPreferences.audienceProfile` is set, adjust tradeoff presentation:

* **technical** - Detailed tradeoff analysis with implementation implications, code-level control descriptions, and specific metric thresholds.
* **executive** - High-level tradeoff summary with business impact focus, risk-to-opportunity framing, and strategic recommendations.
* **mixed** - Tradeoff documentation with regulatory mapping and contextual notes accessible to diverse audiences.

### Common Tradeoffs

#### TO-001: Privacy-Enhanced vs. Valid and Reliable

Differential privacy techniques reduce model accuracy by adding noise to training data. In systems where prediction accuracy affects safety, this tradeoff requires explicit threshold negotiation between privacy guarantees and acceptable accuracy loss.

#### TO-002: Explainable and Interpretable vs. Valid and Reliable

Simpler, interpretable models often underperform complex models. When explainability requirements mandate transparent outputs, document the performance delta and confirm that the accuracy reduction falls within acceptable bounds.

#### TO-003: Fair with Harmful Bias Managed vs. Valid and Reliable

Fairness constraints (demographic parity, equalized odds) increase model complexity and may reduce overall accuracy. Document the specific fairness metric chosen, the accuracy impact, and the stakeholder approval for the selected operating point.

#### TO-004: Safe vs. Valid and Reliable

Conservative safety thresholds (input filtering, output clamping) reduce system utility by rejecting valid inputs or constraining outputs. Document the threshold values, false-positive rates, and conditions under which thresholds may be adjusted.

#### TO-005: Accountable and Transparent vs. Secure and Resilient

Detailed model explanations and audit trails can expose proprietary logic or create adversarial attack vectors. When accountability depth conflicts with security requirements, document the information boundary and the approved level of explanation granularity.

#### TO-006: Secure and Resilient vs. Privacy-Enhanced

Comprehensive security monitoring generates usage data that may conflict with data minimization requirements. Document the monitoring scope, data retention policies, and any anonymization applied to monitoring outputs.

#### TO-007: Explainable and Interpretable vs. Secure and Resilient

Deep explanation outputs can reveal model internals or decision boundaries that adversaries exploit. When explanation depth creates security exposure, document the approved explanation granularity and any redaction applied to sensitive model details.

## Per-Characteristic Maturity Indicators

Assess each characteristic's maturity based on evidence gathered during the session. Select the indicator that best describes the current state and document observations supporting the selection in the principleTracker.

### Valid and Reliable Maturity Indicators

* **Foundational** - Basic awareness exists; no formal validation or reliability testing.
* **Developing** - Basic input validation in place; reliability testing planned but not yet operational.
* **Established** - Full validation, drift detection, and anomaly alerts operational; regular testing cycles.
* **Advanced** - Adversarial robustness testing, failsafe defaults, and tested incident response; continuous improvement active.

### Safe Maturity Indicators

* **Foundational** - Basic awareness exists; no formal safety analysis or hazard identification.
* **Developing** - Safety boundaries documented; hazard analysis planned.
* **Established** - Safety boundaries enforced with operational monitoring; regular review cycles.
* **Advanced** - Continuous safety monitoring with automated enforcement and tested emergency procedures.

### Secure and Resilient Maturity Indicators

* **Foundational** - Basic awareness exists; no formal security controls or resilience testing.
* **Developing** - Security controls partially implemented; resilience testing planned.
* **Established** - Security controls enforced with periodic reviews; resilience testing operational.
* **Advanced** - Full security stack with breach response tested and recovery validated; continuous monitoring active.

### Accountable and Transparent Maturity Indicators

* **Foundational** - Basic awareness exists; no formal audit logging, model documentation, or approval workflows.
* **Developing** - Audit logging exists; model card planned; role-based access partially implemented.
* **Established** - Detailed model card, audit trails, and compliance monitoring available; regular updates.
* **Advanced** - Full accountability chain with transparency stack, user comprehension testing, and corrective action tracking; continuous improvement active.

### Explainable and Interpretable Maturity Indicators

* **Foundational** - Basic awareness exists; no formal explanation capability or interpretability requirements.
* **Developing** - Basic explanation interface planned; interpretability requirements documented.
* **Established** - Explanation interface operational with fidelity monitoring; regular quality reviews.
* **Advanced** - Complete explainability stack with user comprehension testing and explanation quality monitoring; continuous improvement active.

### Privacy-Enhanced Maturity Indicators

* **Foundational** - Basic awareness exists; no formal privacy controls or data minimization.
* **Developing** - Data minimization policy exists; consent management partially implemented.
* **Established** - Privacy controls enforced with periodic access reviews; monitoring in place.
* **Advanced** - Full privacy stack with breach response tested and data deletion verified; continuous monitoring active.

### Fair with Harmful Bias Managed Maturity Indicators

* **Foundational** - Basic awareness exists; no formal bias testing or fairness metrics defined.
* **Developing** - Some bias testing planned or executed with partial demographic coverage; gaps remain.
* **Established** - Comprehensive bias testing with ongoing monitoring; regular review cycles in place.
* **Advanced** - Continuous fairness monitoring with automated processes; industry-leading practices active.

### Assessment Rules

* Assess each characteristic independently based on evidence from the evidence register and session observations.
* Document the rationale for each maturity level in the principleTracker.
* Characteristics at the Foundational level suggest work items with Immediate or Near-term priority.
* When presenting maturity level assessments, explain the reasoning by citing specific observations from the session. Do not present bare maturity levels without supporting evidence.

## Work Item Generation

Generate work items from the evidence register for entries with Coverage Status of Gap, and for entries with Coverage Status of Partial when the associated characteristic is at Foundational maturity level.

### Generation Rules

* Create one work item per evidence register entry with Coverage Status of Gap.
* Create one work item per evidence register entry with Coverage Status of Partial when the associated characteristic is at Foundational maturity level based on principleTracker observations.
* Include the Evidence ID, Threat ID, Characteristic, Control Type, and Control Description in the work item body.
* Reference the Tradeoff ID when the work item involves a documented tradeoff.
* Derive the suggested priority using the Suggested Priority Derivation rules from the priority section above.

### Work Item Fields

* Title: `[RAI] {Characteristic}: {Control Description summary}`
* Suggested Priority: derived from concern levels, trigger severity, and principleTracker observations
* Evidence ID: the associated evidence register entry
* Threat ID: the associated threat from Phase 4
* Characteristic: the trustworthiness characteristic
* Control Type: Prevent, Detect, or Respond
* Acceptance Criteria: the condition that moves Coverage Status from Gap or Partial to Full
* Suggested Remediation Horizon: Pre-Production, Early Operations, or Ongoing Governance

### Suggested Remediation Horizons

| Horizon            | Description                            | Typical Triggers                                                          |
|--------------------|----------------------------------------|---------------------------------------------------------------------------|
| Pre-Production     | Address before initial deployment      | Safety-critical controls, prohibited use gates, Immediate priority items  |
| Early Operations   | Address within first operational cycle | Monitoring controls, user feedback loops, Near-term priority items        |
| Ongoing Governance | Continuous improvement items           | Process refinement, training updates, Planned or Backlog priority items   |

### Horizon Derivation Rules

* Safety-critical controls and controls associated with prohibited use triggers → Pre-Production.
* Monitoring, detection, and feedback controls → Early Operations.
* Process, governance, and training controls → Ongoing Governance.
* When the horizon is uncertain, default to Early Operations with a note explaining the ambiguity.
* Present all horizon suggestions as recommendations for user review.

## Artifact Templates

Phase 5 produces three artifacts. Use these templates to structure the output files.

### Control Surface Catalog

The control surface catalog documents all evaluated controls per characteristic and control type.

```markdown
---
title: Control Surface Catalog
rai-plan: '{plan-id}'
phase: 5
---

# Control Surface Catalog

## {Characteristic}

### Prevent

* {Control Description} (Coverage: {Full|Partial|Gap})

### Detect

* {Control Description} (Coverage: {Full|Partial|Gap})

### Respond

* {Control Description} (Coverage: {Full|Partial|Gap})

<!-- Repeat for each characteristic -->

> **Note** - The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
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

| Evidence ID | Threat ID   | Cross-Ref ID      | Characteristic   | Control Type | Control Description | Coverage | Evidence Source | Verification | Notes   |
|-------------|-------------|-------------------|------------------|--------------|---------------------|----------|-----------------|--------------|---------|
| {EV-ID}     | {T-RAI-NNN} | {T-BUCKET-AI-NNN} | {Characteristic} | {Type}       | {Description}       | {Status} | {Source}        | {Status}     | {Notes} |

> **Note** - The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
```

### RAI Tradeoffs

The tradeoff artifact documents all identified tensions between characteristics and the decisions made to resolve them.

```markdown
---
title: RAI Tradeoffs
rai-plan: '{plan-id}'
phase: 5
---

# RAI Tradeoffs

## {TO-NNN}: {Characteristic A} vs. {Characteristic B}

* Competing Characteristics: {Characteristic A}, {Characteristic B}
* Description: {what creates the tension}
* Decision: {which characteristic takes priority and conditions}
* Compensating Controls: {mitigations for the deprioritized characteristic}
* Residual Risk: {remaining exposure}

> **Note** - The author created this content with assistance from AI. All outputs should be reviewed and validated before use.
> - [ ] Reviewed and validated by a human reviewer
```
