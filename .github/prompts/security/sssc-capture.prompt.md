---
description: >-
  Start supply chain security planning from existing knowledge using the
  SSSC Planner agent in capture mode
agent: SSSC Planner
---

# SSSC Capture

## Startup

Display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim at the start of every new project and whenever `disclaimerShownAt` is `null` in `state.json`, before any questions or analysis. After displaying the disclaimer, set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, display the framework attribution `OpenSSF Scorecard • SLSA Build Levels • OpenSSF Best Practices Badge • Sigstore • SBOM`. Display both the disclaimer and the attribution before any questions or analysis.

Activate the SSSC Planner in **capture mode** for project slug `${input:project-slug}`.

The SSSC Planner consults the `supply-chain-security` skill for framework and capabilities-inventory reference content (OpenSSF Scorecard, SLSA, Best Practices Badge, Sigstore, SBOM); do not restate those tables in this prompt.

## Inputs

* `${input:project-slug}`: (Optional) Kebab-case project identifier for the artifact directory. When omitted, ask for a suitable project name and derive the slug.

## Requirements

### Pre-Scan

Before initialization, scan the shared supporting context sources defined in `sssc-planner.instructions.md` to pre-populate Phase 1.

Present pre-scan results as a checklist:

* ✅ Discovered context with file paths and brief descriptions
* ❌ Expected sources that were not found

### Initialization

Create the project directory at `.copilot-tracking/sssc-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"capture"`, `currentPhase` set to `1`, preserving `disclaimerShownAt` if already set, and remaining fields at their schema defaults.

If the user has provided existing supply chain notes, workflow inventories, or compliance documentation, extract relevant details and pre-populate Phase 1 fields where possible.

### Phase 1 Entry

Present a short summary sentence describing the assessment scope, then invite the user into a Phase 1 conversation with 3 to 5 focused questions covering:

* Project name and supply chain security purpose
* Programming languages, frameworks, and package managers
* CI/CD platform and runner topology
* Release strategy and artifact distribution channels
* Deployment targets and registry destinations
* Existing security tooling (Dependabot, CodeQL, secret scanning, signing)
* Compliance targets (Scorecard threshold, SLSA Build level, Best Practices Badge tier)

Use facilitative phrasing — invite confirmation and refinement rather than dictating answers — and mark each question with ❓ pending, ✅ complete, or ❌ blocked or skipped as the conversation progresses.
