---
title: Phase Reference
description: Detailed reference for each of the SSSC Planner's six phases including inputs, outputs, artifacts, and state transitions
sidebar_position: 5
sidebar_label: Phase Reference
keywords:
  - sssc planner
  - phases
  - OpenSSF Scorecard
  - SLSA
  - supply chain assessment
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-18
ms.topic: reference
estimated_reading_time: 8
---

Each of the SSSC Planner's six phases has defined inputs, outputs, state transitions, and artifacts. This reference documents the details that govern how the agent moves through a complete supply chain security assessment.

## Phase Summary

| Phase | Name                    | Key output              | State fields updated     |
|-------|-------------------------|-------------------------|--------------------------|
| 1     | Project Scoping         | Scope definition        | `entryMode`, `context.*` |
| 2     | Supply Chain Assessment | Capability inventory    | `assessmentComplete`     |
| 3     | Standards Mapping       | Standards coverage map  | `standardsMapped`        |
| 4     | Gap Analysis            | Prioritized gap table   | `gapAnalysisComplete`    |
| 5     | Backlog Generation      | Work items              | `backlogGenerated`       |
| 6     | Review & Handoff        | Projections and handoff | `handoffGenerated`       |

## Phase 1: Project Scoping

### Purpose

Capture the target repository's technology stack, package managers, CI platform, release strategy, and compliance targets. Determine entry mode and establish the assessment context.

### Inputs

* User responses to scoping questions (capture mode).
* PRD artifacts from `.copilot-tracking/` (From-PRD mode).
* BRD artifacts from `.copilot-tracking/` (From-BRD mode).
* Security Planner state file (From-Security-Plan mode).

### Process

The agent asks 3-5 questions per turn covering:

* Target repository purpose and technology stack.
* Package managers (npm, pip, NuGet, etc.).
* CI/CD platform (GitHub Actions, Azure Pipelines, etc.).
* Release strategy (tags, branches, release-please, etc.).
* Compliance targets (OpenSSF Scorecard tier, SLSA level, Badge tier).
* Existing supply chain security tooling already in place.
* Cross-agent references (Security Planner link, RAI Planner link).

### Outputs

* Completed scope definition in the plan file.
* Context fields populated in state.

### State Transitions

| Field                     | Before | After                                                      |
|---------------------------|--------|------------------------------------------------------------|
| `currentPhase`            | 1      | 2 (on user confirmation)                                   |
| `entryMode`               | unset  | `capture`, `from-prd`, `from-brd`, or `from-security-plan` |
| `scopingComplete`         | false  | true                                                       |
| `context.techStack`       | `[]`   | Populated                                                  |
| `context.packageManagers` | `[]`   | Populated                                                  |
| `context.ciPlatform`      | unset  | Populated                                                  |

## Phase 2: Supply Chain Assessment

### Purpose

Inventory 27 supply chain security capabilities across hve-core and physical-ai-toolchain, classifying each by source and coverage status.

### The 27 Capabilities

Capabilities are classified into three source categories:

#### hve-core Unique (6)

| # | Capability                      | Description                                   |
|---|---------------------------------|-----------------------------------------------|
| 1 | pip-audit integration           | Python dependency vulnerability scanning      |
| 2 | Action version consistency      | Cross-workflow action version validation      |
| 3 | Automated SHA pinning           | Script-based SHA pinning for GitHub Actions   |
| 4 | Weekly security summary         | Scheduled security posture reporting          |
| 5 | Get-VerifiedDownload.ps1        | Cryptographic hash verification for downloads |
| 6 | Security workflow orchestration | Multi-workflow security pipeline coordination |

#### physical-ai-toolchain Unique (10)

| #  | Capability                 | Description                                         |
|----|----------------------------|-----------------------------------------------------|
| 7  | SBOM generation            | anchore/sbom-action with SPDX-JSON output           |
| 8  | Sigstore signing           | gitsign keyless commit and artifact signing         |
| 9  | DAST / ZAP integration     | Dynamic application security testing                |
| 10 | Dual attestation           | Build provenance + SBOM attestation                 |
| 11 | Stale docs → issue         | Automated issue creation for outdated documentation |
| 12 | Best Practices Badge       | OpenSSF Best Practices Badge enrollment             |
| 13 | Dependabot security prefix | Security-prefixed Dependabot branch naming          |
| 14 | Threat model               | Structured threat model documentation               |
| 15 | release-please             | Automated release management                        |
| 16 | Vulnerability SLA          | Time-bound vulnerability remediation policy         |

#### Shared (11)

| #  | Capability           | Description                                  |
|----|----------------------|----------------------------------------------|
| 17 | Dependency pinning   | SHA-pinned GitHub Actions dependencies       |
| 18 | SHA staleness checks | Validation that pinned SHAs are current      |
| 19 | gitleaks             | Secret scanning in CI/CD                     |
| 20 | CodeQL               | Static analysis for security vulnerabilities |
| 21 | Dependency review    | PR-time dependency change analysis           |
| 22 | OpenSSF Scorecard    | Automated Scorecard checks in CI             |
| 23 | Workflow permissions | Minimal token permissions enforcement        |
| 24 | Copyright headers    | Automated copyright header validation        |
| 25 | Dependabot           | Automated dependency update PRs              |
| 26 | SECURITY.md          | Security policy documentation                |
| 27 | CODEOWNERS           | Code ownership and review enforcement        |

### Assessment Protocol

The agent follows a four-step protocol for each capability:

| Step     | Action                                                      |
|----------|-------------------------------------------------------------|
| Detect   | Scan the target repository for evidence of the capability   |
| Classify | Assign a source (hve-core, PAT, shared) and coverage status |
| Document | Record findings in the assessment artifact                  |
| Verify   | Confirm with the user before proceeding                     |

### Coverage Icons

| Icon | Meaning        |
|------|----------------|
| ✅    | Present        |
| ⚠️   | Partial        |
| ❌    | Missing        |
| ➖    | Not applicable |

### State Transitions

| Field                | Before  | After  |
|----------------------|---------|--------|
| `currentPhase`       | 2       | 3      |
| `assessmentComplete` | `false` | `true` |

## Phase 3: Standards Mapping

### Purpose

Map the capability inventory to five standard areas, assigning current score estimates and identifying coverage gaps.

### Five Standard Areas

#### OpenSSF Scorecard (20 Checks)

| #  | Check                  | Risk     | Score Range | Agent Mapping            |
|----|------------------------|----------|-------------|--------------------------|
| 1  | Binary-Artifacts       | High     | 0-10        | Convention enforcement   |
| 2  | Branch-Protection      | High     | 0-10        | Platform configuration   |
| 3  | CI-Tests               | Low      | 0-10        | Workflow adoption        |
| 4  | CII-Best-Practices     | Low      | 0-10        | Badge enrollment         |
| 5  | Code-Review            | High     | 0-10        | CODEOWNERS enforcement   |
| 6  | Contributors           | Low      | 0-10        | Organic                  |
| 7  | Dangerous-Workflow     | Critical | 0-10        | Pattern validation       |
| 8  | Dependency-Update-Tool | High     | 0-10        | Dependabot configuration |
| 9  | Fuzzing                | Medium   | 0-10        | New capability           |
| 10 | License                | Low      | 0-10        | LICENSE file presence    |
| 11 | Maintained             | High     | 0-10        | Organic                  |
| 12 | Packaging              | Medium   | 0-10        | Existing capability      |
| 13 | Pinned-Dependencies    | Medium   | 0-10        | Script adoption          |
| 14 | SAST                   | Medium   | 0-10        | CodeQL + linters         |
| 15 | SBOM                   | Medium   | 0-10        | Workflow adoption        |
| 16 | Security-Policy        | Medium   | 0-10        | SECURITY.md presence     |
| 17 | Signed-Releases        | High     | 0-10        | Sigstore adoption        |
| 18 | Token-Permissions      | High     | 0-10        | Script validation        |
| 19 | Vulnerabilities        | High     | 0-10        | Scanner integration      |
| 20 | Webhooks               | Critical | 0-10        | Platform managed         |

#### SLSA Build Track

| Level | Requirements                                    |
|-------|-------------------------------------------------|
| L0    | No guarantees (default)                         |
| L1    | Build process exists and produces provenance    |
| L2    | Hosted build platform, authenticated provenance |
| L3    | Hardened build platform, unforgeable provenance |

#### Best Practices Badge

| Tier    | Key criteria                                  |
|---------|-----------------------------------------------|
| Passing | Basic security practices in place             |
| Silver  | Advanced testing, static analysis, governance |
| Gold    | Dynamic analysis, full reproducibility        |

#### Sigstore Maturity

| Level        | Description                                            |
|--------------|--------------------------------------------------------|
| Not adopted  | No signing in place                                    |
| Basic        | Manual key-based signing                               |
| Intermediate | gitsign for commit signing                             |
| Advanced     | Keyless signing with Fulcio + Rekor + SBOM attestation |

#### SBOM Standards

| Standard     | Description                          |
|--------------|--------------------------------------|
| SPDX-JSON    | Standard SBOM format                 |
| NTIA minimum | Minimum elements for SBOM compliance |

### State Transitions

| Field             | Before  | After  |
|-------------------|---------|--------|
| `currentPhase`    | 3       | 4      |
| `standardsMapped` | `false` | `true` |

## Phase 4: Gap Analysis

### Purpose

Compare current posture against desired state, classify gaps by adoption category, and assign effort sizing.

### Gap Table Format

Gaps are sorted by Scorecard risk level (Critical > High > Medium > Low):

| Gap           | Scorecard Check | Risk    | Current State | Target State | Adoption Type | Effort     |
|---------------|-----------------|---------|---------------|--------------|---------------|------------|
| *description* | *check_name*    | *level* | *current*     | *target*     | *category*    | *S/M/L/XL* |

### Six Adoption Categories

| Category                   | Description                                       | Effort   |
|----------------------------|---------------------------------------------------|----------|
| Reusable Workflow Adoption | Reference an hve-core workflow via `uses:`        | Lowest   |
| Workflow Copy/Modify       | Copy and adapt a workflow to the target repo      | Medium   |
| Reusable Workflow + Script | Adopt both a workflow and supporting scripts      | Medium   |
| Platform Configuration     | GitHub or ADO settings via UI or API              | Variable |
| New Capability             | Build something not available in either repo      | Highest  |
| N/A / Organic              | Not actionable; improves through natural activity | None     |

### Effort Sizing

| Size | Criteria                                           | Typical Duration |
|------|----------------------------------------------------|------------------|
| S    | Single file addition or configuration change       | < 1 day          |
| M    | Multiple files or workflow customization required  | 1-3 days         |
| L    | Cross-cutting changes across CI/CD pipeline        | 3-5 days         |
| XL   | New capability build or major architectural change | 1+ weeks         |

### Prioritization

Gaps are prioritized by Scorecard risk level, with adoption type as a secondary sort (reusable workflow first, new capability last).

### State Transitions

| Field                 | Before  | After  |
|-----------------------|---------|--------|
| `currentPhase`        | 4       | 5      |
| `gapAnalysisComplete` | `false` | `true` |

## Phase 5: Backlog Generation

### Purpose

Convert gap analysis results into actionable work items with adoption steps, acceptance criteria, and priority assignments.

### Work Item Formats

| Platform | ID format         | Example           |
|----------|-------------------|-------------------|
| ADO      | `WI-SSSC-{NNN}`   | `WI-SSSC-001`     |
| GitHub   | `{{SSSC-TEMP-N}}` | `{{SSSC-TEMP-1}}` |

### Priority Derivation

| Risk Level | Priority | Execution Order |
|------------|----------|-----------------|
| Critical   | P1       | First           |
| High       | P2       | Second          |
| Medium     | P3       | Third           |
| Low        | P4       | Fourth          |

### ADO Work Item Hierarchy

| Level      | Scope                                                                   |
|------------|-------------------------------------------------------------------------|
| Epic       | Supply chain security improvement program (one per assessment)          |
| Feature    | Per adoption category (reusable workflow, platform configuration, etc.) |
| User Story | Per Scorecard check or SLSA improvement step                            |
| Task       | Individual implementation steps for a user story                        |

### Autonomy Tiers

| Tier    | Human involvement          | Typical use                              |
|---------|----------------------------|------------------------------------------|
| Full    | None required              | Low-risk configuration changes           |
| Partial | Review and approve         | Default for most supply chain work items |
| Manual  | Human plans and implements | New capability builds, policy decisions  |

### State Transitions

| Field              | Before  | After  |
|--------------------|---------|--------|
| `currentPhase`     | 5       | 6      |
| `backlogGenerated` | `false` | `true` |

## Phase 6: Review and Handoff

### Purpose

Validate the complete analysis, generate improvement projections, and produce platform-specific handoff files for backlog managers.

### Handoff Protocol

1. Read the neutral work item list from Phase 5.
2. Validate completeness: every gap from Phase 4 has a corresponding work item.
3. Generate improvement projections (Scorecard, SLSA, Badge).
4. Present the complete plan to the user for final review.
5. On confirmation, generate platform-specific handoff files.
6. Update state with handoff flags.

### Scorecard Improvement Projection

For each of the 20 checks, project the score improvement if all related work items are completed:

| #   | Check        | Risk   | Current Score | Projected Score | Work Items             |
|-----|--------------|--------|---------------|-----------------|------------------------|
| *n* | *check_name* | *risk* | *current*/10  | *projected*/10  | *WI-SSSC-\{NNN\}, ...* |

### SLSA Level Assessment

| Field           | Value                                     |
|-----------------|-------------------------------------------|
| Current level   | Build L\{N\}                              |
| Projected level | Build L\{N\}                              |
| Remaining steps | Items needed beyond the generated backlog |

### Badge Readiness

| Field               | Value                                     |
|---------------------|-------------------------------------------|
| Current readiness   | Passing, Silver, Gold, or Not enrolled    |
| Projected readiness | Passing, Silver, or Gold                  |
| Missing criteria    | Items not covered by the backlog (if any) |

### Review Checklist

The agent validates:

* All 20 Scorecard checks have been assessed.
* Standards mapping covers all five standard areas.
* Every gap has a corresponding work item.
* Work items have adoption steps and acceptance criteria.
* Cross-agent references are populated if applicable.

### ADO and GitHub Handoff Paths

| Platform | Path                                                                           |
|----------|--------------------------------------------------------------------------------|
| ADO      | `.copilot-tracking/workitems/backlog/{project-slug}-sssc/work-items.md`        |
| GitHub   | `.copilot-tracking/github-issues/discovery/{project-slug}-sssc/issues-plan.md` |

### State Transitions

| Field              | Before                        | After              |
|--------------------|-------------------------------|--------------------|
| `currentPhase`     | 6                             | 6                  |
| `handoffGenerated` | `{ado: false, github: false}` | Updated per target |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
