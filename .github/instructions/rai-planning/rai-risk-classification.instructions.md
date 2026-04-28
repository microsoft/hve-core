---
description: 'Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Risk Classification

Phase 2 screens AI systems for risk using framework skills published under `.github/skills/responsible-ai/`. The prohibited uses gate executes first as a safety-critical check. Risk indicator results determine the suggested assessment depth tier for subsequent phases. Default risk indicators come from the `rai-default-risk-indicators` framework skill; prohibited use definitions come from any framework registered as `consumerKind: prohibited-use-framework` (for example, `eu-ai-act-prohibited-practices`). Custom classification frameworks can replace or extend these defaults.

## Prohibited Uses Gate

The prohibited uses gate is a safety-critical check that executes before risk indicator assessment. When the AI system falls into a prohibited use category defined by an active framework, flag the session immediately and do not proceed to indicator assessment without explicit user acknowledgment.

Prohibited use frameworks vary by regulatory jurisdiction, organizational policy, and deployment context. The planner does not ship inline prohibition definitions; it loads them from framework skills registered with `consumerKind: prohibited-use-framework`. Common candidate sources include:

* EU AI Act Article 5 prohibited practices (shipped as the `eu-ai-act-prohibited-practices` skill).
* Organizational responsible AI policies (internal prohibited-use lists, ethics board determinations).
* Domain-specific regulations (healthcare restrictions on autonomous diagnosis, financial services restrictions on automated credit decisions).
* Regional AI governance frameworks (Singapore Model AI Governance, Canada AIDA, UK AI Regulation).

These examples are illustrative, not exhaustive. The planner does not determine which frameworks apply. Consult your legal and compliance teams to identify the prohibited-use definitions relevant to your deployment context.

### Adding Prohibited Use Frameworks

To incorporate an additional framework's prohibited-use definitions:

1. Publish (or locate) a framework skill under `.github/skills/responsible-ai/<framework-id>/` whose `index.yml` declares the `phase-2-risk-classification` items as prohibition principles.
2. Reference the skill in Phase 1 scoping so it is registered in `state.frameworks[]` with `consumerKind: prohibited-use-framework`.
3. The planner reads only the items listed under `phaseMap.phase-2-risk-classification` and applies the AI processing disclaimer to each.

When a published skill is unavailable, the user can request a Researcher Subagent lookup; the subagent writes the processed definitions to `.copilot-tracking/rai-plans/{project-slug}/references/{framework-name}-prohibited-uses.md` and the planner records the entry in `referencesProcessed[]` with `type: prohibited-use-framework`.

The AI processing disclaimer applies to all retrieved framework content: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

### Evaluating Loaded Prohibited Use Frameworks

Before running the gate, enumerate `state.frameworks[]` for entries with `consumerKind: prohibited-use-framework` and `disabled !== true`. For each:

1. Load the items declared under `phaseMap.phase-2-risk-classification`.
2. Present the framework-specific prohibited categories to the user, attributed to the source skill (cite `skillId` and item id).
3. Evaluate the AI system against each framework's categories.
4. Display the AI processing disclaimer for each framework.

When no prohibited-use frameworks are registered, proceed with the gate protocol using the user's own knowledge of applicable prohibitions.

### Gate Protocol

1. When frameworks were evaluated above, confirm the prohibited use categories already presented and proceed to Step 2. When no prohibited-use frameworks are loaded, ask whether the user's organization or applicable regulations define prohibited AI uses.
2. Ask: "Does the AI system fall into any prohibited use categories defined by your applicable regulations or organizational policies?"
3. If **Yes**: Flag the session, document the prohibited use category and its source framework, and pause. Do not proceed to risk indicator assessment without explicit user acknowledgment and documented justification.
4. If **No**: Proceed to risk indicator assessment.

The gate result is recorded in `state.gateResults.prohibitedUsesGate` with `status` defaulting to `pending` until evaluated. Permitted transitions are `pass`, `flagged`, `waived`, and `blocked`.

## Risk Indicator Extensions

Before beginning indicator assessment, check `state.frameworks[]` for entries with `consumerKind: risk-indicator-extension` (or files in `referencesProcessed[]` with the same `type`). When extensions exist:

1. Present the extension indicators alongside the default indicators.
2. Each extension follows the same item structure: id, description, `assessmentMethod` (binary, categorical, or continuous), gate question, response options, and scoring guidance.
3. Evaluate the AI system against each extension using the assessment method dispatch.
4. Extension results contribute to the activated count for depth tier assignment alongside default indicators.
5. Display the AI processing disclaimer: "AI processed this user-supplied risk indicator extension and may generate inconsistent results. Verify against the original source."

Extensions are always additive. They never replace default indicators, even when a custom framework with `replaceDefaultIndicators: true` is loaded. Extensions augment whichever indicator set is active.

## Risk Indicator Assessment

Evaluate the AI system against the active framework's risk indicators. When no custom framework with `replaceDefaultIndicators: true` is loaded, the default indicators come from the `rai-default-risk-indicators` framework skill (or whichever skill is registered with `consumerKind: risk-indicator-category` in `state.frameworks[]`).

### Loading Indicator Items

1. Resolve `phaseMap.phase-2-risk-classification` for each registered indicator skill.
2. Read **only** those item files; do not enumerate items outside the active phase scope.
3. Append every `read_file` of a skill artifact to `skillsLoaded[]` in `state.json`.

Each item supplies: `id`, `title`, `description`, `assessmentMethod`, `gateQuestion`, `range` (for continuous) or `categories` (for categorical), `gates` (activation thresholds), `evidenceHints[]`, and `mapsTo[]` (cross-framework references such as NIST AI RMF subcategories).

### Evaluating Each Indicator

For each loaded indicator item, route through Assessment Method Dispatch (below) and record the result under `state.riskClassification.indicators.<item-id>` using the dynamic-key shape declared in [`rai-identity.instructions.md`](rai-identity.instructions.md). Capture follow-up context the item's `description` or `gateQuestion` requests (affected domains, severity, mitigations).

The planner does **not** invent indicator semantics, gate questions, or category lists. All such data originates from the per-item YAML.

## Assessment Method Dispatch

Three assessment methods evaluate risk indicators. Each indicator's `assessmentMethod` field selects the route.

| Method      | Input                        | Output                                                                | Use Case                                          |
|-------------|------------------------------|-----------------------------------------------------------------------|---------------------------------------------------|
| Binary      | Yes/No screening question    | `{ activated: boolean, observation: string }`                         | Clear-cut risk presence or absence                |
| Categorical | Multi-level classification   | `{ category: string, matchedDomains: string[], observation: string }` | Graduated impact assessment across defined levels |
| Continuous  | Numeric dimensions (0.0–1.0) | `{ score: number, dimensions: [{name, value}], observation: string }` | Multidimensional risk quantification              |

Each method contributes to the activated count for depth tier assignment using the activation rule declared on the item's `gates` field. Default rules:

| Method      | Default Activation Rule                                                                    |
|-------------|--------------------------------------------------------------------------------------------|
| Binary      | `activated = true` adds 1 to the activated count.                                          |
| Categorical | The categories listed in `gates.activatesOn[]` add 1 (default: any non-baseline category). |
| Continuous  | A score at or above `gates.threshold` (default `0.5`) adds 1.                              |

The dispatch applies identically to default indicators, custom framework indicators, and risk indicator extensions.

## Custom Framework Override

When a custom classification framework with `replaceDefaultIndicators: true` is registered in `state.frameworks[]` (or in `referencesProcessed[]` with `type: risk-classification-framework`), the framework's indicators replace the defaults supplied by `rai-default-risk-indicators`.

Custom framework override rules:

* Custom indicators from the framework's `phaseMap.phase-2-risk-classification` items become the active indicator set for Phase 2.
* Each custom indicator must follow the same per-item schema validated by `scripts/linting/Validate-FsiContent.ps1`.
* When `replaceDefaultIndicators` is absent or `false`, the default indicator skill applies.
* Risk indicator extensions remain additive regardless of this flag.
* When a custom framework defines its own depth tier mapping (in `globals.depthTiers` or equivalent), use that mapping instead of the default count-based tiers.

Loading a custom classification framework via Researcher Subagent (when no skill is published):

1. During Phase 1 (or at any point), tell the agent which framework to use.
2. The agent delegates to the Researcher Subagent to retrieve and process the framework document.
3. The Researcher Subagent writes the processed framework to `.copilot-tracking/rai-plans/{project-slug}/references/{framework-name}-classification.md`.
4. The agent updates `referencesProcessed` in `state.json` with `type: risk-classification-framework`.
5. During Phase 2, the agent reads the framework reference and applies its indicators in place of or alongside the defaults based on the `replaceDefaultIndicators` flag.

The AI processing disclaimer applies: "AI processed this classification framework and may generate inconsistent results. Verify against the original source."

## Code-of-Conduct Cross-Reference

After risk indicators are evaluated, check `state.frameworks[]` for entries with `consumerKind: code-of-conduct` (or `referencesProcessed[]` entries with `type: code-of-conduct`). When code-of-conduct documents are loaded:

1. Read each code-of-conduct reference (skill items or processed reference file).
2. Compare risk indicator results against the provider's acceptable use policies.
3. Flag conflicts where a use case passes risk indicators but violates a provider's acceptable use policy, or where a provider restriction is more stringent than the risk classification result.
4. Document flagged conflicts in the classification output with the provider name, conflicting policy, and recommendation.
5. Display the AI processing disclaimer for each code-of-conduct document.

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

Present classification results using this format (cite the source `skillId` and item id for every row):

### Prohibited Uses Gate

| Field               | Value                                                                                     |
|---------------------|-------------------------------------------------------------------------------------------|
| Status              | [Passed / Flagged]                                                                        |
| Source framework(s) | [framework skillId(s) evaluated, or "user knowledge" if no frameworks loaded]             |
| Notes               | [if flagged, prohibited use category, source framework, and justification for proceeding] |

### Risk Indicator Assessment

| Indicator ID | Source Skill | Activated  | Method                              | Result Summary   | Observation          |
|--------------|--------------|------------|-------------------------------------|------------------|----------------------|
| `<item-id>`  | `<skillId>`  | [Yes / No] | [Binary / Categorical / Continuous] | [result summary] | [observation or N/A] |

Repeat one row per loaded indicator (defaults plus extensions plus custom framework indicators).

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

* Each indicator uses the assessment method declared in its skill item. Do not coerce method types.
* Evidence should cite specific system capabilities, user interactions, or data flows that inform the assessment. Evidence row formatting (path, line span, kind qualifiers) defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.
* Assessment results capture context needed for downstream phases (security model, impact assessment).
* When uncertain whether an indicator should activate, ask clarifying questions before recording the result.
* The depth tier flows automatically from the activation count (or from a custom framework's tier mapping). Never assign a tier manually based on judgment.
* When presenting results, explain the activation reasoning with evidence from the system description. Do not present bare results without reasoning.

## State Update Rules

After Phase 2 evaluation:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Populate `riskClassification.indicators.<item-id>` for each evaluated item using the dynamic-key shape from `rai-identity.instructions.md`.
* Set `riskClassification.activatedCount` to the sum of activated indicators (defaults + extensions + custom).
* Set `riskClassification.suggestedDepthTier` per the Depth Tier Assignment table (or the custom framework's mapping).
* Set `gateResults.prohibitedUsesGate.status` and `sourceFrameworks[]`.
* Advance `currentPhase` to `3` only after the user confirms the suggested depth tier.
