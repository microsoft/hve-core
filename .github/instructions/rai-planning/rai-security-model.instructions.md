---
description: 'RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Security Model Analysis

AI-specific security model analysis extensions for Phase 4 of the RAI Planner. This guidance extends the STRIDE methodology with NIST trustworthiness characteristic overlaps, AI element types, trust boundaries, data flow patterns, and a dual threat ID convention. A merge protocol enables interoperation with Security Planner security models when operating in `from-security-plan` mode.

## AI STRIDE Extensions

Standard STRIDE categories gain AI-specific dimensions when applied to AI systems. Each category maps to one or more NIST trustworthiness characteristics that amplify the threat surface beyond traditional software concerns.

| STRIDE Category        | NIST Characteristic Overlay                                | AI-Specific Threat Examples                                                                     |
|------------------------|------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| Spoofing               | Valid and Reliable, Explainable and Interpretable          | Adversarial inputs mimicking legitimate data, model impersonation, synthetic identity injection |
| Tampering              | Fair with Harmful Bias Managed, Valid and Reliable         | Training data poisoning introducing bias, model weight manipulation, feedback loop corruption   |
| Repudiation            | Accountable and Transparent, Explainable and Interpretable | Unattributable automated decisions, audit log gaps for model outputs, governance bypass         |
| Information Disclosure | Privacy-Enhanced                                           | Training data extraction, model inversion attacks, membership inference, embedding leakage      |
| Denial of Service      | Valid and Reliable                                         | Model resource exhaustion, inference throttling attacks, adversarial input causing degradation  |
| Elevation of Privilege | Privacy-Enhanced, Valid and Reliable                       | Prompt injection bypassing safety filters, jailbreaking, unauthorized model capability access   |

## AI Element Types

Eight AI-specific element types define the components subject to RAI threat analysis. Each element type carries primary NIST concerns that guide threat identification.

| Element Type         | Description                             | Primary NIST Concerns                                                                                   |
|----------------------|-----------------------------------------|---------------------------------------------------------------------------------------------------------|
| Training Data Store  | Datasets used for model training        | Fair with Harmful Bias Managed (bias), Privacy-Enhanced (PII), Accountable and Transparent (provenance) |
| Model Artifact       | Trained model files and weights         | Valid and Reliable (integrity), Explainable and Interpretable (explainability)                          |
| Inference Endpoint   | API or service serving predictions      | Valid and Reliable (availability), Privacy-Enhanced (query privacy)                                     |
| Feature Pipeline     | Data transformation for model input     | Fair with Harmful Bias Managed (feature bias), Privacy-Enhanced (data flow)                             |
| Feedback Loop        | User feedback incorporated into model   | Fair with Harmful Bias Managed (feedback bias), Valid and Reliable (drift)                              |
| Human Review Queue   | Human oversight checkpoints             | Accountable and Transparent (review coverage), Explainable and Interpretable (decision documentation)   |
| Monitoring Dashboard | Model performance and behavior tracking | Explainable and Interpretable (observability), Valid and Reliable (alerting)                            |
| Orchestration Layer  | Agent or pipeline orchestration         | Accountable and Transparent (decision routing), Valid and Reliable (failure handling)                   |

## AI Trust Boundaries

Five trust boundaries plus one accountability-specific boundary define separation points within AI systems. Threats concentrate at these boundaries where control transfers between domains.

| Trust Boundary                              | Description                                                            | Key RAI Threats                                                    |
|---------------------------------------------|------------------------------------------------------------------------|--------------------------------------------------------------------|
| Training Data Boundary                      | Separation between raw data sources and training pipeline              | Data poisoning, bias injection, privacy violations                 |
| Model Boundary                              | Separation between model internals and serving infrastructure          | Model extraction, weight tampering, IP leakage                     |
| Inference Boundary                          | Separation between client requests and model processing                | Adversarial inputs, prompt injection, resource exhaustion          |
| Feedback Boundary                           | Separation between user feedback and model updates                     | Feedback manipulation, drift injection, bias amplification         |
| Human Oversight Boundary                    | Separation between automated decisions and human review                | Accountability gaps, automation bias, review bypass                |
| Human Review to Automated Decision Boundary | Accountability boundary between human judgment and automated execution | Accountability transfer, decision attribution, override governance |

> [!NOTE]
> The Human Review to Automated Decision Boundary is specifically an accountability boundary. It captures the transfer of responsibility when automated systems act on human review decisions, creating a distinct threat surface for decision attribution and override governance.

## AI Data Flow Patterns

Three data flow patterns characterize how data moves through AI systems. Each pattern identifies RAI-relevant stages and threat concentration points where targeted analysis yields the highest return.

### Training Pipeline Flow

Data source -> Feature extraction -> Training -> Model store -> Validation

RAI-relevant stages:

* Data source ingestion: bias in source data, PII exposure, provenance gaps
* Feature extraction: feature selection bias, proxy variable introduction
* Training: overfitting to biased patterns, memorization of sensitive data
* Model store: weight integrity, access control, version lineage
* Validation: evaluation fairness across demographic groups, holdout contamination

Threat concentration points: data source ingestion (poisoning, bias), training (memorization, bias amplification), validation (evaluation fairness gaps).

### Inference Pipeline Flow

Client request -> Pre-processing -> Model inference -> Post-processing -> Response

RAI-relevant stages:

* Client request: adversarial input detection, prompt injection screening
* Pre-processing: input sanitization, feature normalization integrity
* Model inference: output correctness, confidence calibration, latency stability
* Post-processing: content filtering, output explanation generation
* Response: attribution metadata, audit logging, response integrity

Threat concentration points: client request (adversarial inputs, prompt injection), model inference (output manipulation), post-processing (filter bypass).

### Feedback Loop Flow

User interaction -> Feedback collection -> Aggregation -> Model update trigger -> Retraining

RAI-relevant stages:

* User interaction: feedback authenticity, sampling bias in respondents
* Feedback collection: consent and privacy compliance, feedback representation
* Aggregation: statistical bias in aggregation methods, outlier handling
* Model update trigger: drift detection, update authorization
* Retraining: bias amplification across cycles, catastrophic forgetting

Threat concentration points: feedback collection (manipulation, bias), aggregation (statistical bias), retraining (bias amplification, drift injection).

## Dual Threat ID Convention

RAI security model analysis uses a dual ID system that enables independent tracking within the RAI plan and cross-referencing with Security Planner operational buckets.

### ID Formats

* `T-RAI-{NNN}`: Sequential RAI-specific threat identifier starting at T-RAI-001. Every RAI threat receives this ID.
* `T-{BUCKET}-AI-{NNN}`: Cross-reference ID mapping to Security Planner bucket terminology. Assigned when a threat overlaps with a Security Planner operational bucket.

### Rules

1. All RAI threats receive a `T-RAI-{NNN}` ID in sequential order.
2. When a threat overlaps with a Security Planner bucket, also assign a `T-{BUCKET}-AI-{NNN}` ID.
3. Cross-reference both IDs in threat tables so each threat is traceable across both plans.
4. Bucket names match Security Planner operational buckets: DATA, BUILD, WEBUI, IDENTITY, INFRA.
5. The `T-RAI-{NNN}` sequence is independent of the `T-{BUCKET}-AI-{NNN}` sequence within each bucket.

### Example

A training data poisoning threat might carry:

* RAI ID: `T-RAI-003`
* Security cross-reference: `T-DATA-AI-001`

Both IDs appear in the extended threat table, linking the RAI assessment to the security plan's data bucket analysis.

## Extended Threat Table Format

The threat table extends the Security Planner format with five additional columns: RAI ID, NIST Characteristic, NIST AI RMF, Suggested Threat Origin, and Concern Level.

```markdown
| Threat ID     | RAI ID    | STRIDE    | NIST Characteristic            | NIST AI RMF | Description                                          | AI Element          | Trust Boundary         | Suggested Threat Origin | Concern Level | Mitigation                                                    |
|---------------|-----------|-----------|--------------------------------|-------------|------------------------------------------------------|---------------------|------------------------|-------------------------|---------------|---------------------------------------------------------------|
| T-DATA-AI-001 | T-RAI-003 | Tampering | Fair with Harmful Bias Managed | Map 2.3     | Training data poisoning introducing demographic bias | Training Data Store | Training Data Boundary | Data Pipeline           | High Concern  | Data validation pipeline, bias detection, provenance tracking |
```

### Column Definitions

* Threat ID: Security Planner cross-reference ID (`T-{BUCKET}-AI-{NNN}`), or blank if no bucket overlap exists.
* RAI ID: Sequential RAI threat identifier (`T-RAI-{NNN}`).
* STRIDE: Applicable STRIDE category.
* NIST Characteristic: Primary NIST trustworthiness characteristic affected (Valid and Reliable, Safe, Secure and Resilient, Accountable and Transparent, Explainable and Interpretable, Privacy-Enhanced, Fair with Harmful Bias Managed).
* NIST AI RMF: Applicable NIST AI RMF subcategory reference.
* Description: Clear description of the threat, attack vector, and affected behavior.
* AI Element: Element type from the AI Element Types table.
* Trust Boundary: Boundary crossed or affected from the AI Trust Boundaries table.
* Suggested Threat Origin: Where the threat originates (Data Pipeline, Model, Interface, Infrastructure, or Cross-cutting).
* Concern Level: Qualitative assessment of threat significance (Low Concern, Moderate Concern, or High Concern). See Concern Level Assessment below for criteria.
* Mitigation: Proposed mitigation strategy with standards references.

### Concern Level Assessment

Suggest a qualitative concern level for each identified threat based on contextual judgment:

| Concern Level    | Criteria                                                                                |
|------------------|-----------------------------------------------------------------------------------------|
| Low Concern      | Threat is theoretical or mitigated by existing controls; no immediate action suggested. |
| Moderate Concern | Threat is plausible and partially mitigated; additional controls recommended.           |
| High Concern     | Threat is likely or unmitigated; priority mitigation suggested.                         |

The concern level is a suggested assessment for the team's consideration, not a definitive risk rating.

### Threat Origin Grouping

After populating the threat table, present a summary grouped by Suggested Threat Origin. This helps the team identify which system components carry the most threats and prioritize architectural mitigations. Present AI-specific threats (Data Pipeline, Model) first, then Interface threats, then Infrastructure and Cross-cutting threats.

### Output Detail Level

Adjust threat table column visibility based on `userPreferences.outputDetailLevel`:

| Level         | Visible Columns                                                                                                                           |
|---------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| summary       | RAI ID, STRIDE, Concern Level, Suggested Threat Origin.                                                                                   |
| standard      | All columns (default).                                                                                                                    |
| comprehensive | All columns plus a "Detailed Rationale" column with per-threat analysis explaining the concern level assignment and mitigation reasoning. |

### Audience Adaptation

Adjust ML STRIDE matrix presentation based on `userPreferences.audienceProfile`:

| Profile   | Presentation                                                                                    |
|-----------|-------------------------------------------------------------------------------------------------|
| technical | Include the full ML STRIDE matrix.                                                              |
| executive | Summarize ML-specific threats in narrative prose; omit the matrix.                              |
| mixed     | Include the matrix with regulatory cross-references and contextual notes for diverse audiences. |

## ML STRIDE Matrix

Extended matrix covering AI system components with NIST trustworthiness characteristic annotations. Each cell contains threat applicability (High/Medium/Low/N/A) and the primary NIST characteristic relevant to that intersection.

> [!NOTE]
> The STRIDE categories in this matrix (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege) correspond to the AI-extended definitions in the AI STRIDE Extensions table above. Refer to that table for AI-specific threat examples and NIST characteristic overlays for each category.

| Component        | Spoofing                                | Tampering                             | Repudiation                            | Info Disclosure                        | DoS                         | EoP                                     |
|------------------|-----------------------------------------|---------------------------------------|----------------------------------------|----------------------------------------|-----------------------------|-----------------------------------------|
| Training Data    | Medium / Valid and Reliable             | High / Fair with Harmful Bias Managed | Medium / Accountable and Transparent   | High / Privacy-Enhanced                | Low / Valid and Reliable    | Low / Privacy-Enhanced                  |
| Feature Pipeline | Low / Explainable and Interpretable     | High / Fair with Harmful Bias Managed | Medium / Accountable and Transparent   | Medium / Privacy-Enhanced              | Low / Valid and Reliable    | Low / Fair with Harmful Bias Managed    |
| Model Training   | Medium / Valid and Reliable             | High / Fair with Harmful Bias Managed | High / Accountable and Transparent     | High / Privacy-Enhanced                | Medium / Valid and Reliable | Medium / Valid and Reliable             |
| Model Serving    | High / Valid and Reliable               | Medium / Valid and Reliable           | Medium / Explainable and Interpretable | High / Privacy-Enhanced                | High / Valid and Reliable   | High / Valid and Reliable               |
| Inference API    | High / Valid and Reliable               | High / Valid and Reliable             | Medium / Explainable and Interpretable | Medium / Privacy-Enhanced              | High / Valid and Reliable   | High / Privacy-Enhanced                 |
| Feedback Loop    | Medium / Fair with Harmful Bias Managed | High / Fair with Harmful Bias Managed | High / Accountable and Transparent     | Medium / Privacy-Enhanced              | Low / Valid and Reliable    | Medium / Fair with Harmful Bias Managed |
| Human Review     | Low / Accountable and Transparent       | Medium / Accountable and Transparent  | High / Accountable and Transparent     | Low / Privacy-Enhanced                 | N/A                         | Medium / Accountable and Transparent    |
| Model Monitoring | Low / Explainable and Interpretable     | Medium / Valid and Reliable           | High / Explainable and Interpretable   | Medium / Explainable and Interpretable | Medium / Valid and Reliable | Low / Valid and Reliable                |

### Reading the Matrix

Each cell uses the format `Applicability / NIST Characteristic`:

* Applicability indicates how likely the STRIDE category applies to the component (High, Medium, Low, N/A).
* NIST Characteristic identifies which NIST trustworthiness characteristic is most relevant for that specific threat intersection.
* Use this matrix as a starting point for threat identification. Investigate all High-applicability cells first, then Medium, then Low. N/A cells can be skipped unless the system architecture suggests otherwise.

## Merge Protocol

When a Security Planner assessment already exists (`from-security-plan` entry mode), the merge protocol prevents duplication and ensures consistent cross-referencing between security and RAI security models.

### Steps

1. Read the existing security plan security model from the path in `state.json` `securityPlanRef`.
2. Extract the highest `T-{BUCKET}-AI-{NNN}` ID for each bucket to establish cross-reference continuity.
3. Start new RAI threat IDs at `T-RAI-001` (independent sequence from the security plan).
4. For overlapping threats (threats already identified in the security plan that also have RAI dimensions), cross-reference using dual IDs rather than duplicating the threat entry.
5. Produce an addendum document (`rai-threat-addendum.md`) with a merge header identifying the source security plan.
6. Use the extended threat table format with both ID columns to maintain traceability.
7. Include a cross-reference section listing security `T-{BUCKET}-AI-{NNN}` IDs and their RAI `T-RAI-{NNN}` counterparts.

### Addendum Header Template

```markdown
## RAI Security Model Addendum

- Source security plan: {path}
- Security plan date: {date}
- Highest existing security threat ID: T-{BUCKET}-{NNN}
- RAI threat ID range: T-RAI-001 through T-RAI-{NNN}
```

### Cross-Reference Section Template

```markdown
## Security Plan Cross-Reference

| Security Threat ID | RAI Threat ID | Description             | Overlap Type                                      |
|--------------------|---------------|-------------------------|---------------------------------------------------|
| T-DATA-AI-001      | T-RAI-003     | Training data poisoning | Full overlap, RAI extends with fairness dimension |
```

## AI Threat Concentration by Bucket

Expected threat density per operational bucket when analyzing AI systems. Use these estimates for planning and to validate coverage completeness.

| Bucket         | Expected AI Threat Count | Key Concern Areas                                                            |
|----------------|--------------------------|------------------------------------------------------------------------------|
| Data           | 9                        | Training data poisoning, bias injection, privacy violations, data provenance |
| Build          | 5                        | Model supply chain, training integrity, pipeline security                    |
| Web/UI         | 6                        | Adversarial inputs, prompt injection, output manipulation                    |
| Identity       | 3                        | Model impersonation, unauthorized access, credential compromise              |
| Infrastructure | 2                        | Resource exhaustion, compute hijacking                                       |

> [!NOTE]
> Actual threat counts vary based on system architecture and AI component complexity. These estimates provide a baseline for coverage validation. If analysis produces significantly fewer threats in a bucket, revisit the analysis for gaps.

## Artifact Templates

### RAI Threat Addendum Template

Template for `rai-threat-addendum.md` produced during Phase 4.

```markdown
---
title: RAI Security Model Addendum
description: RAI-specific threat analysis extending security plan security model
---

## RAI Security Model Addendum

- Source security plan: {path or "standalone"}
- Security plan date: {date or "N/A"}
- Highest existing security threat ID: {ID or "N/A"}
- RAI threat ID range: T-RAI-001 through T-RAI-{NNN}

## Extended Threat Table

| Threat ID | RAI ID    | STRIDE | NIST Characteristic | NIST AI RMF | Description | AI Element | Trust Boundary | Suggested Threat Origin | Concern Level | Mitigation |
|-----------|-----------|--------|---------------------|-------------|-------------|------------|----------------|-------------------------|---------------|------------|
|           | T-RAI-001 |        |                     |             |             |            |                |                         |               |            |

## Cross-Reference

| Security Threat ID | RAI Threat ID | Description | Overlap Type |
|--------------------|---------------|-------------|--------------|
|                    |               |             |              |

## Threat Concentration Summary

| Bucket         | Threat Count | Coverage Status |
|----------------|--------------|-----------------|
| Data           |              |                 |
| Build          |              |                 |
| Web/UI         |              |                 |
| Identity       |              |                 |
| Infrastructure |              |                 |
```

### Control Surface Catalog Template

Template for `control-surface-catalog.md` mapping controls to each identified threat.

```markdown
---
title: RAI Control Surface Catalog
description: Per-threat control surface mappings for RAI threat mitigations
---

## Control Surface Catalog

### Control Entry Template

For each threat, document the control surface:

| Field                 | Value                                     |
|-----------------------|-------------------------------------------|
| RAI Threat ID         | T-RAI-{NNN}                               |
| Security Threat ID    | T-{BUCKET}-AI-{NNN} or N/A                |
| NIST Characteristic   | {characteristic}                          |
| Control Category      | Preventive, Detective, or Corrective      |
| Control Description   | {description}                             |
| Implementation Status | Implemented, Partial, Planned, or Missing |
| Evidence              | {reference to evidence or "None"}         |
| Residual Concern      | {concern level after control application} |

### Control Surface Table

| RAI ID    | Control Category | Control Description | Status | Evidence | Residual Concern |
|-----------|------------------|---------------------|--------|----------|------------------|
| T-RAI-001 |                  |                     |        |          |                  |
```
