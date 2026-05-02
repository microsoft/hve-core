---
description: >-
  Extend a Security Planner assessment with supply chain coverage using the
  SSSC Planner agent in from-security-plan mode
agent: sssc-planner
---

# SSSC from Security Plan

Activate the SSSC Planner in **from-security-plan mode** for project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, announce the SSSC Planner standards baseline following the Disclaimer and Attribution Protocol in #file:../../instructions/security/sssc-identity.instructions.md: OpenSSF Scorecard, SLSA Build Levels, OpenSSF Best Practices Badge, Sigstore, and SBOM standards (CycloneDX, SPDX).

## Inputs

* `${input:project-slug}`: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered security plan project name.

## Requirements

### Pre-Scan

Scan the workspace for Security Planner artifacts and supporting context:

**Primary paths:**

* `.copilot-tracking/security-plans/` for Security Planner project subdirectories. Look for `state.json` within each subdirectory. If multiple plans exist, present all candidates to the user for selection.

**Supporting context:**

* `package.json`, `pyproject.toml`, `*.csproj`, `Cargo.toml`, `go.mod` — language and package manager inventory.
* `.github/workflows/`, `.azure-pipelines/`, `Jenkinsfile`, `.gitlab-ci.yml` — CI/CD platform.
* `.copilot-tracking/rai-plans/`, `.copilot-tracking/prd-sessions/`, `.copilot-tracking/brd-sessions/` — sibling planner artifacts to cross-link.
* `.copilot-tracking/sssc-plans/references/` — user-supplied evaluation standards or output format requirements.

Present pre-scan results as a checklist:

* ✅ Discovered security plans and supporting context with file paths and brief descriptions
* ❌ Expected sources that were not found

If zero Security Planner artifacts are found, fall back to capture mode and explain the switch.

### Output Preferences

Ask the user up front whether they have output preferences for backlog generation in Phase 5: dual-format ADO and GitHub work items (`both`), ADO-only (`ado`), or GitHub-only (`github`). Capture the answer in `state.json` under `userPreferences.targetSystem` (allowed values: `ado`, `github`, `both`) so later phases honor the choice without re-asking. When the user supplies a custom backlog template, store it under `.copilot-tracking/sssc-plans/references/` and still record the closest matching `targetSystem` value.

### Scope Extraction

Read the selected Security Planner `state.json` and completed artifacts. Extract:

1. Technology stack and deployment targets
2. Compliance requirements and regulatory drivers
3. Threat model findings and operational buckets
4. Identified security controls and gaps
5. Cross-domain mapping from application-level threats to dependency and build pipeline priorities

### Initialization

Create the project directory at `.copilot-tracking/sssc-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"from-security-plan"`, `currentPhase` set to `1`, `securityPlannerLink` set to the path of the source security plan, preserving `disclaimerShownAt` if already set, and remaining fields populated from the extracted security plan context.

### Phase 1 Entry

Present the extracted scope as a checklist with markers:

* ✅ Items confirmed from the Security Planner artifacts
* ❓ Items that need clarification or are missing

Then invite the user into a Phase 1 conversation with 3 to 5 facilitative clarifying questions targeting supply chain gaps not covered by the security plan, such as package manager inventory, CI/CD pipeline topology, release strategy, signing posture, SBOM tooling, and Best Practices Badge readiness. Use confirmation-and-refinement phrasing rather than directives.

Also ask whether the user has evaluation standards, workflow inventories, or output format requirements to supply for storage in `.copilot-tracking/sssc-plans/references/`.
