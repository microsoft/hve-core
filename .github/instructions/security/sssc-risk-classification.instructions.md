---
description: 'SSSC risk classification model — binary/categorical assessment with gate tiering and depth selection - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Risk Classification

Risk classification screens the target software supply chain before standards mapping. The disallowed components and sources gate executes first as a safety-critical check. Risk indicator results determine the suggested assessment depth tier for subsequent phases. By default, indicators derive from supply chain blast radius, dependency exposure, and compliance threat surface (see `sssc-standards.instructions.md` for the framework skills consulted in later phases). Custom classification frameworks can replace or extend these defaults.

## Disallowed Components and Sources Gate

The disallowed components and sources gate is a safety-critical check that executes before risk indicator assessment. When the project consumes, distributes, or depends on components or sources that are prohibited by applicable regulations or organizational policies, flag the session immediately and do not proceed to indicator assessment without explicit user acknowledgment.

Prohibited categories vary by regulatory jurisdiction, organizational policy, and deployment context. Common frameworks that define prohibited supply chain practices include:

* Export control regulations (US EAR/ITAR, EU Dual-Use Regulation) restricting cryptographic libraries, geographic distribution, or sanctioned-entity dependencies.
* Organizational supply chain policies (banned vendor lists, internal allowlist of registries, license-incompatible components).
* Sector-specific regulations (FedRAMP package origin requirements, PCI DSS approved-component lists, healthcare HIPAA constraints on third-party processors).
* National cybersecurity directives (CISA Known Exploited Vulnerabilities catalog, US Executive Order 14028 attestation requirements, EU CRA component obligations).

These examples are illustrative, not exhaustive. The planner does not determine which frameworks apply. Consult your legal, compliance, and security teams to identify the prohibited component definitions relevant to your deployment context.

### Adding Prohibited Component Frameworks

To incorporate a specific framework's prohibited component definitions into the assessment:

1. During Phase 1 (or at any point), tell the agent which framework to evaluate (for example, "Add US EAR cryptographic export controls to this assessment").
2. The agent delegates to the Researcher Subagent to retrieve current prohibited component definitions from that framework.
3. The Researcher Subagent writes the processed definitions to `.copilot-tracking/sssc-plans/references/{framework-name}-prohibited-components.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `prohibited-component-framework`.
5. When the framework is loaded during Phase 2 and the gate has not yet concluded, evaluate it immediately before proceeding. On subsequent sessions, the gate evaluates automatically against all loaded framework definitions.

The AI processing disclaimer applies to all retrieved framework content: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

### Evaluating Loaded Prohibited Component Frameworks

Before running the gate, check `.copilot-tracking/sssc-plans/references/` for files with type `prohibited-component-framework` in `referencesProcessed` state. When loaded frameworks exist:

1. Read each prohibited component framework reference file.
2. Present the framework-specific prohibited categories to the user, attributed to their source.
3. Evaluate the project against each framework's categories.
4. Display the AI processing disclaimer for each framework: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

When no prohibited component frameworks are loaded, proceed with the gate protocol using the user's own knowledge of applicable prohibitions.

### Gate Protocol

1. When frameworks were evaluated above, confirm the prohibited component categories already presented and proceed to Step 2. When no prohibited component frameworks are loaded, ask whether the user's organization or applicable regulations define prohibited supply chain components or sources.
2. Ask: "Does this project consume, distribute, or depend on components or sources that fall into any prohibited category defined by your applicable regulations or organizational policies?"
3. If **Yes**: Flag the session, document the prohibited category and its source framework, and pause. Do not proceed to risk indicator assessment without explicit user acknowledgment and documented justification.
4. If **No**: Proceed to risk indicator assessment.

The gate result is recorded in `state.json` as `riskClassification.disallowedGate` with `status` defaulting to `pending` until evaluated. Permitted transitions are `pass`, `fail`, `waived`, and `blocked`.

## Risk Indicator Extensions

Before beginning indicator assessment, check `.copilot-tracking/sssc-plans/references/` for files with type `risk-indicator-extension` in `referencesProcessed` state. When risk indicator extensions exist:

1. Present the extension indicators alongside the default supply chain indicators.
2. Each extension follows the same indicator structure: description, assessment method type (binary or categorical), gate question, response options, and scoring guidance.
3. Evaluate the project against each extension using the assessment method dispatch.
4. Extension results contribute to the activated count for depth tier assignment alongside default indicators.
5. Display the AI processing disclaimer: "AI processed this user-supplied risk indicator extension and may generate inconsistent results. Verify against the original source."

Extensions are always additive. They never replace default indicators, even when a custom framework with `replaceDefaultIndicators: true` is loaded. Extensions augment whichever indicator set is active.

## Risk Indicator Assessment

Evaluate the project against the active framework's risk indicators. When no custom framework with `replaceDefaultIndicators: true` is loaded, use the three default supply chain indicators below.

### Default Indicator Table

| Indicator ID                | Domain Source                                              | Method      | Domain                                                                                                  |
|-----------------------------|------------------------------------------------------------|-------------|---------------------------------------------------------------------------------------------------------|
| `release_blast_radius`      | SLSA Build track, Sigstore signing scope                   | Binary      | Downstream consumer impact from a compromised, tampered, or unverifiable release                        |
| `dependency_exposure`       | OpenSSF Scorecard (Pinned-Dependencies, Dependency-Update) | Categorical | Breadth of direct and transitive third-party footprint, registry diversity, update cadence              |
| `compliance_threat_surface` | NIST SSDF, S2C2F, CISA SSCM, regulatory obligations        | Categorical | Combined attack surface, sensitive-data handling, and regulated-obligation pressure on the supply chain |

### Release Blast Radius (`release_blast_radius`)

Assessment method: Binary (Yes/No). Domain source: SLSA Build track integrity expectations and Sigstore signing/verification scope.

**Gate question**: Could a compromised, tampered, or unverifiable release of this project cause material harm to downstream consumers, paying customers, regulated workloads, or critical infrastructure?

If activated (Yes):

1. Who consumes the release (internal services, external customers, OEM partners, public OSS users)?
2. What harm could a compromised artifact cause (data loss, outages, regulatory violation, safety impact)?
3. What signing, attestation, and verification controls exist or could be added?
4. Record: `riskClassification.indicators.release_blast_radius.activated = true`, capture observation.

If not activated (No): Record the observation explaining why a compromised release would not cause material downstream harm.

### Dependency Exposure (`dependency_exposure`)

Assessment method: Categorical (None, Limited, Broad, Extensive). Domain source: OpenSSF Scorecard checks for Pinned-Dependencies, Dependency-Update-Tool, Vulnerabilities, and Maintained.

**Gate question**: How broad is the project's third-party and transitive dependency footprint, and how exposed is it to upstream compromise?

Categories:

| Category  | Description                                                                                                                             |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------|
| None      | First-party only; no external runtime, build, or transitive dependencies.                                                               |
| Limited   | Small, well-maintained dependency set from a single trusted registry; pinned versions; routine updates.                                 |
| Broad     | Multi-registry footprint with significant transitive depth; mixed pinning posture; mixed maintenance health.                            |
| Extensive | Large transitive surface, multiple ecosystems or registries, low-maintenance or unmaintained packages, or known supply chain incidents. |

A category of "Broad" or "Extensive" counts as activated for depth tier purposes.

When activated, capture follow-up context:

1. Which ecosystems, registries, and package managers are in scope?
2. What is the pinning, update, and vulnerability-monitoring posture?
3. Are any dependencies unmaintained, deprecated, or previously implicated in supply chain incidents?
4. Record: `riskClassification.indicators.dependency_exposure.activated = true`, plus `result.category`, `result.matchedDomains[]`, and observation.

When not activated: Record `activated = false` with the assigned category and observation.

### Compliance Threat Surface (`compliance_threat_surface`)

Assessment method: Categorical (multi-dimension classification). Domain source: NIST SSDF practice groups, S2C2F practices, CISA SSCM lifecycle controls, and applicable regulatory obligations.

**Gate question**: Could security vulnerabilities, missing attestations, or regulatory non-compliance in this project's supply chain result in significant harm or enforcement exposure?

Classify each dimension into one of the four exposure categories:

| Dimension                        | Categories                         | Description                                                                                                               |
|----------------------------------|------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| Build and release attack surface | None / Limited / Broad / Extensive | Breadth and accessibility of build, release, and distribution infrastructure exposed to tampering or unauthorized access. |
| Sensitive material handling      | None / Limited / Broad / Extensive | Classification and protection requirements of credentials, signing keys, customer data, or regulated content in scope.    |
| Regulatory obligation pressure   | None / Limited / Broad / Extensive | Strength of external mandates (EO 14028, EU CRA, FedRAMP, sector regulators) requiring attestations, SBOMs, or controls.  |

Category definitions match `dependency_exposure`: **None** = absent; **Limited** = small, well-bounded exposure with routine controls; **Broad** = significant exposure across multiple surfaces or actors; **Extensive** = pervasive exposure with weak or missing controls, or active regulatory pressure.

Activation rule: any dimension classified as **Broad** or **Extensive** counts as activated for depth tier purposes.

When activated, capture follow-up context:

1. Which dimensions drove activation, and what evidence supports each category assignment?
2. What existing controls (signing, SBOMs, scanning, attestations, access controls) mitigate identified exposure?
3. Record: `riskClassification.indicators.compliance_threat_surface.activated = true`, plus `result.dimensions[]` (each with `name` and `category`), and observation.

When not activated: Record `activated = false` with the dimension categories and observation.

## Assessment Method Dispatch

Two assessment methods evaluate risk indicators. Each indicator specifies its method type, and the dispatch routes evaluation accordingly.

| Method      | Input                                     | Output                                                                   | Use Case                                            |
|-------------|-------------------------------------------|--------------------------------------------------------------------------|-----------------------------------------------------|
| Binary      | Yes/No screening question                 | `{ activated: boolean, observation: string }`                            | Clear-cut presence or absence of supply chain risk  |
| Categorical | Single- or multi-dimension classification | `{ category|dimensions, matchedDomains: string[], observation: string }` | Graduated exposure assessment across defined levels |

Each method contributes to the activated count for depth tier assignment:

| Method      | Activation Rule                                                                                                           |
|-------------|---------------------------------------------------------------------------------------------------------------------------|
| Binary      | `activated = true` adds 1 to the activated count.                                                                         |
| Categorical | A result of "Broad" or "Extensive" (single-dimension), or any dimension at "Broad"/"Extensive" (multi-dimension), adds 1. |

The dispatch applies identically to default indicators, custom framework indicators, and risk indicator extensions.

## Risk Tiers

Each indicator result is mapped to a risk tier used downstream by gap analysis and backlog generation when prioritizing remediation work.

| Tier     | Source                                                                                            | Downstream Use                                     |
|----------|---------------------------------------------------------------------------------------------------|----------------------------------------------------|
| Critical | Disallowed gate failure, or any activated indicator combined with regulated downstream consumers. | Immediate remediation; blocks Phase 6 handoff.     |
| High     | Two or more activated indicators, or an activated indicator with any dimension at `Extensive`.    | Prioritized in next backlog increment.             |
| Medium   | Single activated indicator with `Broad` as the highest dimension category.                        | Scheduled remediation in upcoming sprint.          |
| Low      | No activated indicators but elevated context (for example, planned regulated launch).             | Tracked in backlog; opportunistic remediation.     |
| Info     | No activated indicators and no elevated context.                                                  | Documented for awareness; no remediation required. |

Risk tier values are recorded in `state.json` as `riskClassification.indicators[<id>].tier`. The tier value is informational; it does not gate phase advancement on its own.

## Gate Model

Gates are the controlled transition points used by the planner across phases. All gates default to `pending` (per RI-2) and accept the following terminal states:

| State   | Meaning                                                                                                   |
|---------|-----------------------------------------------------------------------------------------------------------|
| pending | Gate has not yet been evaluated.                                                                          |
| pass    | Gate evaluated and met its acceptance criteria.                                                           |
| fail    | Gate evaluated and did not meet its acceptance criteria; remediation is required.                         |
| waived  | Gate evaluated as `fail` but explicitly waived by the user with documented justification in `state.json`. |
| blocked | Gate cannot be evaluated due to missing inputs, missing references, or downstream dependency failures.    |

Gate state is persisted in `state.json` under `riskClassification.disallowedGate` and `riskClassification.indicators[<id>].gate`. The planner refuses to advance phases when any gate required for the next phase remains `pending` or `blocked`. Waivers must include a `justification` field and the user identity that approved the waiver.

## Custom Framework Override

When a custom classification framework with `replaceDefaultIndicators: true` is loaded via `referencesProcessed` with type `risk-classification-framework`, the framework's indicators replace the three default supply chain indicators.

Custom framework override rules:

* Custom indicators from the framework's Risk Indicators section become the active indicator set for risk classification.
* Each custom indicator must follow the same structure: ID, method type (binary or categorical), gate question, response options, and scoring guidance.
* When `replaceDefaultIndicators` is absent or `false`, the default supply chain indicators apply.
* Risk Indicator Extensions (type `risk-indicator-extension`) remain additive regardless of this flag.
* When a custom framework defines its own depth tier mapping, use that mapping instead of the default count-based tiers.

Loading a custom classification framework:

1. During Phase 1 (or at any point), tell the agent which framework to use (for example, "Use our internal supply chain risk classification framework").
2. The agent delegates to the Researcher Subagent to retrieve and process the framework document.
3. The Researcher Subagent writes the processed framework to `.copilot-tracking/sssc-plans/references/{framework-name}-classification.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `risk-classification-framework`.
5. During risk classification, the agent reads the framework reference and applies its indicators in place of or alongside the defaults based on the `replaceDefaultIndicators` flag.

The AI processing disclaimer applies: "AI processed this classification framework and may generate inconsistent results. Verify against the original source."

## Depth Tier Assignment

The suggested depth tier flows automatically from the activated indicator count. Do not assign a tier manually based on judgment.

| Tier        | Criteria                | Description                                                                                                                        |
|-------------|-------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Lightweight | 0 indicators activated  | No significant supply chain risks identified. Subsequent phases use baseline framework coverage and minimal evidence collection.   |
| Standard    | 1 indicator activated   | One risk area identified. Subsequent phases include additional framework controls and evidence collection for that area.           |
| In-Depth    | 2+ indicators activated | Multiple risk areas identified. Subsequent phases load the full framework control set and require verified evidence for all gates. |

The activated count includes both default (or custom framework) indicators and any risk indicator extensions. When a custom framework defines its own depth tier mapping, use that mapping instead of the default table.

Present the suggested depth tier to the user with the rationale (activation count and which indicators activated). The user must confirm the tier before advancing to the next phase. This is a hard gate because tier changes affect framework control loading scope and effort of all downstream phases.

## Classification Output Template

Present classification results using this format:

### Disallowed Components and Sources Gate

| Field               | Value                                                                                 |
|---------------------|---------------------------------------------------------------------------------------|
| Status              | [pending / pass / fail / waived / blocked]                                            |
| Source framework(s) | [framework name(s) evaluated, or "user knowledge" if no frameworks loaded]            |
| Notes               | [if flagged, prohibited category, source framework, and justification for proceeding] |

### Risk Indicator Assessment

| Indicator ID                | Activated  | Method      | Result Summary                 | Tier   | Observation          |
|-----------------------------|------------|-------------|--------------------------------|--------|----------------------|
| `release_blast_radius`      | [Yes / No] | Binary      | [Yes/No]                       | [tier] | [observation or N/A] |
| `dependency_exposure`       | [Yes / No] | Categorical | [None/Limited/Broad/Extensive] | [tier] | [observation or N/A] |
| `compliance_threat_surface` | [Yes / No] | Categorical | [highest dimension category]   | [tier] | [observation or N/A] |
| [extension indicator IDs]   | [Yes / No] | [method]    | [result summary]               | [tier] | [observation or N/A] |

### Suggested Depth Tier

| Field                 | Value                                             |
|-----------------------|---------------------------------------------------|
| Tier                  | [Lightweight / Standard / In-Depth]               |
| Rationale             | [activation count and which indicators activated] |
| Confirmation required | User must confirm tier before advancing.          |

## Indicator Evaluation Guidance

When evaluating indicators:

* Each indicator uses its defined assessment method. Binary indicators produce yes/no results. Categorical indicators assign a level or set of dimension categories.
* Evidence should cite specific repositories, workflows, dependency manifests, signing configurations, or release artifacts that inform the assessment.
* Assessment results capture context needed for downstream phases (assessment, standards mapping, gap analysis, backlog generation).
* When uncertain whether an indicator should activate, ask clarifying questions before recording the result.
* The depth tier flows automatically from the activation count (or from a custom framework's tier mapping). Never assign a tier manually based on judgment.
* When presenting results, explain the activation reasoning with evidence from the project description. Do not present bare results without reasoning.
* All gates default to `pending` and only transition to `pass`, `fail`, `waived`, or `blocked` after explicit evaluation.
