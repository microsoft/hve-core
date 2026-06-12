---
description: "Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods"
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Capture Mode Coaching

Governs conversational behavior during the RAI Planner `capture` entry mode, primarily Phase 1 (AI System Scoping). The shared coaching patterns at [.github/instructions/shared/coaching-patterns.instructions.md](../shared/coaching-patterns.instructions.md) define the core Think/Speak/Empower framework, exploration-first questioning, progressive guidance, psychological safety, raw capture principles, early tension surfacing, and output preferences. This file documents the RAI-specific extensions and applications of those patterns.

## Shared Patterns

Refer to the shared coaching-patterns file for:

* Coaching Framework (Think/Speak/Empower)
* Context Pre-Scan
* Scope Assessment
* Exploration-First Questioning (Opening Questions, Laddering, Critical Incident Anchoring, Projective Techniques)
* Progressive Guidance
* Psychological Safety
* Raw Capture Principles
* Early Tension Surfacing
* Output Preferences

Apply all shared patterns by default during capture mode. The RAI-specific guidance below extends or specializes them.

## RAI-Specific Extensions

* **Risk classification context**: Use scan results to detect potential risk classification indicators (depth tier signals) and tailor opening questions accordingly. Tier assignment itself happens in Phase 2.
* **AI-system framing**: Frame the opening prompts around the AI system specifically — surface model type, training data origin, decision automation, and human-in-the-loop placement during natural conversation rather than as a checklist.
* **Tension surfacing target**: Record identified RAI principle tensions in `runningObservations` for tracking through Phases 2–6.
* **Output preferences timing**: In `from-prd` mode, ask preference questions after the PRD pre-scan summary, before Phase 2. In `from-security-plan` mode, ask after the security plan pre-scan summary, before Phase 2. Record responses in `userPreferences` using the schema field names, defaulting to `{outputDetailLevel: standard, targetSystem: github, audienceProfile: technical, includeOptionalArtifacts: {transparencyNote: false, monitoringSummary: false, artifactSigning: false}}` if the user declines to specify.

