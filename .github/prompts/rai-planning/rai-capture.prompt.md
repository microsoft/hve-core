---
description: >-
  Initiate a responsible AI assessment from existing knowledge using the
  RAI Planner agent in capture mode
agent: rai-planner
---

# RAI Capture

Activate the RAI Planner in **capture mode** for project slug `${input:project-slug}`.

## Requirements

Initialize capture mode at `.copilot-tracking/rai-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"capture"`, `currentPhase` set to `1`, and all other fields at their default empty values.

If the user has provided existing AI system notes, model descriptions, or risk context, extract relevant details and pre-populate the system definition where possible.

Begin the Phase 1 AI System Scoping interview with up to 7 focused questions covering:

- AI system purpose and intended outcomes
- AI components and model types (ML models, LLMs, vision, speech)
- Technology stack and deployment context
- Data inputs, outputs, and data flow
- Stakeholder roles (developers, operators, affected individuals)
- Intended and unintended use scenarios
- Known AI-specific risks or concerns

Present a short summary sentence of the assessment scope before asking questions.
