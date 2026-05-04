---
description: >-
  Initiate supply chain security planning from existing PRD artifacts using the
  SSSC Planner agent in from-prd mode
agent: sssc-planner
---

# SSSC from PRD

Activate the SSSC Planner in **from-prd mode** for project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, announce the SSSC Planner standards baseline following the Disclaimer and Attribution Protocol in #file:../../instructions/security/sssc-identity.instructions.md: OpenSSF Scorecard, SLSA Build Levels, OpenSSF Best Practices Badge, Sigstore, and SBOM standards (CycloneDX, SPDX).

## Inputs

* `${input:project-slug}`: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered PRD project name.

## Requirements

### Pre-Scan

Scan the workspace for PRD artifacts and supporting context:

**Primary paths:**

* `.copilot-tracking/prd-sessions/` for product requirements documents

**Secondary scan:**

* `.copilot-tracking/` for files matching `prd-*.md`, `*-prd.md`, or `product-definition*.md`. Exclude generic matches like `requirements.txt` or files outside product-scoping contexts.

**Supporting context:**

* `package.json`, `pyproject.toml`, `*.csproj`, `Cargo.toml`, `go.mod` — language and package manager inventory.
* `.github/workflows/`, `.azure-pipelines/`, `Jenkinsfile`, `.gitlab-ci.yml` — CI/CD platform.
* `.copilot-tracking/security-plans/`, `.copilot-tracking/rai-plans/` — sibling planner artifacts to cross-link.
* `.copilot-tracking/sssc-plans/references/` — user-supplied evaluation standards or output format requirements.

Present pre-scan results as a checklist:

* ✅ Discovered PRD artifacts and supporting context with file paths and brief descriptions
* ❌ Expected sources that were not found

If zero PRD artifacts are found, fall back to capture mode and explain the switch.

### Output Preferences

Ask the user up front whether they have output preferences for backlog generation in Phase 5: dual-format ADO and GitHub work items (`both`), ADO-only (`ado`), or GitHub-only (`github`). Capture the answer in `state.json` under `userPreferences.targetSystem` (allowed values: `ado`, `github`, `both`) so later phases honor the choice without re-asking. When the user supplies a custom backlog template, store it under `.copilot-tracking/sssc-plans/references/` and still record the closest matching `targetSystem` value.

### Scope Extraction

Extract from the discovered PRD artifacts:

1. Project name and supply chain security purpose
2. Technology stack and package managers
3. CI/CD platform and release strategy
4. Deployment targets and registry destinations
5. Compliance requirements and integration points

### Initialization

Create the project directory at `.copilot-tracking/sssc-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"from-prd"`, `currentPhase` set to `1`, preserving `disclaimerShownAt` if already set, and remaining fields populated from the extracted PRD context.

### Phase 1 Entry

Present the extracted scope as a checklist with markers:

* ✅ Items confirmed from the PRD
* ❓ Items that need clarification or are missing

Then invite the user into a Phase 1 conversation with 3 to 5 facilitative clarifying questions targeting supply chain gaps not covered by the PRD, such as runner topology, signing strategy, SBOM tooling, and Best Practices Badge readiness. Use confirmation-and-refinement phrasing rather than directives.

Also ask whether the user has evaluation standards, workflow inventories, or output format requirements to supply for storage in `.copilot-tracking/sssc-plans/references/`.
