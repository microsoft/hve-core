---
description: 'Sensitive uses trigger screening for Phase 2: binary trigger assessment, restricted uses gate, and depth tier assignment'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# Sensitive Uses Trigger Screening

Phase 2 screens AI systems for sensitive use triggers using three binary assessments derived from the Microsoft Responsible AI Impact Assessment Template §3.6. For copyright and intellectual property notices applicable to the Microsoft Responsible AI Impact Assessment Guide, see the Attribution section in `rai-standards.instructions.md`. The restricted uses gate executes first as a safety-critical binary check. Trigger results determine the suggested assessment depth tier for subsequent phases.

## Restricted Uses Gate

The restricted uses gate is a safety-critical binary check that executes before trigger screening. If the AI system falls into a restricted use category defined by applicable regulations or organizational policies, flag the session immediately and do not proceed to trigger screening without explicit user acknowledgment.

Restricted use categories vary by regulatory jurisdiction, organizational policy, and deployment context. Common regulatory frameworks that define restricted or prohibited AI uses include:

* EU AI Act Article 5 (prohibited practices such as social scoring, real-time biometric identification, subliminal manipulation)
* Organizational responsible AI policies (internal restricted use lists, ethics board determinations)
* Domain-specific regulations (healthcare restrictions on autonomous diagnosis, financial services restrictions on automated credit decisions)
* Regional AI governance frameworks (Singapore Model AI Governance, Canada AIDA, UK AI Regulation)

These examples are illustrative, not exhaustive. The planner does not determine which frameworks apply. Consult your legal and compliance teams to identify the restricted use definitions relevant to your deployment context.

### Adding Restricted Use Frameworks

To incorporate a specific regulatory framework's restricted use definitions into the assessment:

1. During Phase 1 (or at any point), tell the agent which framework to evaluate (for example, "Add EU AI Act prohibited practices to this assessment").
2. The agent delegates to the Researcher Subagent to retrieve current restricted use definitions from that framework.
3. The Researcher Subagent writes the processed definitions to `.copilot-tracking/rai-plans/references/{framework-name}-restricted-uses.md`.
4. The agent updates `referencesProcessed` in `state.json` with type `restricted-use-framework`.
5. When the framework is loaded during Phase 2 and the restricted uses gate has not yet concluded, evaluate it immediately before proceeding. On subsequent sessions, the restricted uses gate evaluates automatically against all loaded framework definitions.

The AI processing disclaimer applies to all retrieved framework content: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

### Evaluating Loaded Restricted Use Frameworks

Before running the gate, check `.copilot-tracking/rai-plans/references/` for files with type `restricted-use-framework` in `referencesProcessed` state. When loaded frameworks exist:

1. Read each restricted use framework reference file.
2. Present the framework-specific restricted use categories to the user, attributed to their source.
3. Evaluate the AI system against each framework's categories.
4. Display the AI processing disclaimer for each framework: "AI processed this regulatory framework and may generate inconsistent results. Verify against the original source."

When no restricted use frameworks are loaded, proceed with the gate protocol using the user's own knowledge of applicable restrictions.

### Gate Protocol

1. When frameworks were evaluated above, confirm the restricted use categories already presented and proceed to Step 2. When no restricted use frameworks are loaded, ask whether the user's organization or applicable regulations define restricted AI uses.
2. Ask: "Does the AI system fall into any restricted use categories defined by your applicable regulations or organizational policies?"
3. If **Yes**: Flag the session, document the restricted use category and its source framework, and pause. Do not proceed to trigger screening without explicit user acknowledgment and documented justification.
4. If **No**: Proceed to sensitive use trigger screening.

## User-Supplied Sensitive Use Categories

Before beginning trigger screening, check `.copilot-tracking/rai-plans/references/` for files with type `sensitive-use-category` in `referencesProcessed` state. When user-supplied sensitive use categories exist:

1. Present the custom categories alongside the standard T1/T2/T3 triggers.
2. Evaluate the AI system against each custom category using the same binary (triggered/not triggered) approach.
3. Record custom category results in the screening output with the category name and observation.
4. Custom categories contribute to trigger count for depth tier assignment alongside T1/T2/T3.
5. Display the AI processing disclaimer: "AI processed this user-supplied sensitive use category and may generate inconsistent results. Verify against the original source."

Custom categories do not replace the fixed T1/T2/T3 triggers. They extend the evaluation with additional criteria the user considers relevant to their organizational context.

## Sensitive Use Trigger Screening

Evaluate the AI system against three binary triggers derived from the Microsoft Responsible AI Impact Assessment Template §3.6. Each trigger is binary (triggered or not triggered). There is no partial activation or severity grading within triggers.

### Trigger Table

| Trigger                               | Description                                                                                                                                                                                                                                                      |
|---------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| T1: Legal Status / Life Opportunities | The use or misuse of the AI system could affect an individual's legal status, legal rights, access to credit, education, employment, healthcare, housing, insurance, social welfare benefits/services/opportunities, or the terms on which they are provided.    |
| T2: Physical / Psychological Injury   | The use or misuse of the AI system could result in significant physical or psychological injury to an individual.                                                                                                                                                |
| T3: Human Rights Restrictions         | The use or misuse of the AI system could restrict, infringe upon, or undermine the ability to realize an individual's human rights. Because human rights are interdependent and interrelated, AI can affect nearly every internationally recognized human right. |

### Trigger 1: Legal Status / Life Opportunities (T1)

**Gate question**: Could this system affect a person's legal status, legal rights, or access to credit, education, employment, healthcare, housing, insurance, or social welfare?

If triggered:

1. Which domains are affected (legal, employment, healthcare, etc.)?
2. Who is affected and how many individuals could be impacted?
3. What recourse or appeal mechanisms exist?
4. Record: `sensitiveUsesTriggers.T1_legal_life.triggered = true`, capture observation.

### Trigger 2: Physical / Psychological Injury (T2)

**Gate question**: Could this system cause or contribute to significant physical or psychological injury?

If triggered:

1. What types of injury could occur (physical safety, emotional distress, manipulation)?
2. What severity levels are possible?
3. What safeguards exist or could be implemented?
4. Record: `sensitiveUsesTriggers.T2_injury.triggered = true`, capture observation.

### Trigger 3: Human Rights Restrictions (T3)

**Gate question**: Does this system interact with or make decisions about individuals' human rights, including privacy, transparency, autonomy, or dual-use concerns?

Sub-areas to consider: privacy and surveillance, deception and synthetic content, transparency and disclosure, human autonomy and agency, dual-use and misuse potential.

If triggered:

1. Which human rights areas are affected?
2. What protections exist or could be implemented?
3. What is the power differential between the system and affected individuals?
4. Record: `sensitiveUsesTriggers.T3_human_rights.triggered = true`, capture observation.

## Depth Tier Assignment

The suggested depth tier flows automatically from trigger activation count. Do not assign a tier manually based on judgment.

| Tier          | Criteria              | Description                                                                                                   |
|---------------|-----------------------|---------------------------------------------------------------------------------------------------------------|
| Basic         | 0 triggers activated  | No sensitive use triggers identified. Subsequent phases use baseline analysis depth.                          |
| Standard      | 1 trigger activated   | One sensitive area identified. Subsequent phases include additional analysis for the triggered area.          |
| Comprehensive | 2+ triggers activated | Multiple sensitive areas identified. Subsequent phases use comprehensive analysis across all triggered areas. |

Present the suggested depth tier to the user with the rationale (trigger count). The user must confirm the tier before advancing to Phase 3. This is a hard gate because tier changes affect scope and effort of all downstream phases.

## Screening Output Template

Present screening results using this format:

### Restricted Uses Gate

- **Status**: [Passed / Flagged]
- **Source framework(s)**: [framework name(s) evaluated, or "user knowledge" if no frameworks loaded]
- **Notes**: [if flagged, restricted use category, source framework, and justification for proceeding]

### Trigger Assessment

| Trigger                               | Triggered  | Observation          |
|---------------------------------------|------------|----------------------|
| T1: Legal Status / Life Opportunities | [Yes / No] | [observation or N/A] |
| T2: Physical / Psychological Injury   | [Yes / No] | [observation or N/A] |
| T3: Human Rights Restrictions         | [Yes / No] | [observation or N/A] |

### Suggested Depth Tier

- **Tier**: [Basic / Standard / Comprehensive]
- **Rationale**: [trigger count and which triggers activated]
- **Confirmation required**: User must confirm tier before advancing.

## Trigger Evaluation Guidance

When evaluating triggers:

- Each trigger is binary (triggered or not triggered). There is no partial activation.
- Evidence should cite specific system capabilities, user interactions, or data flows that activate the trigger.
- Depth notes capture the context needed for downstream phases (security model, impact assessment).
- When uncertain whether a trigger applies, ask clarifying questions before recording it.
- The depth tier flows automatically from trigger activation count. Never assign a tier manually based on judgment.

When presenting trigger evaluation results, explain why each trigger was or was not activated by citing specific evidence from the system description. Do not present bare yes/no results without reasoning.

## State Schema Reference

Trigger screening updates the following state fields:

```json
"restrictedUsesGate": {
  "status": "passed",
  "sourceFrameworks": [],
  "notes": null
},
"sensitiveUsesTriggers": {
  "T1_legal_life": { "triggered": false, "observation": null },
  "T2_injury": { "triggered": false, "observation": null },
  "T3_human_rights": { "triggered": false, "observation": null }
},
"triggeredCount": 0,
"suggestedDepthTier": "Basic"
```

Update `triggeredCount` and `suggestedDepthTier` after evaluating all three triggers. The depth tier value must match the Depth Tier Assignment table criteria.
