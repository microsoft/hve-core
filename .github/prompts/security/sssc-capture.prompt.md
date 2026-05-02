---
description: >-
  Initiate supply chain security planning from existing knowledge using the
  SSSC Planner agent in capture mode
agent: sssc-planner
---

# SSSC Capture

Activate the SSSC Planner in **capture mode** for project slug `${input:project-slug}`.

## Startup

Before any phase work, check `state.json` for `disclaimerShownAt`. If `disclaimerShownAt` is `null` or `state.json` does not yet exist, display the SSSC Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim and set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, announce the SSSC Planner standards baseline following the Disclaimer and Attribution Protocol in #file:../../instructions/security/sssc-identity.instructions.md: OpenSSF Scorecard, SLSA Build Levels, OpenSSF Best Practices Badge, Sigstore, and SBOM standards (CycloneDX, SPDX).

## Inputs

* `${input:project-slug}`: (Optional) Kebab-case project identifier for the artifact directory. When omitted, ask for a suitable project name and derive the slug.

## Requirements

### Pre-Scan

Before initialization, scan the workspace for context that can pre-populate Phase 1:

* `package.json`, `pyproject.toml`, `*.csproj`, `Cargo.toml`, `go.mod` — language and package manager inventory.
* `.github/workflows/`, `.azure-pipelines/`, `azure-pipelines*.yml`, `Jenkinsfile`, `.gitlab-ci.yml` — CI/CD platform.
* `release-please-config.json`, `.releaserc*`, `CHANGELOG.md` — release strategy.
* `Dockerfile`, `compose.yaml`, `helm/`, `k8s/`, `terraform/`, `bicep/` — deployment surfaces.
* `SECURITY.md`, `.github/dependabot.yml`, CodeQL or secret-scanning configuration — existing security tooling.
* `.copilot-tracking/security-plans/`, `.copilot-tracking/rai-plans/`, `.copilot-tracking/prd-sessions/`, `.copilot-tracking/brd-sessions/` — sibling planner artifacts to cross-link.
* `.copilot-tracking/sssc-plans/references/` — user-supplied evaluation standards, workflow inventories, or output format requirements.

Present pre-scan results as a checklist:

* ✅ Discovered context with file paths and brief descriptions
* ❌ Expected sources that were not found

### Output Preferences

Ask the user up front whether they have output preferences for backlog generation in Phase 5: dual-format ADO and GitHub work items (`both`), ADO-only (`ado`), or GitHub-only (`github`). Capture the answer in `state.json` under `userPreferences.targetSystem` (allowed values: `ado`, `github`, `both`) so later phases honor the choice without re-asking. When the user supplies a custom backlog template, store it under `.copilot-tracking/sssc-plans/references/` and still record the closest matching `targetSystem` value.

### Initialization

Create the project directory at `.copilot-tracking/sssc-plans/${input:project-slug}/`.

Write `state.json` with `entryMode` set to `"capture"`, `currentPhase` set to `1`, preserving `disclaimerShownAt` if already set, and remaining fields at their schema defaults.

If the user has provided existing supply chain notes, workflow inventories, or compliance documentation, extract relevant details and pre-populate Phase 1 fields where possible.

### Phase 1 Entry

Present a short summary sentence describing the assessment scope, then invite the user into a Phase 1 conversation with up to 5 focused questions covering:

* Project name and supply chain security purpose
* Programming languages, frameworks, and package managers
* CI/CD platform and runner topology
* Release strategy and artifact distribution channels
* Deployment targets and registry destinations
* Existing security tooling (Dependabot, CodeQL, secret scanning, signing)
* Compliance targets (Scorecard threshold, SLSA Build level, Best Practices Badge tier)
* User-supplied evaluation standards, workflow inventories, or output format requirements to store in `.copilot-tracking/sssc-plans/references/`

Use facilitative phrasing — invite confirmation and refinement rather than dictating answers — and mark each question with ❓ pending, ✅ complete, or ❌ blocked or skipped as the conversation progresses.
