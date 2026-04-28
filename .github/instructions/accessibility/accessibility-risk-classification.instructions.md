---
description: 'Accessibility risk classification model with binary/categorical indicators, depth tiering, and gate rules consumed by Phase 2 surface assessment.'
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Risk Classification

Risk classification screens the target surface before standards mapping. The prohibited uses and surfaces gate executes first as a safety-critical check. Risk indicator results determine the suggested depth tier for subsequent phases, and the depth tier in turn determines which Framework Skills load and which capability inventory checks are mandatory. By default, indicators derive from regulatory exposure, surface kind, audience composition, and concept maturity. Custom classification frameworks can replace or extend these defaults.

## Prohibited Uses and Surfaces Gate

The prohibited uses and surfaces gate is a safety-critical check that executes before risk indicator assessment. When the project ships patterns or surfaces that are prohibited by applicable accessibility regulations or organizational accessibility policy, flag the session immediately and do not proceed to indicator assessment without explicit user acknowledgment.

Prohibited categories vary by regulatory jurisdiction, organizational policy, and deployment context. Common frameworks that define prohibited accessibility practices include:

* Sensory-exclusionary patterns banned under the European Accessibility Act (EAA) consumer-product scope (e.g., information conveyed by color or sound alone with no equivalent alternative).
* Procurement disqualifiers under US Section 508 (kiosks lacking the operable-by-touch and audio-output requirements of §1194.25) and AODA (Ontario Integrated Accessibility Standards) for public-sector procurement.
* Dark patterns and accessibility-defeating designs prohibited under EAA Article 4 (deceptive interface patterns that exploit assistive-technology behavior).
* Biometric-only authentication or CAPTCHA challenges with no accessible alternative (WCAG 2.2 SC 3.3.8 / 3.3.9 baseline obligations).
* Organizational accessibility policy (banned UI patterns, mandatory contrast minimums, prohibited use of motion or autoplay without user control).

These examples are illustrative, not exhaustive. The planner does not determine which frameworks apply. Consult your legal, compliance, and accessibility teams to identify the prohibited pattern definitions relevant to your deployment context.

### Adding Prohibited Pattern Frameworks

To incorporate a specific framework's prohibited pattern definitions into the assessment:

1. During Phase 1 (or at any point), tell the agent which framework to evaluate (for example, "Add EAA dark-pattern prohibitions to this assessment").
2. The agent delegates to the Researcher Subagent to retrieve current prohibited pattern definitions from that framework.
3. The Researcher Subagent writes the processed definitions to `.copilot-tracking/accessibility-plans/references/{framework-name}-prohibited-patterns.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `prohibited-pattern-framework`.
5. When the framework is loaded during Phase 2 and the gate has not yet concluded, evaluate it immediately before proceeding. On subsequent sessions, the gate evaluates automatically against all loaded framework definitions.

The AI processing disclaimer applies to all retrieved framework content: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

### Evaluating Loaded Prohibited Pattern Frameworks

Before running the gate, check `.copilot-tracking/accessibility-plans/references/` for files with type `prohibited-pattern-framework` in `referencesProcessed` state. When loaded frameworks exist:

1. Read each prohibited pattern framework reference file.
2. Present the framework-specific prohibited categories to the user, attributed to their source.
3. Evaluate the project against each framework's categories.
4. Display the AI processing disclaimer for each framework: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

When no prohibited pattern frameworks are loaded, proceed with the gate protocol using the user's own knowledge of applicable prohibitions.

### Gate Protocol

1. When frameworks were evaluated above, confirm the prohibited pattern categories already presented and proceed to Step 2. When no prohibited pattern frameworks are loaded, ask whether the user's organization or applicable regulations define prohibited accessibility patterns or surfaces.
2. Ask: "Does this project ship any pattern, surface, or interaction that falls into a prohibited accessibility category defined by your applicable regulations or organizational policy?"
3. If **Yes**: Flag the session, document the prohibited category and its source framework, and pause. Do not proceed to risk indicator assessment without explicit user acknowledgment and documented justification.
4. If **No**: Proceed to risk indicator assessment.

The gate result is recorded in `state.json` as `riskClassification.prohibitedGate` with `status` defaulting to `pending` until evaluated. Permitted transitions are `pass`, `fail`, `waived`, and `blocked`.

## Risk Indicator Extensions

Before beginning indicator assessment, check `.copilot-tracking/accessibility-plans/references/` for files with type `risk-indicator-extension` in `referencesProcessed` state. When risk indicator extensions exist:

1. Present the extension indicators alongside the default accessibility indicators.
2. Each extension follows the same indicator structure: description, assessment method type (binary or categorical), gate question, response options, and scoring guidance.
3. Evaluate the project against each extension using the assessment method dispatch.
4. Extension results contribute to the activated count for depth tier assignment alongside default indicators.
5. Display the AI processing disclaimer: "AI processed this user-supplied risk indicator extension and may generate inconsistent results. Verify against the original source."

Extensions are always additive. They never replace default indicators, even when a custom framework with `replaceDefaultIndicators: true` is loaded.

## Risk Indicator Assessment

Evaluate the project against the active framework's risk indicators. When no custom framework with `replaceDefaultIndicators: true` is loaded, use the six default accessibility indicators below.

### Default Indicator Table

| Indicator ID                 | Domain Source                                                                  | Method      | Domain                                                                            |
|------------------------------|--------------------------------------------------------------------------------|-------------|-----------------------------------------------------------------------------------|
| `regulated_jurisdiction`     | EAA, US Section 508, AODA (Ontario), Australian DDA, public-sector procurement | Binary      | Statutory or contractual accessibility obligation in any deployment jurisdiction. |
| `surface_kind`               | WCAG 2.2 conformance scope, EN 301 549 surface taxonomy                        | Categorical | Class of artifact under assessment (web app, content site, mobile, kiosk, voice). |
| `audience`                   | EAA Article 2 consumer scope, Section 508 federal-procurement scope            | Categorical | Reachability and statutory protection level of the user population.               |
| `user_population_indicators` | W3C COGA, WCAG 2.2 disability profiles                                         | Categorical | Disability profiles known or expected to be material to the user base.            |
| `audience_size`              | Public-impact heuristics, internal user-count estimates                        | Categorical | Estimated reach classified into one of four brackets.                             |
| `concept_stage`              | Product lifecycle (mvp, ga, mature)                                            | Categorical | Maturity-driven obligation pressure (later stages carry stronger obligations).    |

### Regulated Jurisdiction (`regulated_jurisdiction`)

Assessment method: Binary (Yes/No). Domain source: EAA, US Section 508, AODA, Australian DDA, public-sector procurement triggers.

**Gate question**: Does this surface ship into any jurisdiction or contract scope that imposes a statutory or procurement-driven accessibility obligation?

If activated (Yes):

1. Which jurisdictions or contract regimes apply (EAA, Section 508, AODA, DDA, internal procurement standard)?
2. What conformance level does each obligation reference (WCAG 2.2 AA is the most common floor)?
3. Which evidentiary artifacts are required (VPAT/ACR, EN 301 549 self-assessment, EAA technical file)?
4. Record: `riskClassification.indicators.regulated_jurisdiction.activated = true`, `result.jurisdictions[]`, observation.

If not activated (No): Record the observation explaining why no statutory or procurement obligation applies.

### Surface Kind (`surface_kind`)

Assessment method: Categorical. Domain source: WCAG 2.2 conformance scope and EN 301 549 surface taxonomy.

**Gate question**: Which surface class best describes this project?

Categories: `web-app`, `content-site`, `mobile-web`, `hybrid-mobile`, `native-mobile`, `internal-tool`, `kiosk`, `voice-only`.

The following categories count as activated for depth tier purposes:

| Category        | Counts as activated | Rationale                                                                             |
|-----------------|---------------------|---------------------------------------------------------------------------------------|
| `web-app`       | Yes                 | Custom widgets and dynamic state engage ARIA APG patterns and AA-level criteria.      |
| `content-site`  | Yes                 | Cognitive-load and reading-experience criteria apply to public content surfaces.      |
| `mobile-web`    | Yes                 | Combines web-app obligations with mobile gesture and orientation criteria.            |
| `hybrid-mobile` | Yes                 | Web and platform-native overlays must each satisfy applicable platform criteria.      |
| `native-mobile` | Yes                 | Platform a11y APIs apply; capability inventory must include platform-native scanners. |
| `internal-tool` | No (default)        | Lower default obligation; can re-activate via `regulated_jurisdiction` or audience.   |
| `kiosk`         | Yes                 | Section 508 §1194.25 hardware obligations apply by default; tier floor is Tier 2.     |
| `voice-only`    | Yes                 | EN 301 549 §6 voice-output and §5.5 mechanical-operation criteria apply.              |

When activated, capture: surface class, primary platforms in scope, custom-widget inventory (if any), and known assistive-technology constraints.

Record: `riskClassification.indicators.surface_kind.activated`, `result.category`, `result.matchedDomains[]`, observation.

### Audience (`audience`)

Assessment method: Categorical. Domain source: EAA Article 2 consumer scope, Section 508 federal-procurement scope.

**Gate question**: Who can reach this surface?

Categories: `public`, `regulated`, `internal-only`.

Activation rule: `public` and `regulated` count as activated. `internal-only` does not, unless combined with `regulated_jurisdiction = true`.

Capture: deployment scope (open internet, partner portal, federal contract), user-onboarding gates, identity model.

Record: `riskClassification.indicators.audience.activated`, `result.category`, observation.

### User Population Indicators (`user_population_indicators`)

Assessment method: Categorical (multi-select). Domain source: W3C COGA, WCAG 2.2 disability profiles.

**Gate question**: Which disability profiles are known or expected to be material to this user base?

Multi-select options: `cognitive-load-sensitive`, `motor-impairment`, `sensory-low-vision`, `sensory-blind`, `sensory-deaf`, `hard-of-hearing`.

Activation rule: any selection counts as activated. Selecting `cognitive-load-sensitive` additionally raises the Tier 3 trigger when combined with `audience = public` and `regulated_jurisdiction = true`.

Capture: evidence supporting each selected profile (research, support tickets, regulatory mandate, reasonable inference for the deployment context). When the user cannot speak to the population, default to enabling all profiles and record the assumption.

Record: `riskClassification.indicators.user_population_indicators.activated`, `result.profiles[]`, observation.

### Audience Size (`audience_size`)

Assessment method: Categorical (single-select). Domain source: public-impact heuristics, internal user-count estimates.

**Gate question**: How many people can reasonably be expected to reach this surface within its deployment lifetime?

Brackets:

| Bracket          | Notes                                                             |
|------------------|-------------------------------------------------------------------|
| < 1,000          | Small internal tool, prototype, single-team workflow.             |
| 1,000–10,000     | Department or mid-sized customer base.                            |
| 10,000–1,000,000 | Public product, regulated workflow, regional public-sector reach. |
| > 1,000,000      | Global consumer surface, national public-sector deployment.       |

Activation rule: `10,000–1,000,000` and `> 1,000,000` count as activated. When the user cannot estimate, record `confidence: low` and pick the most plausible bracket.

Record: `riskClassification.indicators.audience_size.activated`, `result.bracket`, `result.confidence`, observation.

### Concept Stage (`concept_stage`)

Assessment method: Categorical (single-select). Domain source: product lifecycle (mvp, ga, mature).

**Gate question**: What is the current lifecycle stage of this surface?

Stages:

| Stage    | Description                                                                    |
|----------|--------------------------------------------------------------------------------|
| `mvp`    | Pre-GA, validated prototype, narrow user pool.                                 |
| `ga`     | General availability with active customer base and external commitments.       |
| `mature` | Long-lived surface with regulatory history, support contracts, certifications. |

Activation rule: `ga` and `mature` count as activated. `mvp` does not activate by default.

Record: `riskClassification.indicators.concept_stage.activated`, `result.stage`, observation.

## Assessment Method Dispatch

Two assessment methods evaluate risk indicators. Each indicator specifies its method type, and the dispatch routes evaluation accordingly.

| Method      | Input                     | Output                                                                 | Use Case                                             |
|-------------|---------------------------|------------------------------------------------------------------------|------------------------------------------------------|
| Binary      | Yes/No screening question | `{ activated: boolean, observation: string }`                          | Clear-cut presence or absence of an obligation.      |
| Categorical | Single or multi-select    | `{ category|profiles, matchedDomains: string[], observation: string }` | Graduated exposure assessment across defined levels. |

Each method contributes to the activated count for depth tier assignment:

| Method      | Activation Rule                                                                   |
|-------------|-----------------------------------------------------------------------------------|
| Binary      | `activated = true` adds 1 to the activated count.                                 |
| Categorical | An activating category (per the indicator's table) adds 1 to the activated count. |

The dispatch applies identically to default indicators, custom framework indicators, and risk indicator extensions.

## Risk Tiers

Each indicator result is mapped to a risk tier used downstream by gap analysis and backlog generation when prioritizing remediation work.

| Tier     | Source                                                                                         | Downstream Use                                     |
|----------|------------------------------------------------------------------------------------------------|----------------------------------------------------|
| Critical | Prohibited gate failure, or any activated indicator combined with regulated public deployment. | Immediate remediation; blocks final handoff.       |
| High     | Two or more activated indicators, or activation including `regulated_jurisdiction = true`.     | Prioritized in next backlog increment.             |
| Medium   | Single activated indicator, or `cognitive-load-sensitive` profile selected.                    | Scheduled remediation in upcoming sprint.          |
| Low      | No activated indicators but elevated context (for example, planned public launch).             | Tracked in backlog; opportunistic remediation.     |
| Info     | No activated indicators and no elevated context.                                               | Documented for awareness; no remediation required. |

Risk tier values are recorded in `state.json` as `riskClassification.indicators[<id>].tier`. The tier value is informational; it does not gate phase advancement on its own.

## Gate Model

Gates are the controlled transition points used by the planner across phases. All gates default to `pending` and accept the following terminal states:

| State   | Meaning                                                                                                   |
|---------|-----------------------------------------------------------------------------------------------------------|
| pending | Gate has not yet been evaluated.                                                                          |
| pass    | Gate evaluated and met its acceptance criteria.                                                           |
| fail    | Gate evaluated and did not meet its acceptance criteria; remediation is required.                         |
| waived  | Gate evaluated as `fail` but explicitly waived by the user with documented justification in `state.json`. |
| blocked | Gate cannot be evaluated due to missing inputs, missing references, or downstream dependency failures.    |

Gate state is persisted in `state.json` under `riskClassification.prohibitedGate` and `riskClassification.indicators[<id>].gate`. The planner refuses to advance phases when any gate required for the next phase remains `pending` or `blocked`. Waivers must include a `justification` field and the user identity that approved the waiver.

## Custom Framework Override

When a custom classification framework with `replaceDefaultIndicators: true` is loaded via `referencesProcessed` with type `risk-classification-framework`, the framework's indicators replace the six default accessibility indicators.

Custom framework override rules:

* Custom indicators from the framework's Risk Indicators section become the active indicator set for risk classification.
* Each custom indicator must follow the same structure: ID, method type (binary or categorical), gate question, response options, and scoring guidance.
* When `replaceDefaultIndicators` is absent or `false`, the default accessibility indicators apply.
* Risk Indicator Extensions (type `risk-indicator-extension`) remain additive regardless of this flag.
* When a custom framework defines its own depth tier mapping, use that mapping instead of the default combination table.

Loading a custom classification framework:

1. During Phase 1 (or at any point), tell the agent which framework to use (for example, "Use our internal accessibility risk classification framework").
2. The agent delegates to the Researcher Subagent to retrieve and process the framework document.
3. The Researcher Subagent writes the processed framework to `.copilot-tracking/accessibility-plans/references/{framework-name}-classification.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `risk-classification-framework`.
5. During risk classification, the agent reads the framework reference and applies its indicators in place of or alongside the defaults based on the `replaceDefaultIndicators` flag.

The AI processing disclaimer applies: "AI processed this classification framework and may generate inconsistent results. Verify against the original source."

## Depth Tier Assignment

The suggested depth tier flows from the indicator combination table below. Do not assign a tier manually based on judgment.

| Tier            | Trigger                                                                                                                                                                                                              | Description                                                                                 |
|-----------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| Tier1Foundation | `regulated_jurisdiction = false` AND `audience = internal-only` AND `surface_kind ∈ {internal-tool}` AND `concept_stage < 0.5` (mvp).                                                                                | WCAG 2.2 level A only. Default for internal mvp tooling without statutory exposure.         |
| Tier2Standard   | Any of: `audience ∈ {public, regulated}`; `regulated_jurisdiction = true`; `surface_kind ∈ {kiosk, voice-only}`; `concept_stage >= 0.5` AND `audience_size >= 0.5`.                                                  | WCAG 2.2 level A + AA. Default for any public-facing surface or any regulated jurisdiction. |
| Tier3Enhanced   | Any of: (`audience = public` AND `regulated_jurisdiction = true` AND `cognitive-load-sensitive` selected); (`regulated_jurisdiction = true` AND EAA scope AND `surface_kind = content-site`); explicit user request. | WCAG 2.2 A + AA + applicable AAA + cognitive-accessibility overlay.                         |

Tier evaluation is a top-down lookup: evaluate Tier 3 triggers first, then Tier 2, then default to Tier 1. The first matching tier wins.

Present the suggested depth tier to the user with the rationale (which combination triggered which tier). The user must confirm the tier before advancing. This is a hard gate because tier changes affect Framework Skill loading scope and effort of all downstream phases.

## Framework-to-Tier Mapping

Each tier loads a specific subset of Wave 1 Framework Skills. Framework IDs match the `framework` value declared in each skill's `index.yml`.

| Tier            | Loaded Framework Skills (by `framework-id`)                                                          | Subset Filter                                                                                                                                                                                     |
|-----------------|------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Tier1Foundation | `wcag-2-2`, `capability-inventory-web`                                                               | `wcag-2-2`: items where `conformanceLevel = A`. `capability-inventory-web`: automated subset only.                                                                                                |
| Tier2Standard   | `wcag-2-2`, `aria-apg`, `capability-inventory-web`                                                   | `wcag-2-2`: items where `conformanceLevel ∈ {A, AA}`. `aria-apg`: full inventory. `capability-inventory-web`: full inventory.                                                                     |
| Tier3Enhanced   | `wcag-2-2`, `aria-apg`, `cognitive-a11y`, `capability-inventory-web`, `capability-inventory-content` | `wcag-2-2`: items where `conformanceLevel ∈ {A, AA}` plus AAA items whose `appliesTo` matches the surface kind. `cognitive-a11y`: full inventory. `capability-inventory-content`: full inventory. |

Surface-kind exclusions override tier loading:

* `surface_kind = voice-only` excludes visual-presentation items (`wcag-2-2` items in guideline `1.4` whose `appliesTo` does not include `voice`).
* `surface_kind = content-site` excludes interaction-pattern items (`aria-apg` items whose `appliesTo` is restricted to interactive widgets) unless the content site embeds custom widgets.
* `surface_kind = kiosk` adds Section 508 §1194.25 hardware-obligation items when the `section-508` Framework Skill is loaded as an extension; the default Wave 1 set does not include hardware items.

## Gate Rules for Surface Assessment

Phase 2 surface assessment consumes these rules to decide which capability inventory checks are mandatory, which are optional, and which surface kinds are out of scope for which check classes.

### Mandatory checks per tier

| Tier            | Mandatory `capability-inventory-web` checks                                                                                                                                                                  | Mandatory `capability-inventory-content` checks                                                                                                                                          |
|-----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Tier1Foundation | `axe-core-ci` (or equivalent automated runner from the `web-automated-a11y` alternative group).                                                                                                              | None.                                                                                                                                                                                    |
| Tier2Standard   | Tier 1 mandatory plus `eslint-jsx-a11y` (or static-analysis equivalent) and one manual-AT touchpoint (`nvda-manual`, `jaws-manual`, `voiceover-manual`, or `talkback-manual` matching the surface platform). | None unless `surface_kind = content-site`, in which case `vale` and one readability metric (any of `textstat-flesch-kincaid`, `textstat-smog`, `textstat-coleman-liau`, `textstat-ari`). |
| Tier3Enhanced   | Tier 2 mandatory plus `accessibility-insights-assessment` (or equivalent guided-assessment tool) and `apca-contrast` when contrast obligations apply.                                                        | Tier 2 mandatory plus `alex`, `error-recovery-flow-review`, and `terminology-glossary-check`.                                                                                            |

When a mandatory check has multiple acceptable implementations (alternative group), satisfying any one member of the group satisfies the requirement.

### Optional checks per tier

All `capability-inventory-web` and `capability-inventory-content` items not listed as mandatory at the active tier are optional. Optional items appear in gap analysis as opportunities, not as failing gates.

### Surface-kind exclusions

| Surface kind    | Excluded check classes                                                                              | Reason                                                        |
|-----------------|-----------------------------------------------------------------------------------------------------|---------------------------------------------------------------|
| `voice-only`    | Visual-contrast checks (`wcag-contrast-2x`, `apca-contrast`); visual-presentation `wcag-2-2` items. | No visual surface to evaluate.                                |
| `kiosk`         | Browser-bound automated runners (`pa11y-ci`, `lighthouse-a11y-ci`).                                 | Kiosk surface is not a browsable URL set.                     |
| `native-mobile` | Web-targeted runners (`axe-core-ci` web mode, `pa11y-ci`, `lighthouse-a11y-ci`).                    | Use platform-native scanners loaded as inventory extensions.  |
| `internal-tool` | `nu-html-checker` (markup conformance) when not externally distributed.                             | Markup conformance not enforced for non-distributed surfaces. |

### Gate consumption contract

Phase 2 surface assessment reads the active tier from `state.json:riskClassification.depthTier`, then:

1. Loads the Framework Skills listed in the Framework-to-Tier Mapping for that tier, applying the subset filter.
2. Loads the mandatory check list for that tier from this section.
3. Applies surface-kind exclusions to remove non-applicable checks before evaluation.
4. Records each mandatory check as a gate under `surfaceAssessment.gates[<check-id>]`, defaulting to `pending`.
5. Optional checks are recorded under `surfaceAssessment.opportunities[<check-id>]`.

The surface-assessment instructions reference this file via `#file:` to inherit these rules; do not duplicate the tables.

## Classification Output Template

Present classification results using this format:

### Prohibited Uses and Surfaces Gate

| Field               | Value                                                                                 |
|---------------------|---------------------------------------------------------------------------------------|
| Status              | [pending / pass / fail / waived / blocked]                                            |
| Source framework(s) | [framework name(s) evaluated, or "user knowledge" if no frameworks loaded]            |
| Notes               | [if flagged, prohibited category, source framework, and justification for proceeding] |

### Risk Indicator Assessment

| Indicator ID                 | Activated  | Method      | Result Summary                                         | Tier   | Observation          |
|------------------------------|------------|-------------|--------------------------------------------------------|--------|----------------------|
| `regulated_jurisdiction`     | [Yes / No] | Binary      | [jurisdictions list or "none"]                         | [tier] | [observation or N/A] |
| `surface_kind`               | [Yes / No] | Categorical | [web-app / content-site / mobile-web / … / voice-only] | [tier] | [observation or N/A] |
| `audience`                   | [Yes / No] | Categorical | [public / regulated / internal-only]                   | [tier] | [observation or N/A] |
| `user_population_indicators` | [Yes / No] | Categorical | [profiles selected]                                    | [tier] | [observation or N/A] |
| `audience_size`              | [Yes / No] | Categorical | [bracket]                                              | [tier] | [observation or N/A] |
| `concept_stage`              | [Yes / No] | Categorical | [mvp / ga / mature]                                    | [tier] | [observation or N/A] |
| [extension indicator IDs]    | [Yes / No] | [method]    | [result summary]                                       | [tier] | [observation or N/A] |

### Suggested Depth Tier

| Field                 | Value                                                             |
|-----------------------|-------------------------------------------------------------------|
| Tier                  | [Tier1Foundation / Tier2Standard / Tier3Enhanced]                 |
| Trigger matched       | [which row of the Depth Tier Assignment table fired]              |
| Frameworks loaded     | [comma-separated framework-ids per the Framework-to-Tier Mapping] |
| Confirmation required | User must confirm tier before advancing.                          |

## Indicator Evaluation Guidance

When evaluating indicators:

* Each indicator uses its defined assessment method. Binary indicators produce yes/no results. Categorical indicators assign a level, bracket, or set of profiles.
* Evidence should cite specific surfaces, repositories, design files, user-research artifacts, or regulatory references that inform the assessment. Evidence row formatting (path, line span, kind qualifiers) defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.
* Assessment results capture context needed for downstream phases (surface assessment, standards mapping, gap analysis, backlog generation).
* When uncertain whether an indicator should activate, ask clarifying questions before recording the result.
* The depth tier flows from the combination table (or from a custom framework's tier mapping). Never assign a tier manually based on judgment.
* When presenting results, explain the activation reasoning with evidence from the project description. Do not present bare results without reasoning.
* All gates default to `pending` and only transition to `pass`, `fail`, `waived`, or `blocked` after explicit evaluation.
