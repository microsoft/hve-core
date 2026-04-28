---
description: 'RAI impact assessment for Phase 5: control surface evaluation, evidence register, tradeoff documentation, and work item generation - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Impact Assessment and Controls

Phase 5 evaluates control surface coverage for each identified threat, documents evidence of existing mitigations, identifies gaps, and analyzes tradeoffs between competing trustworthiness characteristics. This file defines the planner mechanics; the framework content (control surface taxonomy, tradeoff catalog, maturity models, output templates) is supplied by Framework Skills loaded in earlier phases.

## Source-of-Truth Resolution

Control-surface taxonomy, worked tradeoffs, per-characteristic maturity indicators, and artifact output templates are not inlined here. Read them from the Framework Skills enumerated in `state.frameworks[]` at session entry:

* **Control surface taxonomy** — the `rai-control-surface` skill (or any framework skill that exposes items with `itemKind: principle`/`control-surface`). Each item maps a trustworthiness characteristic to Prevent / Detect / Respond control surfaces and includes a maturity ladder.
* **Tradeoffs** — the `rai-tradeoffs` skill (or any framework skill that exposes items with `itemKind: tradeoff`). Each item documents competing characteristics, decision rationale guidance, and compensating-control patterns.
* **Output templates** — the `rai-output-formats` skill. Phase 5 artifacts (control surface catalog, evidence register, tradeoff register) render from `itemKind: output-format` items keyed by phase id `phase-5-impact-assessment`.

When custom or replacement skills are loaded, prefer their items over defaults. Record every consulted skill in `state.skillsLoaded[]` and every emitted artifact in `state.referencesProcessed[]` with `skillId` and `skillVersion`.

## Evidence Register

The evidence register catalogs all mitigations, their coverage status, and supporting documentation. Each entry maps a control to the threat it addresses and the characteristic it serves. Evidence row formatting for every `Evidence Source` reference defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.

### Evidence Fields

Each evidence entry requires these fields:

* Evidence ID: format `EV-{CHARACTERISTIC_ABBR}-{NNN}` where abbreviations are derived from the characteristic id supplied by the active control-surface skill (for the default `rai-control-surface` skill: VR, SAFE, SR, AT, EI, PRIV, FAIR).
* Threat ID: the `T-RAI-{NNN}` identifier from Phase 4 security model analysis.
* Cross-Reference Threat ID: the `T-{BUCKET}-AI-{NNN}` identifier when a Security Planner threat exists.
* Characteristic: the characteristic id surfaced by the active control-surface skill.
* Control Type: Prevent, Detect, or Respond.
* Control Description: what the mitigation does and how it operates.
* Coverage Status: Full, Partial, or Gap.
* Evidence Source: document, test result, audit log, or other artifact that demonstrates the control exists.
* Verification Status: Verified, Unverified, Partially Verified, or N/A. Tracks whether the control has been tested and confirmed to work, distinct from Coverage Status which tracks whether the control exists.
* Notes: additional context including dependencies, assumptions, or known limitations.

### Evidence Register Rules

* Assign a unique Evidence ID to every control entry.
* Reference exactly one Threat ID per entry. Controls that address multiple threats require separate entries.
* Set Coverage Status to Gap when no evidence source exists for the control.
* Review all Gap entries during work item generation.

### Output Detail Levels

When `userPreferences.outputDetailLevel` is set, adjust the evidence register output:

* **summary** — Evidence register captures Evidence ID, Evidence Source, and a one-line summary per entry.
* **standard** — Default behavior. Full evidence fields as defined above.
* **comprehensive** — Full evidence register plus chain-of-custody tracking (who provided the evidence, when, and verification chain) and cross-references to external documents.

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

Appropriate reliance helps ensure users neither over-trust nor under-trust AI-generated outputs. This assessment evaluates whether the system's design calibrates user trust to match the system's actual reliability. Findings produce evidence register entries under the Valid and Reliable or Accountable and Transparent characteristics surfaced by the active control-surface skill.

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

## Per-Characteristic Maturity Assessment

Maturity ladders for each characteristic are defined in the active control-surface skill (default: `rai-control-surface`). Each control-surface item exposes a maturity model with named tiers (typically Foundational → Developing → Established → Advanced) and tier-specific indicators.

### Assessment Rules

* Read the maturity tiers and indicators from the corresponding `rai-control-surface` item for each characteristic in scope.
* Assess each characteristic independently based on evidence gathered during the session.
* Document the rationale for each maturity tier in `state.principleTracker[]`, citing the skill item id and the specific indicator that supports the assessment.
* Characteristics at the lowest tier (e.g. Foundational) suggest work items with Immediate or Near-term priority.
* When presenting maturity tier assessments, explain the reasoning by citing specific observations from the session. Do not present bare maturity tiers without supporting evidence.

## Tradeoff Documentation

Tradeoffs arise when mitigating one trustworthiness characteristic creates tension with another. The catalog of common tradeoffs and their decision patterns is provided by the active tradeoff skill (default: `rai-tradeoffs`).

### Tradeoff Entry Template

Each tradeoff entry recorded during the session includes:

* Tradeoff ID: format `TO-{NNN}`.
* Source Skill Item: the `rai-tradeoffs` (or override) item id this tradeoff instantiates, when applicable.
* Competing Characteristics: the two characteristics in tension.
* Description: what creates the tension and why both characteristics cannot be fully satisfied simultaneously.
* Decision: which characteristic takes priority and under what conditions.
* Compensating Controls: mitigations that reduce the impact on the deprioritized characteristic.
* Residual Risk: remaining exposure after compensating controls are applied.

### Audience Adaptation

When `userPreferences.audienceProfile` is set, adjust tradeoff presentation:

* **technical** — Detailed tradeoff analysis with implementation implications, code-level control descriptions, and specific metric thresholds.
* **executive** — High-level tradeoff summary with business impact focus, risk-to-opportunity framing, and strategic recommendations.
* **mixed** — Tradeoff documentation with regulatory mapping and contextual notes accessible to diverse audiences.

### Tradeoff Discovery

* For each pair of characteristics where evidence-register entries indicate competing demands, consult the active tradeoff skill for an existing pattern before authoring a bespoke entry.
* When the active skill does not contain a matching pattern, author a new `TO-{NNN}` entry inline and flag it in `state.principleTracker[]` so handoff can recommend upstream contribution to the framework skill.

## Suggested Priority Derivation

Priority is derived from the combination of concern levels, trigger severity, and `principleTracker` observations. Never derive priority from numerical scores. The categorical priority ladder and tie-break rules are governed by `.github/instructions/shared/planner-priority-rules.instructions.md`.

### Derivation Rules

* Prohibited use triggers (from Phase 2 risk classification screening) automatically suggest the highest priority tier.
* Concern levels from Phase 4 security model inform priority: High concern → Immediate or Near-term; Moderate concern → Near-term or Planned; Low concern → Planned or Backlog.
* `principleTracker` observations provide supporting evidence for priority selection.
* When multiple signals conflict, select the higher priority and document the reasoning.
* Present all priorities as suggestions for user review — the user makes final priority decisions.

## Work Item Generation

Generate work items from the evidence register for entries with Coverage Status of Gap, and for entries with Coverage Status of Partial when the associated characteristic is at the lowest maturity tier surfaced by the control-surface skill.

### Generation Rules

* Create one work item per evidence register entry with Coverage Status of Gap.
* Create one work item per evidence register entry with Coverage Status of Partial when the associated characteristic is at the lowest maturity tier based on `principleTracker` observations.
* Include the Evidence ID, Threat ID, Characteristic, Control Type, and Control Description in the work item body.
* Reference the Tradeoff ID when the work item involves a documented tradeoff.
* Derive the suggested priority using the Suggested Priority Derivation rules above.

### Work Item Fields

* Title: `[RAI] {Characteristic}: {Control Description summary}`
* Suggested Priority: derived from concern levels, trigger severity, and `principleTracker` observations.
* Evidence ID: the associated evidence register entry.
* Threat ID: the associated threat from Phase 4.
* Characteristic: the trustworthiness characteristic.
* Control Type: Prevent, Detect, or Respond.
* Acceptance Criteria: the condition that moves Coverage Status from Gap or Partial to Full.
* Suggested Remediation Horizon: Pre-Production, Early Operations, or Ongoing Governance.

### Suggested Remediation Horizons

| Horizon            | Description                            | Typical Triggers                                                         |
|--------------------|----------------------------------------|--------------------------------------------------------------------------|
| Pre-Production     | Address before initial deployment      | Safety-critical controls, prohibited use gates, Immediate priority items |
| Early Operations   | Address within first operational cycle | Monitoring controls, user feedback loops, Near-term priority items       |
| Ongoing Governance | Continuous improvement items           | Process refinement, training updates, Planned or Backlog priority items  |

### Horizon Derivation Rules

* Safety-critical controls and controls associated with prohibited use triggers → Pre-Production.
* Monitoring, detection, and feedback controls → Early Operations.
* Process, governance, and training controls → Ongoing Governance.
* When the horizon is uncertain, default to Early Operations with a note explaining the ambiguity.
* Present all horizon suggestions as recommendations for user review.

## Artifact Emission

Phase 5 emits three artifacts (control surface catalog, evidence register, tradeoff register). Render each artifact from the corresponding `itemKind: output-format` item in `rai-output-formats` keyed by `phase-5-impact-assessment`. Do not inline templates in this contract — when the active output-formats skill is missing or does not provide a Phase 5 template, halt and surface the gap to the user before writing files.

Each emitted artifact records its source skill id and version in `state.referencesProcessed[]`.
