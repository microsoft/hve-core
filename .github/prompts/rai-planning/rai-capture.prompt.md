---
description: >-
  Initiate responsible AI assessment planning from existing knowledge using the
  RAI Planner agent in capture mode
agent: "RAI Planner"
---

# RAI Capture

Activate the RAI Planner in **capture mode** for project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the RAI Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, display the framework attribution following the Session Start Display protocol in #file:../../instructions/rai-planning/rai-identity.instructions.md. When `replaceDefaultFramework` is `false` or `state.json` does not yet exist, announce the default NIST AI RMF 1.0 framework. When `replaceDefaultFramework` is `true`, announce the custom framework by its name from `riskClassification.activeFrameworkProfile.name` in `state.json`.

## Requirements

Initialize capture mode at `.copilot-tracking/rai-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"capture"`, `currentPhase` set to `1`, preserving `disclaimerShownAt` if already set, and all remaining fields at their schema defaults.

If the user has provided existing AI system notes, model descriptions, or risk context, extract relevant details and pre-populate the system definition where possible.

Begin the Phase 1 AI System Scoping interview with up to 7 focused questions covering:

- AI system purpose and intended outcomes
- AI components and model types (ML models, LLMs, vision, speech)
- Technology stack and deployment context
- Data inputs, outputs, and data flow
- Stakeholder roles (developers, operators, affected individuals)
- Intended and unintended use scenarios
- Known AI-specific risks or concerns
- User-supplied evaluation standards, risk indicator categories, prohibited use frameworks, or output format requirements to store in `.copilot-tracking/rai-plans/references/`

Present a short summary sentence of the assessment scope before asking questions.
