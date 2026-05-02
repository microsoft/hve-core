---
description: >-
  Initiate supply chain security planning from existing BRD artifacts using the
  SSSC Planner agent in from-brd mode
agent: sssc-planner
---

# SSSC from BRD

Activate the SSSC Planner in **from-brd mode** for project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, announce the SSSC Planner standards baseline following the Disclaimer and Attribution Protocol in #file:../../instructions/security/sssc-identity.instructions.md: OpenSSF Scorecard, SLSA Build Levels, OpenSSF Best Practices Badge, Sigstore, and SBOM standards (CycloneDX, SPDX).

## Inputs

* `${input:project-slug}`: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered BRD project name.

## Requirements

### Pre-Scan

Scan the workspace for BRD artifacts and supporting context:

**Primary paths:**

* `.copilot-tracking/brd-sessions/` for business requirements documents

**Secondary scan:**

* `.copilot-tracking/` for files matching `brd-*.md`, `*-brd.md`, or `business-requirements*.md`. Exclude generic matches like `requirements.txt` or files outside business-scoping contexts.

**Supporting context:**

* `package.json`, `pyproject.toml`, `*.csproj`, `Cargo.toml`, `go.mod` — language and package manager inventory.
* `.github/workflows/`, `.azure-pipelines/`, `Jenkinsfile`, `.gitlab-ci.yml` — CI/CD platform.
* `.copilot-tracking/security-plans/`, `.copilot-tracking/rai-plans/`, `.copilot-tracking/prd-sessions/` — sibling planner artifacts to cross-link.
* `.copilot-tracking/sssc-plans/references/` — user-supplied evaluation standards or output format requirements.

Present pre-scan results as a checklist:

* ✅ Discovered BRD artifacts and supporting context with file paths and brief descriptions
* ❌ Expected sources that were not found

If zero BRD artifacts are found, fall back to capture mode and explain the switch.

### Output Preferences

Ask the user up front whether they have output preferences for backlog generation in Phase 5: dual-format ADO and GitHub work items (`both`), ADO-only (`ado`), or GitHub-only (`github`). Capture the answer in `state.json` under `userPreferences.targetSystem` (allowed values: `ado`, `github`, `both`) so later phases honor the choice without re-asking. When the user supplies a custom backlog template, store it under `.copilot-tracking/sssc-plans/references/` and still record the closest matching `targetSystem` value.

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

Also ask whether the user has evaluation standards, workflow inventories, or output format requirements to supply for storage in `.copilot-tracking/sssc-plans/references/`.
