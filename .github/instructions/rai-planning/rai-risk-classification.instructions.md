---
description: 'Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# Risk Classification

Phase 2 screens AI systems for risk using the active classification framework. The prohibited uses gate executes first as a safety-critical check. Risk indicator results determine the suggested assessment depth tier for subsequent phases. By default, indicators derive from the NIST AI Risk Management Framework 1.0 trustworthiness characteristics (see `rai-standards.instructions.md`). Custom classification frameworks can replace or extend these defaults.

## Prohibited Uses Gate

The prohibited uses gate is a safety-critical check that executes before risk indicator assessment. When the AI system falls into a prohibited use category defined by applicable regulations or organizational policies, flag the session immediately and do not proceed to indicator assessment without explicit user acknowledgment.

Prohibited use categories vary by regulatory jurisdiction, organizational policy, and deployment context. Common regulatory frameworks that define prohibited AI uses include:

* EU AI Act Article 5 (prohibited practices such as social scoring, real-time biometric identification, subliminal manipulation)
* Organizational responsible AI policies (internal prohibited use lists, ethics board determinations)
* Domain-specific regulations (healthcare restrictions on autonomous diagnosis, financial services restrictions on automated credit decisions)
* Regional AI governance frameworks (Singapore Model AI Governance, Canada AIDA, UK AI Regulation)

These examples are illustrative, not exhaustive. The planner does not determine which frameworks apply. Consult your legal and compliance teams to identify the prohibited use definitions relevant to your deployment context.

### Adding Prohibited Use Frameworks

To incorporate a specific regulatory framework's prohibited use definitions into the assessment:

1. During Phase 1 (or at any point), tell the agent which framework to evaluate (for example, "Add EU AI Act prohibited practices to this assessment").
2. The agent delegates to the Researcher Subagent to retrieve current prohibited use definitions from that framework.
3. The Researcher Subagent writes the processed definitions to `.copilot-tracking/rai-plans/references/{framework-name}-prohibited-uses.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `prohibited-use-framework`.
5. When the framework is loaded during Phase 2 and the prohibited uses gate has not yet concluded, evaluate it immediately before proceeding. On subsequent sessions, the prohibited uses gate evaluates automatically against all loaded framework definitions.

The AI processing disclaimer applies to all retrieved framework content: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

### Evaluating Loaded Prohibited Use Frameworks

Before running the gate, check `.copilot-tracking/rai-plans/references/` for files with type `prohibited-use-framework` in `referencesProcessed` state. When loaded frameworks exist:

1. Read each prohibited use framework reference file.
2. Present the framework-specific prohibited use categories to the user, attributed to their source.
3. Evaluate the AI system against each framework's categories.
4. Display the AI processing disclaimer for each framework: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

When no prohibited use frameworks are loaded, proceed with the gate protocol using the user's own knowledge of applicable prohibitions.

### Gate Protocol

1. When frameworks were evaluated above, confirm the prohibited use categories already presented and proceed to Step 2. When no prohibited use frameworks are loaded, ask whether the user's organization or applicable regulations define prohibited AI uses.
2. Ask: "Does the AI system fall into any prohibited use categories defined by your applicable regulations or organizational policies?"
3. If **Yes**: Flag the session, document the prohibited use category and its source framework, and pause. Do not proceed to risk indicator assessment without explicit user acknowledgment and documented justification.
4. If **No**: Proceed to risk indicator assessment.

## Risk Indicator Extensions

Before beginning indicator assessment, check `.copilot-tracking/rai-plans/references/` for files with type `risk-indicator-extension` in `referencesProcessed` state. When risk indicator extensions exist:

1. Present the extension indicators alongside the default NIST-derived indicators.
2. Each extension follows the same indicator structure: description, assessment method type (binary, categorical, or continuous), gate question, response options, and scoring guidance.
3. Evaluate the AI system against each extension using the assessment method dispatch.
4. Extension results contribute to the activated count for depth tier assignment alongside default indicators.
5. Display the AI processing disclaimer: "AI processed this user-supplied risk indicator extension and may generate inconsistent results. Verify against the original source."

Extensions are always additive. They never replace default indicators, even when a custom framework with `replaceDefaultIndicators: true` is loaded. Extensions augment whichever indicator set is active.

## Risk Indicator Assessment

Evaluate the AI system against the active framework's risk indicators. When no custom framework with `replaceDefaultIndicators: true` is loaded, use the three default NIST-derived indicators below.

### Default Indicator Table

| Indicator ID              | NIST Source              | Method      | Domain                                                                                            |
|---------------------------|--------------------------|-------------|---------------------------------------------------------------------------------------------------|
| `safety_reliability`      | MS-2.5, MS-2.6           | Binary      | Physical harm, psychological injury, operational disruption from inaccurate or unreliable outputs |
| `rights_fairness_privacy` | MS-2.8, MS-2.10, MS-2.11 | Categorical | Discrimination, rights restriction, equitable access, personal data misuse, accountability gaps   |
| `security_explainability` | MS-2.7, MS-2.9           | Continuous  | Adversarial attacks, data poisoning, model theft, inability to explain consequential decisions    |

### Safety and Reliability (`safety_reliability`)

Assessment method: Binary (Yes/No). NIST source: Safe (MS-2.6) and Valid and Reliable (MS-2.5).

**Gate question**: Could failures in this AI system's safety, accuracy, or reliability cause physical harm, psychological injury, or significant operational disruption?

If activated (Yes):

1. What types of harm could occur?
2. What severity levels are possible?
3. What safeguards exist or could be implemented?
4. Record: `riskClassification.indicators.safety_reliability.activated = true`, capture observation.

If not activated (No): Record the observation explaining why the system does not pose safety or reliability risks.

### Rights, Fairness, and Privacy (`rights_fairness_privacy`)

Assessment method: Categorical (None, Indirect, Direct, Primary). NIST source: Fair with Harmful Bias Managed (MS-2.11), Privacy-Enhanced (MS-2.10), and Accountable and Transparent (MS-2.8).

MS-2.8 (Accountable and Transparent) groups with fairness and privacy because accountability gaps directly affect rights recourse mechanisms. This indicator assesses whether affected individuals can understand, question, and seek remedy for AI decisions, which requires transparency and accountability infrastructure.

**Gate question**: Could this AI system produce biased or discriminatory outcomes, infringe on individual rights, or process personal data in ways that violate privacy expectations?

Categories:

| Category | Description                                                                                                                           |
|----------|---------------------------------------------------------------------------------------------------------------------------------------|
| None     | No measurable fairness, privacy, or rights impact.                                                                                    |
| Indirect | System outputs may influence decisions affecting rights, fairness, or privacy, but the system does not directly make those decisions. |
| Direct   | System directly processes personal data or makes decisions affecting individual rights, fairness, or privacy.                         |
| Primary  | System's core purpose involves rights-affecting decisions, protected class data, or privacy-sensitive operations.                     |

A category of "Direct" or "Primary" counts as activated for depth tier purposes.

When activated, capture follow-up context:

1. Which domains are affected (fairness, privacy, accountability)?
2. Who is affected and what is the scale of impact?
3. What recourse or appeal mechanisms exist?
4. Record: `riskClassification.indicators.rights_fairness_privacy.activated = true`, plus `result.category`, `result.matchedDomains[]`, and observation.

When not activated: Record `activated = false` with the assigned category and observation.

### Security and Explainability (`security_explainability`)

Assessment method: Continuous (0.0–1.0 score). NIST source: Secure and Resilient (MS-2.7) and Explainable and Interpretable (MS-2.9).

**Gate question**: Could security vulnerabilities, adversarial attacks, or inability to explain this system's decisions result in significant harm?

Score each dimension from 0.0 (minimal risk) to 1.0 (severe risk):

| Dimension                   | Range   | Description                                                                                                                   |
|-----------------------------|---------|-------------------------------------------------------------------------------------------------------------------------------|
| Attack surface exposure     | 0.0–1.0 | Breadth and accessibility of interfaces vulnerable to adversarial input, data poisoning, or model extraction.                 |
| Data sensitivity level      | 0.0–1.0 | Classification and protection requirements of data the system processes, stores, or generates.                                |
| Decision explainability gap | 0.0–1.0 | Distance between the system's decision complexity and stakeholders' ability to understand, audit, or contest those decisions. |

The overall score is the mean of the three dimension scores. A score of 0.5 or higher counts as activated for depth tier purposes.

When activated, capture follow-up context:

1. Which security vulnerabilities or explainability gaps drive the score?
2. What existing controls mitigate identified risks?
3. Record: `riskClassification.indicators.security_explainability.activated = true`, plus `result.score`, `result.dimensions[]`, and observation.

When not activated: Record `activated = false` with the score, dimension values, and observation.

## Assessment Method Dispatch

Three assessment methods evaluate risk indicators. Each indicator specifies its method type, and the dispatch routes evaluation accordingly.

| Method      | Input                        | Output                                                                | Use Case                                          |
|-------------|------------------------------|-----------------------------------------------------------------------|---------------------------------------------------|
| Binary      | Yes/No screening question    | `{ activated: boolean, observation: string }`                         | Clear-cut risk presence or absence                |
| Categorical | Multi-level classification   | `{ category: string, matchedDomains: string[], observation: string }` | Graduated impact assessment across defined levels |
| Continuous  | Numeric dimensions (0.0–1.0) | `{ score: number, dimensions: [{name, value}], observation: string }` | Multidimensional risk quantification              |

Each method contributes to the activated count for depth tier assignment:

| Method      | Activation Rule                                                  |
|-------------|------------------------------------------------------------------|
| Binary      | `activated = true` adds 1 to the activated count.                |
| Categorical | A result of "Direct" or "Primary" adds 1 to the activated count. |
| Continuous  | A score of 0.5 or higher adds 1 to the activated count.          |

The dispatch applies identically to default indicators, custom framework indicators, and risk indicator extensions.

## Custom Framework Override

When a custom classification framework with `replaceDefaultIndicators: true` is loaded via `referencesProcessed` with type `risk-classification-framework`, the framework's indicators replace the 3 default NIST-derived indicators.

Custom framework override rules:

* Custom indicators from the framework's Risk Indicators section become the active indicator set for Phase 2.
* Each custom indicator must follow the same structure: ID, method type (binary, categorical, or continuous), gate question, response options, and scoring guidance.
* When `replaceDefaultIndicators` is absent or `false`, the default NIST indicators apply.
* Risk Indicator Extensions (type `risk-indicator-extension`) remain additive regardless of this flag.
* When a custom framework defines its own depth tier mapping, use that mapping instead of the default count-based tiers.

Loading a custom classification framework:

1. During Phase 1 (or at any point), tell the agent which framework to use (for example, "Use our internal risk classification framework").
2. The agent delegates to the Researcher Subagent to retrieve and process the framework document.
3. The Researcher Subagent writes the processed framework to `.copilot-tracking/rai-plans/references/{framework-name}-classification.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `risk-classification-framework`.
5. During Phase 2, the agent reads the framework reference and applies its indicators in place of or alongside the defaults based on the `replaceDefaultIndicators` flag.

The AI processing disclaimer applies: "AI processed this classification framework and may generate inconsistent results. Verify against the original source."

## Code-of-Conduct Cross-Reference

After risk indicators are evaluated, check `referencesProcessed` for entries with type `code-of-conduct`. When code-of-conduct documents are loaded:

1. Read each code-of-conduct reference file.
2. Compare risk indicator results against the provider's acceptable use policies.
3. Flag conflicts where:
   * A use case passes risk indicators but violates a provider's acceptable use policy.
   * A provider restriction is more stringent than the risk classification result.
4. Document flagged conflicts in the classification output with the provider name, conflicting policy, and recommendation.
5. Display the AI processing disclaimer for each code-of-conduct document: "AI processed this code-of-conduct document and may generate inconsistent results. Verify against the original source."

When no code-of-conduct documents are loaded, skip this section.

## Depth Tier Assignment

The suggested depth tier flows automatically from the activated indicator count. Do not assign a tier manually based on judgment.

| Tier          | Criteria                | Description                                                                            |
|---------------|-------------------------|----------------------------------------------------------------------------------------|
| Basic         | 0 indicators activated  | No significant risks identified. Subsequent phases use baseline analysis depth.        |
| Standard      | 1 indicator activated   | One risk area identified. Subsequent phases include additional analysis for that area. |
| Comprehensive | 2+ indicators activated | Multiple risk areas identified. Subsequent phases use comprehensive analysis.          |

The activated count includes both default (or custom framework) indicators and any risk indicator extensions. When a custom framework defines its own depth tier mapping, use that mapping instead of the default table.

Present the suggested depth tier to the user with the rationale (activation count and which indicators activated). The user must confirm the tier before advancing to Phase 3. This is a hard gate because tier changes affect scope and effort of all downstream phases.

## Classification Output Template

Present classification results using this format:

### Prohibited Uses Gate

| Field               | Value                                                                                     |
|---------------------|-------------------------------------------------------------------------------------------|
| Status              | [Passed / Flagged]                                                                        |
| Source framework(s) | [framework name(s) evaluated, or "user knowledge" if no frameworks loaded]                |
| Notes               | [if flagged, prohibited use category, source framework, and justification for proceeding] |

### Risk Indicator Assessment

| Indicator ID              | Activated  | Method      | Result Summary                 | Observation          |
|---------------------------|------------|-------------|--------------------------------|----------------------|
| `safety_reliability`      | [Yes / No] | Binary      | [Yes/No]                       | [observation or N/A] |
| `rights_fairness_privacy` | [Yes / No] | Categorical | [None/Indirect/Direct/Primary] | [observation or N/A] |
| `security_explainability` | [Yes / No] | Continuous  | [0.00–1.00 score]              | [observation or N/A] |
| [extension indicator IDs] | [Yes / No] | [method]    | [result summary]               | [observation or N/A] |

### Code-of-Conduct Conflicts

| Provider   | Conflicting Policy   | Recommendation          |
|------------|----------------------|-------------------------|
| [provider] | [policy description] | [action recommendation] |

Omit this table when no code-of-conduct documents are loaded or no conflicts exist.

### Suggested Depth Tier

| Field                 | Value                                             |
|-----------------------|---------------------------------------------------|
| Tier                  | [Basic / Standard / Comprehensive]                |
| Rationale             | [activation count and which indicators activated] |
| Confirmation required | User must confirm tier before advancing.          |

## Indicator Evaluation Guidance

When evaluating indicators:

* Each indicator uses its defined assessment method. Binary indicators produce yes/no results. Categorical indicators assign a level. Continuous indicators produce a numeric score.
* Evidence should cite specific system capabilities, user interactions, or data flows that inform the assessment.
* Assessment results capture context needed for downstream phases (security model, impact assessment).
* When uncertain whether an indicator should activate, ask clarifying questions before recording the result.
* The depth tier flows automatically from the activation count (or from a custom framework's tier mapping). Never assign a tier manually based on judgment.
* When presenting results, explain the activation reasoning with evidence from the system description. Do not present bare results without reasoning.

## State Schema Reference

Risk classification updates the following state fields:

```json
"riskClassification": {
  "framework": {
    "id": "nist-ai-rmf",
    "name": "NIST AI Risk Management Framework",
    "version": "1.0",
    "source": "rai-standards.instructions.md",
    "replaceDefaultIndicators": false,
    "replaceDefaultFramework": false
  },
  "indicators": {
    "safety_reliability": {
      "method": "binary",
      "nistSource": ["MS-2.5", "MS-2.6"],
      "activated": false,
      "observation": null,
      "result": null
    },
    "rights_fairness_privacy": {
      "method": "categorical",
      "nistSource": ["MS-2.8", "MS-2.10", "MS-2.11"],
      "activated": false,
      "observation": null,
      "result": null
    },
    "security_explainability": {
      "method": "continuous",
      "nistSource": ["MS-2.7", "MS-2.9"],
      "activated": false,
      "observation": null,
      "result": null
    }
  },
  "activatedCount": 0,
  "riskScore": null,
  "suggestedDepthTier": "Basic"
},
"gateResults": {
  "prohibitedUsesGate": {
    "status": "pending",
    "sourceFrameworks": [],
    "notes": null
  }
}
```

The `riskScore` field is reserved for future aggregation logic and is not calculated during Phase 2. Leave it as `null` until a scoring formula is defined.

### Key Changes from Legacy Schema

* `sensitiveUsesTriggers` replaced by `riskClassification.indicators` with dynamic keys supporting both default and custom indicators.
* `triggered` replaced by `activated` on each indicator.
* `triggeredCount` replaced by `activatedCount` under `riskClassification`.
* `suggestedDepthTier` nested under `riskClassification` instead of top-level state.
* New `framework` object defaults to `nist-ai-rmf` and tracks the active classification framework's identity, version, and override flags.
* Each indicator now includes `nistSource` (array of MS-2.x subcategory IDs), `method` (binary, categorical, or continuous), and `result` (method-specific output object).
* `restrictedUsesGate` replaced by `prohibitedUsesGate` under `gateResults`.

Update `activatedCount` and `suggestedDepthTier` after evaluating all indicators. The depth tier value must match the Depth Tier Assignment table criteria.
