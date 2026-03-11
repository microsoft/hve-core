---
description: 'RAI risk surface analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and risk surface merge protocol'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Risk Surface Analysis

AI-specific risk surface analysis extensions for Phase 4 of the RAI Planner. This guidance extends the STRIDE methodology with RAI principle overlaps, AI element types, trust boundaries, data flow patterns, and a dual threat ID convention. A merge protocol enables interoperation with Security Planner risk surfaces when operating in `from-security-plan` mode.

## AI STRIDE Extensions

Standard STRIDE categories gain RAI-specific dimensions when applied to AI systems. Each category maps to one or more RAI principles that amplify the threat surface beyond traditional software concerns.

| STRIDE Category        | RAI Principle Overlay        | AI-Specific Threat Examples                                                                     |
|------------------------|------------------------------|-------------------------------------------------------------------------------------------------|
| Spoofing               | Reliability, Transparency    | Adversarial inputs mimicking legitimate data, model impersonation, synthetic identity injection |
| Tampering              | Fairness, Reliability        | Training data poisoning introducing bias, model weight manipulation, feedback loop corruption   |
| Repudiation            | Accountability, Transparency | Unattributable automated decisions, audit log gaps for model outputs, governance bypass         |
| Information Disclosure | Privacy                      | Training data extraction, model inversion attacks, membership inference, embedding leakage      |
| Denial of Service      | Reliability                  | Model resource exhaustion, inference throttling attacks, adversarial input causing degradation  |
| Elevation of Privilege | Privacy, Reliability         | Prompt injection bypassing safety filters, jailbreaking, unauthorized model capability access   |

## AI Element Types

Eight AI-specific element types define the components subject to RAI threat analysis. Each element type carries primary RAI concerns that guide threat identification.

| Element Type         | Description                             | Primary RAI Concerns                                                    |
|----------------------|-----------------------------------------|-------------------------------------------------------------------------|
| Training Data Store  | Datasets used for model training        | Fairness (bias), Privacy (PII), Accountability (provenance)             |
| Model Artifact       | Trained model files and weights         | Reliability (integrity), Transparency (explainability)                  |
| Inference Endpoint   | API or service serving predictions      | Reliability (availability), Privacy (query privacy)                     |
| Feature Pipeline     | Data transformation for model input     | Fairness (feature bias), Privacy (data flow)                            |
| Feedback Loop        | User feedback incorporated into model   | Fairness (feedback bias), Reliability (drift)                           |
| Human Review Queue   | Human oversight checkpoints             | Accountability (review coverage), Transparency (decision documentation) |
| Monitoring Dashboard | Model performance and behavior tracking | Transparency (observability), Reliability (alerting)                    |
| Orchestration Layer  | Agent or pipeline orchestration         | Accountability (decision routing), Reliability (failure handling)       |

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

RAI risk surface analysis uses a dual ID system that enables independent tracking within the RAI plan and cross-referencing with Security Planner operational buckets.

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

The threat table extends the Security Planner format with three additional columns: RAI ID, RAI Principle, and NIST AI RMF.

```markdown
| Threat ID     | RAI ID    | STRIDE    | RAI Principle | NIST AI RMF | Description                                          | AI Element          | Trust Boundary         | Likelihood | Impact | Risk     | Mitigation                                                    |
|---------------|-----------|-----------|---------------|-------------|------------------------------------------------------|---------------------|------------------------|------------|--------|----------|---------------------------------------------------------------|
| T-DATA-AI-001 | T-RAI-003 | Tampering | Fairness      | Map 2.3     | Training data poisoning introducing demographic bias | Training Data Store | Training Data Boundary | High       | High   | Critical | Data validation pipeline, bias detection, provenance tracking |
```

### Column Definitions

* Threat ID: Security Planner cross-reference ID (`T-{BUCKET}-AI-{NNN}`), or blank if no bucket overlap exists.
* RAI ID: Sequential RAI threat identifier (`T-RAI-{NNN}`).
* STRIDE: Applicable STRIDE category.
* RAI Principle: Primary RAI principle affected (Fairness, Reliability, Privacy, Inclusiveness, Transparency, Accountability).
* NIST AI RMF: Applicable NIST AI RMF subcategory reference.
* Description: Clear description of the threat, attack vector, and affected behavior.
* AI Element: Element type from the AI Element Types table.
* Trust Boundary: Boundary crossed or affected from the AI Trust Boundaries table.
* Likelihood: High, Medium, Low, or ❓ (unassessed).
* Impact: High, Medium, Low, or ❓ (unassessed).
* Risk: Calculated using the standard risk matrix (High x High = Critical, High x Medium or Medium x High = High, Medium x Medium = Medium, Low x any or any x Low = Low).
* Mitigation: Proposed mitigation strategy with standards references.

## ML STRIDE Matrix

Extended matrix covering AI system components with RAI principle annotations. Each cell contains threat applicability (High/Medium/Low/N/A) and the primary RAI principle relevant to that intersection.

| Component        | Spoofing             | Tampering               | Repudiation             | Info Disclosure       | DoS                  | EoP                     |
|------------------|----------------------|-------------------------|-------------------------|-----------------------|----------------------|-------------------------|
| Training Data    | Medium / Reliability | High / Fairness         | Medium / Accountability | High / Privacy        | Low / Reliability    | Low / Privacy           |
| Feature Pipeline | Low / Transparency   | High / Fairness         | Medium / Accountability | Medium / Privacy      | Low / Reliability    | Low / Fairness          |
| Model Training   | Medium / Reliability | High / Fairness         | High / Accountability   | High / Privacy        | Medium / Reliability | Medium / Reliability    |
| Model Serving    | High / Reliability   | Medium / Reliability    | Medium / Transparency   | High / Privacy        | High / Reliability   | High / Reliability      |
| Inference API    | High / Reliability   | High / Reliability      | Medium / Transparency   | Medium / Privacy      | High / Reliability   | High / Privacy          |
| Feedback Loop    | Medium / Fairness    | High / Fairness         | High / Accountability   | Medium / Privacy      | Low / Reliability    | Medium / Fairness       |
| Human Review     | Low / Accountability | Medium / Accountability | High / Accountability   | Low / Privacy         | N/A                  | Medium / Accountability |
| Model Monitoring | Low / Transparency   | Medium / Reliability    | High / Transparency     | Medium / Transparency | Medium / Reliability | Low / Reliability       |

### Reading the Matrix

Each cell uses the format `Applicability / RAI Principle`:

* Applicability indicates how likely the STRIDE category applies to the component (High, Medium, Low, N/A).
* RAI Principle identifies which RAI principle is most relevant for that specific threat intersection.
* Use this matrix as a starting point for threat identification. Investigate all High-applicability cells first, then Medium, then Low. N/A cells can be skipped unless the system architecture suggests otherwise.

## Merge Protocol

When a Security Planner assessment already exists (`from-security-plan` entry mode), the merge protocol prevents duplication and ensures consistent cross-referencing between security and RAI risk surfaces.

### Steps

1. Read the existing security plan risk surface from the path in `state.json` `securityPlanRef`.
2. Extract the highest `T-{BUCKET}-AI-{NNN}` ID for each bucket to establish cross-reference continuity.
3. Start new RAI threat IDs at `T-RAI-001` (independent sequence from the security plan).
4. For overlapping threats (threats already identified in the security plan that also have RAI dimensions), cross-reference using dual IDs rather than duplicating the threat entry.
5. Produce an addendum document (`rai-threat-addendum.md`) with a merge header identifying the source security plan.
6. Use the extended threat table format with both ID columns to maintain traceability.
7. Include a cross-reference section listing security `T-{BUCKET}-AI-{NNN}` IDs and their RAI `T-RAI-{NNN}` counterparts.

### Addendum Header Template

```markdown
## RAI Risk Surface Addendum

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
title: RAI Risk Surface Addendum
description: RAI-specific threat analysis extending security plan risk surface
---

## RAI Risk Surface Addendum

- Source security plan: {path or "standalone"}
- Security plan date: {date or "N/A"}
- Highest existing security threat ID: {ID or "N/A"}
- RAI threat ID range: T-RAI-001 through T-RAI-{NNN}

## Extended Threat Table

| Threat ID | RAI ID    | STRIDE | RAI Principle | NIST AI RMF | Description | AI Element | Trust Boundary | Likelihood | Impact | Risk | Mitigation |
|-----------|-----------|--------|---------------|-------------|-------------|------------|----------------|------------|--------|------|------------|
|           | T-RAI-001 |        |               |             |             |            |                |            |        |      |            |

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
| RAI Principle         | {principle}                               |
| Control Category      | Preventive, Detective, or Corrective      |
| Control Description   | {description}                             |
| Implementation Status | Implemented, Partial, Planned, or Missing |
| Evidence              | {reference to evidence or "None"}         |
| Residual Risk         | {risk level after control application}    |

### Control Surface Table

| RAI ID    | Control Category | Control Description | Status | Evidence | Residual Risk |
|-----------|------------------|---------------------|--------|----------|---------------|
| T-RAI-001 |                  |                     |        |          |               |
```
