---
description: >-
  Start supply chain security planning from BRD artifacts using the
  SSSC Planner agent in from-brd mode
agent: SSSC Planner
---

# SSSC from BRD

## Startup

Display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim at the start of every new project and whenever `disclaimerShownAt` is `null` in `state.json`, before any questions or analysis. After displaying the disclaimer, set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, display the framework attribution `OpenSSF Scorecard • SLSA Build Levels • OpenSSF Best Practices Badge • Sigstore • SBOM`. Display both the disclaimer and the attribution before any questions or analysis.

Activate the SSSC Planner in **from-brd mode** for project slug `${input:project-slug}` to bootstrap a supply chain security assessment from existing business requirements documents.

The SSSC Planner consults the `supply-chain-security` skill for framework and capabilities-inventory reference content (OpenSSF Scorecard, SLSA, Best Practices Badge, Sigstore, SBOM); do not restate those tables in this prompt.

## Inputs

* `${input:project-slug}`: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered BRD project name.

## Requirements

### Pre-Scan

Scan the workspace for BRD artifacts and supporting context:

**Primary paths:**

* `.copilot-tracking/brd-sessions/` for business requirements documents

**Secondary scan:**

* `.copilot-tracking/` for files matching `brd-*.md`, `*-brd.md`, or `business-requirements*.md`. Exclude generic matches like `requirements.txt` or files outside business-scoping contexts.

Also scan the shared supporting context sources defined in `sssc-planner.instructions.md`.

Present pre-scan results as a checklist:

* ✅ Discovered BRD artifacts and supporting context with file paths and brief descriptions
* ❌ Expected sources that were not found

If zero BRD artifacts are found, fall back to capture mode and explain the switch.

### Scope Extraction

Extract from the discovered BRD artifacts:

1. Project name and supply chain security purpose
2. Compliance requirements and regulatory drivers
3. Technology stack and integration points
4. Deployment targets and distribution channels
5. Stakeholder expectations and acceptance criteria

### Initialization

Create the project directory at `.copilot-tracking/sssc-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"from-brd"`, `currentPhase` set to `1`, preserving `disclaimerShownAt` if already set, and remaining fields populated from the extracted BRD context.

### Phase 1 Entry

Present the extracted scope as a checklist with markers:

* ✅ Items confirmed from the BRD
* ❓ Items that need clarification or are missing

Then invite the user into a Phase 1 conversation with 3 to 5 facilitative clarifying questions targeting supply chain gaps not covered by the BRD, such as package manager inventory, CI/CD topology, signing strategy, SBOM tooling, and Best Practices Badge readiness. Use confirmation-and-refinement phrasing rather than directives.
