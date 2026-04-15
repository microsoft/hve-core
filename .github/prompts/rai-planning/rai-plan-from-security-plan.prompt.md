---
description: >-
  Initiate responsible AI assessment planning from a completed Security Plan using
  the RAI Planner agent in from-security-plan mode (recommended)
agent: "RAI Planner"
---

# RAI Plan from Security Plan

Activate the RAI Planner in **from-security-plan mode**, the recommended workflow for projects that have already completed a security assessment.

Use project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the RAI Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, display the framework attribution following the Session Start Display protocol in #file:../../instructions/rai-planning/rai-identity.instructions.md. When `replaceDefaultFramework` is `false` or `state.json` does not yet exist, announce the default NIST AI RMF 1.0 framework. When `replaceDefaultFramework` is `true`, announce the custom framework by its name from `riskClassification.activeFrameworkProfile.name` in `state.json`.

## Requirements

### Security Plan Discovery

Scan `.copilot-tracking/security-plans/` for directories containing `state.json` files.

Present discovered security plans:

- ✅ Found plans with project slug, current phase, and completion status
- ❌ No security plans found

If zero security plans are found, fall back to capture mode and explain the switch.

If multiple security plans exist, present the list and ask the user to select one.

### State Extraction

Read the selected security plan `state.json` and extract:

1. Project name and system description
2. `aiComponents` array with component details
3. `threatCount` for RAI threat ID sequence continuation
4. Technology stack, deployment targets, and data classification
5. Compliance requirements already identified
6. Operational bucket assignments relevant to AI components

Security plan artifacts are **read-only**. Never modify files under `.copilot-tracking/security-plans/`.

### State Initialization

Create the project directory at `.copilot-tracking/rai-plans/${input:project-slug}/`.

Initialize `state.json` with:

- `entryMode` set to `"from-security-plan"`
- `currentPhase` set to `1`
- `securityPlanRef` pointing to the security plan state.json path
- Pre-populated fields from the extracted security plan
- `raiThreatCount` starting at the security plan's `threatCount` value to continue the ID sequence

### Phase 1 Entry

Present the extracted AI system scope from the security plan as a checklist.

Highlight what the security plan already covers and identify AI-specific context that it does not address, such as:

- Model architecture and training data provenance
- Fairness and bias assessment needs
- Transparency and explainability requirements
- Intended versus unintended use scenarios
- Vulnerable populations and downstream effects

Ask 3 to 5 clarifying questions targeting these AI-specific gaps.

Also ask whether the user has evaluation standards, risk indicator categories, prohibited use frameworks, or output format requirements to supply for storage in `.copilot-tracking/rai-plans/references/`.
