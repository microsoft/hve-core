<!-- markdownlint-disable-file -->

---
description: "Validation spec for VEX Workflow (#1220) and VEX Generation Agent (#1221)"
---

# VEX Implementation — Validation Spec

Companion to the implementation plan at `.copilot-tracking/plans/2026-04-29/vex-workflow-and-agent-plan.instructions.md`. Each criterion maps to a phase and step. Validators check the box when the criterion passes.

## Phase 1: VEX Foundation (Plumbing)

### P1-FILE: VEX Document

- [ ] File exists at `security/vex/hve-core.openvex.json`
- [ ] Valid JSON that parses without error
- [ ] Contains required OpenVEX fields:
  - `@context` equals `https://openvex.dev/ns/v0.2.0`
  - `@id` is a string starting with `https://github.com/microsoft/hve-core/`
  - `author` is a non-empty string
  - `timestamp` is a valid ISO 8601 datetime
  - `statements` is an array (may be empty for initial document)
- [ ] `products` array (when statements exist) uses PURL format: `pkg:npm/@microsoft/hve-core`

### P1-CODEOWNERS: Ownership

- [ ] `.github/CODEOWNERS` contains a line matching `/security/vex/` with an owner group
- [ ] Owner group is a valid GitHub team reference (e.g., `@microsoft/edge-ai-core-dev`)

### P1-TEMPLATE: PR Template

- [ ] File exists at `.github/PULL_REQUEST_TEMPLATE/vex-triage.md`
- [ ] Contains a confidence-band field (one of: High not_affected, High affected, Medium, Low, Vendor-disputed)
- [ ] Contains an evidence checklist section
- [ ] Contains a VEX status field

### P1-CSPELL: Spelling Dictionary

- [ ] `.cspell/general-technical.txt` contains `openvex` (case-insensitive match)
- [ ] `.cspell/general-technical.txt` contains `osv` (case-insensitive match)
- [ ] Entries are in alphabetical order within the file

### P1-INSTRUCTIONS: VEX Standards

- [ ] File exists at `.github/instructions/security/vex-standards.instructions.md`
- [ ] Has valid YAML frontmatter with `description` and `applyTo` fields
- [ ] Contains the 5-band confidence routing table with columns: Band, Criteria, Agent Action, Human Action
- [ ] Contains forbidden transitions section listing:
  - `unknown reachability → not_affected` as forbidden
  - `unknown reachability → affected` as forbidden
  - Default for uncertain cases = `under_investigation`
- [ ] Contains licensing posture section (OSV.dev CC0 preferred, NVD public domain, GHSA CC-BY-4.0 avoid quoting)
- [ ] Contains author-of-record contract (merge commit author = accountable author)

### P1-RELEASE: Pipeline Integration

- [ ] `release-stable.yml` `attest-and-upload` job contains a step that attests VEX file using `actions/attest`
- [ ] `release-stable.yml` `attest-and-upload` job uploads VEX file via `gh release upload`
- [ ] `release-stable.yml` `append-verification-notes` references VEX in the verification section
- [ ] All new action references are SHA-pinned with version comments

### P1-VALIDATE: Automated Checks

- [ ] `npm run spell-check` passes (no new spelling errors)
- [ ] `npm run lint:md` passes (no markdown lint errors in new/modified files)
- [ ] `npm run lint:frontmatter` passes (frontmatter valid in new instructions files)
- [ ] `npm run lint:yaml` passes

## Phase 2: OpenVEX Skill + VEX Generation Instructions

### P2-SKILL: OpenVEX Spec Skill

- [x] `SKILL.md` exists at `.github/skills/security/openvex-spec/SKILL.md`
- [x] Has valid YAML frontmatter with `name: openvex-spec`, `description`, `license`, `user-invocable: false`, and `metadata` block
- [x] Lists normative references pointing to files in `references/` subdirectory
- [x] References directory contains:
  - `openvex-schema.md` — JSON schema reference with field definitions
  - `vex-status-logic.md` — Status determination decision tree
  - `cve-data-sources.md` — OSV.dev, NVD, GHSA API references with licensing
- [x] Each reference file has valid YAML frontmatter

### P2-INSTRUCTIONS: VEX Generation

- [x] File exists at `.github/instructions/security/vex-generation.instructions.md`
- [x] Has valid YAML frontmatter with `description` and `applyTo` fields
- [x] Contains evidence requirements per VEX status:
  - `not_affected`: requires code citation (file + line range) or mitigation reference
  - `affected`: requires reachable execution path or runtime invocation evidence
  - `under_investigation`: no evidence required (safe default)
  - `fixed`: requires version reference where fix was applied
- [x] Contains confidence-routing rules matching Phase 1 instructions
- [x] Contains forbidden transitions matching Phase 1 instructions
- [x] Contains report template sections (executive summary, technical report, OpenVEX JSON)
- [x] Contains licensing posture matching Phase 1 instructions

### P2-VALIDATE: Automated Checks

- [x] `npm run validate:skills` passes (skill structure valid)
- [x] `npm run lint:md` passes
- [x] `npm run lint:frontmatter` passes

## Phase 3: VEX Agent + Subagent

### P3-SUBAGENT: CVE Analyzer

- [ ] File exists at `.github/agents/security/subagents/cve-analyzer.agent.md`
- [ ] Has valid YAML frontmatter with:
  - `name` field (e.g., `CVE Analyzer` or `cve-analyzer`)
  - `description` ending with `- Brought to you by microsoft/hve-core`
  - `tools` list including: `codebase`, `search`, `fetch`, `think`
  - `agents: []` (empty — subagents do not invoke subagents)
  - `disable-model-invocation: true`
  - `user-invocable: false`
- [ ] Body contains:
  - Purpose section describing per-CVE deep analysis
  - Inputs section (enriched CVE profile, codebase context)
  - Analysis steps: code reachability, attack vector assessment, environmental context, evidence collection
  - Output format: structured finding with status, justification, evidence, confidence
  - Forbidden transitions enforced (references `vex-generation.instructions.md`)

### P3-AGENT: VEX Generator

- [ ] File exists at `.github/agents/security/vex-generator.agent.md`
- [ ] Has valid YAML frontmatter with:
  - `name` field (e.g., `VEX Generator` or `vex-generator`)
  - `description` ending with `- Brought to you by microsoft/hve-core`
  - `tools` list including: `codebase`, `search`, `editFiles`, `fetch`, `runCommands`, `think`, `agent`
  - `agents` list including reference to CVE Analyzer subagent
  - `user-invocable: true`
- [ ] Body contains:
  - Purpose section describing the orchestration workflow
  - CAUTION disclaimer block (referencing shared disclaimer instructions)
  - Phase 1: Vulnerability Scan (Trivy CLI via `runCommands`)
  - Phase 2: CVE Enrichment (OSV.dev + NVD via `fetch`)
  - Phase 3: Exploitability Analysis (delegates to `cve-analyzer` subagent per CVE)
  - Phase 4: Report Generation (OpenVEX JSON + markdown reports via `editFiles`)
  - Mode 1 (scan) and Mode 2 (triage) differentiation
  - Input precedence: Trivy JSON > OSV-Scanner JSON > SPDX-JSON SBOM
  - References to `vex-generation.instructions.md` and `openvex-spec` skill

### P3-VALIDATE: Automated Checks

- [ ] `npm run lint:md` passes
- [ ] `npm run lint:frontmatter` passes

## Phase 4: Prompts + Collection Integration

### P4-PROMPT-SCAN: /vex-scan

- [ ] File exists at `.github/prompts/security/vex-scan.prompt.md`
- [ ] Has valid YAML frontmatter with:
  - `name: vex-scan`
  - `agent` referencing VEX Generator
  - `description` ending with `- Brought to you by microsoft/hve-core`
- [ ] Contains CAUTION disclaimer block
- [ ] Contains input variables for scope and product name
- [ ] Requirements section routes to Mode 1 (full pipeline)

### P4-PROMPT-TRIAGE: /vex-triage

- [ ] File exists at `.github/prompts/security/vex-triage.prompt.md`
- [ ] Has valid YAML frontmatter with:
  - `name: vex-triage`
  - `agent` referencing VEX Generator
  - `description` ending with `- Brought to you by microsoft/hve-core`
- [ ] Contains CAUTION disclaimer block
- [ ] Contains input variables for report/SBOM path
- [ ] Requirements section routes to Mode 2 (triage from existing report)

### P4-COLLECTION: Security Collection Updates

- [ ] `collections/security.collection.yml` contains entries for all new artifacts:
  - `.github/agents/security/vex-generator.agent.md` (kind: agent, maturity: experimental)
  - `.github/agents/security/subagents/cve-analyzer.agent.md` (kind: agent, maturity: experimental)
  - `.github/skills/security/openvex-spec` (kind: skill, maturity: experimental)
  - `.github/prompts/security/vex-scan.prompt.md` (kind: prompt, maturity: experimental)
  - `.github/prompts/security/vex-triage.prompt.md` (kind: prompt, maturity: experimental)
  - `.github/instructions/security/vex-generation.instructions.md` (kind: instruction, maturity: experimental)
  - `.github/instructions/security/vex-standards.instructions.md` (kind: instruction, maturity: experimental)
- [ ] `collections/security.collection.md` documents VEX capabilities
- [ ] `npm run plugin:generate` completes without error
- [ ] `npm run plugin:validate` passes (0 errors)

### P4-VALIDATE: Automated Checks

- [ ] `npm run lint:md` passes
- [ ] `npm run lint:frontmatter` passes
- [ ] `npm run lint:collections-metadata` passes

## Phase 5: VEX Detection Workflow

### P5-WORKFLOW: vex-detect.yml

- [ ] File exists at `.github/workflows/vex-detect.yml`
- [ ] Triggers include:
  - `workflow_run` on `release-stable.yml` with `types: [completed]`
  - `schedule` with weekly cron (after Dependabot Monday cadence)
  - `workflow_dispatch` for manual runs
- [ ] Permissions follow least-privilege (minimal required)
- [ ] All action references are SHA-pinned with version comments
- [ ] Workflow steps:
  - Checkout repository
  - Install scanner tool (OSV-Scanner or Grype)
  - Download or reference latest SBOM
  - Run vulnerability scan against SBOM
  - Diff findings against `security/vex/hve-core.openvex.json`
  - File a structured GitHub issue when new CVEs or status drift detected
- [ ] Issue template includes: CVE ID, package, current VEX status (if any), scan source, severity
- [ ] Workflow has `continue-on-error` or failure handling so scan failures don't block releases

### P5-ENV: Environment Updates

- [ ] `copilot-setup-steps.yml` installs OSV-Scanner (or scanner tool is available on ubuntu-latest)
- [ ] If added to devcontainer, `.devcontainer/scripts/on-create.sh` is also updated

### P5-VALIDATE: Automated Checks

- [ ] `npm run lint:yaml` passes
- [ ] `actionlint` passes on `vex-detect.yml` (if actionlint is available)
- [ ] All action SHAs are pinned (`npm run lint:dependency-pinning` passes)

## Phase 6: AI-Assisted VEX Drafting Workflow

### P6-WORKFLOW: vex-draft.md

- [ ] File exists at `.github/workflows/vex-draft.md`
- [ ] Has valid gh-aw frontmatter with:
  - `description` field
  - `on` trigger (dispatched from `vex-detect.yml` or manual)
  - `engine: copilot`
  - `imports` referencing `../agents/security/vex-generator.agent.md`
  - `safe-outputs` with `create-pull-request` and `max: 1`
  - `permissions` with minimal required scopes
- [ ] PR template references `.github/PULL_REQUEST_TEMPLATE/vex-triage.md`
- [ ] Confidence routing rules are enforced (references instructions file)

### P6-LOCK: Compiled Workflow

- [ ] File exists at `.github/workflows/vex-draft.lock.yml`
- [ ] Contains `gh-aw-metadata` comment header
- [ ] Generated by `gh aw compile` (not hand-edited)

### P6-VALIDATE: Automated Checks

- [ ] `npm run lint:yaml` passes
- [ ] `npm run lint:md` passes on `vex-draft.md`

## Phase 7: Documentation

### P7-VEX-VERIFY: Consumer Documentation

- [ ] File exists at `docs/security/vex-verification.md`
- [ ] Has valid YAML frontmatter with `title`, `description`, `sidebar_position`, `author`, `ms.date`, `ms.topic`, `keywords`, `estimated_reading_time`
- [ ] Contains sections:
  - What VEX is and how it complements the SBOM
  - How to download the VEX document from a release
  - How to verify the VEX attestation (`gh attestation verify` with `--predicate-type`)
  - How to interpret status values (`not_affected`, `affected`, `fixed`, `under_investigation`)
  - How to consume VEX alongside SBOM in tooling (Trivy `--vex` flag, Grype)

### P7-SECURITY-MODEL: Control Table Update

- [ ] `docs/security/security-model.md` contains a VEX control entry in the Security Controls table
- [ ] Control entry includes: control name, description, automated status, validation method

### P7-SECURITY-INDEX: README Update

- [ ] `docs/security/README.md` contains a link to `vex-verification.md`

### P7-SECURITY-MD: Release Artifacts Table

- [ ] `SECURITY.md` Release Artifact Formats table includes `.openvex.json` row with format and description

### P7-AGENT-DOCS: Agent Documentation

- [ ] File exists at `docs/agents/security/vex-generator.md`
- [ ] Contains: purpose, prerequisites (Trivy v0.63.0+), usage examples (`/vex-scan`, `/vex-triage`), output format, confidence routing explanation

### P7-VALIDATE: Automated Checks

- [ ] `npm run lint:md` passes
- [ ] `npm run lint:frontmatter` passes
- [ ] `npm run lint:md-links` passes (no broken links)
- [ ] `npm run spell-check` passes

## Cross-Phase Validation

### CROSS-CONSISTENCY: Content Consistency

- [ ] Confidence-routing 5-band table is identical in: `vex-standards.instructions.md`, `vex-generation.instructions.md`, `vex-generator.agent.md` (by reference)
- [ ] Forbidden transitions list is identical across all files that reference it
- [ ] Licensing posture (OSV CC0 preferred) is consistent across all files
- [ ] Author-of-record contract is consistent across all files
- [ ] Evidence requirements match between instructions and agent files
- [ ] CAUTION disclaimer blocks reference `disclaimer-language.instructions.md`

### CROSS-COLLECTION: Collection Integrity

- [ ] Every new `.github/` artifact is listed in `collections/security.collection.yml`
- [ ] No artifact listed in collection YAML is missing from the filesystem
- [ ] `npm run plugin:generate` produces no unexpected diffs outside `plugins/`
- [ ] `npm run plugin:validate` reports 0 errors

### CROSS-RELEASE: Release Pipeline

- [ ] VEX attestation step in `release-stable.yml` uses the same `actions/attest` SHA as existing SBOM attestation
- [ ] VEX upload uses the same `gh release upload --clobber` pattern as existing artifacts
- [ ] Release notes mention VEX verification alongside SBOM verification

### CROSS-LINT: Full Lint Suite

- [ ] `npm run lint:all` passes
- [ ] `npm run validate:copyright` passes (if copyright headers are required for new file types)
