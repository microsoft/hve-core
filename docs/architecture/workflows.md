---
title: Build Workflows
description: GitHub Actions CI/CD pipeline architecture for validation, security, and release automation
sidebar_position: 3
author: WilliamBerryiii
ms.date: 2026-08-04
ms.topic: overview
---

HVE Core uses GitHub Actions for continuous integration, quality validation, security scanning, and release automation. The workflow architecture emphasizes reusable components and parallel execution for fast feedback.

## Pipeline Overview

```mermaid
flowchart TD
    subgraph PR["Pull Request"]
        direction TB
        PR1[PR Opened/Updated] --> PV[pr-validation.yml]
        PV --> LINT[Linting Jobs]
        PV --> SEC[Security Jobs]
        PV --> TEST[Test Jobs]
    end

    subgraph MAIN["Main Branch"]
        direction TB
        MERGE[Merge to Main] --> MN[release-stable.yml]
        MN --> VAL[Validation]
        VAL --> PROMO[Review main to release/stable Promotion]
        PROMO --> STABLE[release-stable-publish.yml]
        STABLE --> REL[release-please Stable PR]
        REL --> REVIEW[Review Stable Release PR]
        REVIEW --> EVIDENCE[Artifacts and Immutable Plugin Snapshot]
        EVIDENCE --> PUBLISH[Publish Stable Release]
        PUBLISH --> SYNC[Review release/stable to main Metadata Sync]
    end

    subgraph PRE["PreRelease"]
        direction TB
        SHA[Explicit main SHA] --> PRE_RELEASE[release-prerelease.yml]
    end

    subgraph SCHED["Scheduled"]
        direction TB
        CRON[Weekly Sunday 2AM] --> WEEKLY[weekly-security-maintenance.yml]
        WEEKLY --> SECCHECK[Security Checks]
    end

    subgraph MANUAL["Manual"]
        direction TB
        DISPATCH[Manual Trigger] --> PUB[release-marketplace-stable.yml]
        PUB --> VSCE[Publish to Marketplace]
    end
```

## Workflow Inventory

| Workflow                             | Trigger                   | Purpose                                                                |
|--------------------------------------|---------------------------|------------------------------------------------------------------------|
| `pr-validation.yml`                  | Pull request, manual      | Pre-merge quality gate with parallel validation                        |
| `release-stable.yml`                 | Push to main, manual      | Validate `main` and open the reviewed Stable promotion PR              |
| `release-stable-publish.yml`         | PR merged to Stable       | Run release-please, build release evidence, publish, and sync metadata |
| `weekly-security-maintenance.yml`    | Sunday 2 AM UTC, manual   | Scheduled security posture review                                      |
| `weekly-validation.yml`              | Schedule, manual          | Weekly full validation sweep                                           |
| `security-scan.yml`                  | Push to main/develop      | CodeQL security validation                                             |
| `release-marketplace-stable.yml`     | Manual                    | VS Code extension marketplace publishing                               |
| `release-marketplace-prerelease.yml` | Manual                    | VS Code extension pre-release publishing                               |
| `copilot-setup-steps.yml`            | Manual                    | Coding agent environment setup                                         |
| `devcontainer-change-log.yml`        | Push to main/develop      | Logs devcontainer infrastructure file changes to the step summary      |
| `devcontainer-lockfile-check.yml`    | Reusable                  | Validates devcontainer lockfile integrity and SHA-256 pinning          |
| `release-prerelease.yml`             | Manual                    | Package an explicit main SHA as an immutable PreRelease                |
| `scorecard.yml`                      | Schedule, push            | OpenSSF Scorecard security analysis                                    |
| `codeql-analysis.yml`                | Schedule                  | Weekly CodeQL security scan (also reusable)                            |
| `dependency-review.yml`              | Pull request              | Dependency vulnerability review (also reusable)                        |
| `sha-staleness-check.yml`            | Manual                    | SHA reference freshness check (also reusable)                          |
| `deploy-docs.yml`                    | Push to main, manual      | Docusaurus documentation site deployment                               |
| `create-stale-docs-issues.yml`       | Schedule                  | Automated stale docs issue creation from ms.date freshness             |
| `msdate-freshness-check.yml`         | Schedule, manual          | ms.date freshness validation across documentation                      |
| `label-sync.yml`                     | Push to main, manual      | Repository label synchronization                                       |
| `workflow-permissions-scan.yml`      | Schedule, manual          | GitHub Actions permissions audit                                       |
| `weekly-gh-code-scanning.yml`        | Monday 3 AM UTC, manual   | Weekly GitHub code scanning alert retrieval and issue creation         |
| `vex-detect.yml`                     | Schedule, release, manual | Dependency vulnerability scan and VEX triage issue creation            |

GitHub Agentic Workflow markdown files (`issue-triage.md`, `issue-implement.md`, `pr-review.md`, `dependency-pr-review.md`, `doc-update-check.md`, and `vex-draft.md`) compile to `*.lock.yml` workflows and are documented in [Agentic Workflows](agentic-workflows).

### Reusable Workflows

Individual validation workflows called by orchestration workflows:

| Workflow                              | Purpose                                        | npm Script                               |
|---------------------------------------|------------------------------------------------|------------------------------------------|
| `markdown-lint.yml`                   | Markdownlint validation                        | `npm run lint:md`                        |
| `spell-check.yml`                     | cspell dictionary check                        | `npm run spell-check`                    |
| `frontmatter-validation.yml`          | AI artifact frontmatter schemas                | `npm run lint:frontmatter`               |
| `markdown-link-check.yml`             | Broken link detection                          | `npm run lint:md-links`                  |
| `link-lang-check.yml`                 | Link language validation                       | `npm run lint:links`                     |
| `yaml-lint.yml`                       | YAML syntax validation                         | `npm run lint:yaml`                      |
| `ps-script-analyzer.yml`              | PowerShell static analysis                     | `npm run lint:ps`                        |
| `table-format.yml`                    | Markdown table formatting                      | `npm run format:tables`                  |
| `pester-tests.yml`                    | PowerShell unit tests                          | `npm run test:ps`                        |
| `skill-validation.yml`                | Skill structure validation                     | `npm run validate:skills`                |
| `dependency-pinning-scan.yml`         | Dependency pinning validation                  | N/A (PowerShell direct)                  |
| `sha-staleness-check.yml`             | SHA reference freshness*                       | N/A (PowerShell direct)                  |
| `codeql-analysis.yml`                 | CodeQL security scanning*                      | N/A (GitHub native)                      |
| `dependency-review.yml`               | Dependency vulnerability review*               | N/A (GitHub native)                      |
| `gh-code-scanning.yml`                | GitHub code scanning alert retrieval           | N/A (PowerShell direct)                  |
| `create-gh-code-scanning-issues.yml`  | Create GitHub code scanning issues from alerts | N/A (bash + gh CLI direct)               |
| `extension-package.yml`               | VS Code extension packaging                    | `npm run extension:package`              |
| `copyright-headers.yml`               | Copyright header validation                    | `npm run validate:copyright`             |
| `gitleaks-scan.yml`                   | Secret detection scanning                      | N/A (gitleaks direct)                    |
| `plugin-package.yml`                  | Plugin packaging                               | N/A                                      |
| `plugin-validation.yml`               | Marketplace package metadata and closure       | `npm run lint:marketplace`               |
| `extension-marketplace-publish.yml`   | Extension marketplace publishing               | N/A                                      |
| `python-lint.yml`                     | Python linting (ruff)                          | `npm run lint:py`                        |
| `pytest-tests.yml`                    | Python unit tests                              | `npm run test:py`                        |
| `pip-audit.yml`                       | Python dependency auditing                     | N/A (pip-audit direct)                   |
| `fuzz-tests.yml`                      | Python fuzz testing                            | N/A (pytest direct)                      |
| `docusaurus-tests.yml`                | Docusaurus test suite                          | N/A (npm test)                           |
| `model-validation.yml`                | Model reference validation                     | `npm run lint:models`                    |
| `ai-artifact-validation.yml`          | AI artifact structure validation               | `npm run lint:ai-artifacts`              |
| `devcontainer-lockfile-check.yml`     | Devcontainer lockfile integrity                | `npm run validate:devcontainer-lockfile` |
| `action-version-consistency-scan.yml` | Action version consistency                     | `npm run lint:version-consistency`       |

Workflows marked with `*` are dual-purpose: they accept `workflow_call` for reuse by orchestration workflows and also run independently via their own triggers.

### Composite Actions

Composite actions package reusable step sequences that workflows invoke directly. Unlike reusable workflows (called via `uses:` at the job level with `workflow_call`), composite actions are referenced as steps within a job.

| Action             | Purpose                                     | Reference                                  |
|--------------------|---------------------------------------------|--------------------------------------------|
| `setup-ps-modules` | Cached PowerShell module install with retry | `uses: ./.github/actions/setup-ps-modules` |

The `setup-ps-modules` action caches modules keyed on `scripts/security/ps-module-versions.json` and retries installation with exponential backoff on PSGallery failures. Workflows that need PowerShell modules must use `uses: ./.github/actions/setup-ps-modules` instead of inline `Install-Module` steps, consistent with the convention recorded in `.github/copilot-instructions.md`.

## PR Validation Pipeline

The `pr-validation.yml` workflow serves as the primary quality gate for all pull requests. It runs parallel linting, security, and testing jobs.

```mermaid
flowchart LR
    subgraph "Linting"
        ML[markdown-lint]
        SC[spell-check]
        TF[table-format]
        YL[yaml-lint]
        FV[frontmatter-validation]
        LLC[link-lang-check]
        MLC[markdown-link-check]
        CH[copyright-headers]
    end

    subgraph "Analysis"
        PSA[psscriptanalyzer]
        PT[pester-tests]
        SV[skill-validation]
        PV[plugin-validation]
    end

    subgraph "Security"
        DPC[dependency-pinning-check]
        DCL[devcontainer-lockfile-check]
        NA[npm-audit]
        CQL[codeql]
        GLS[gitleaks-scan]
    end
```

### Jobs

| Job                         | Reusable Workflow                 | Validates                       |
|-----------------------------|-----------------------------------|---------------------------------|
| spell-check                 | `spell-check.yml`                 | Spelling across all files       |
| markdown-lint               | `markdown-lint.yml`               | Markdown formatting rules       |
| table-format                | `table-format.yml`                | Markdown table structure        |
| psscriptanalyzer            | `ps-script-analyzer.yml`          | PowerShell code quality         |
| yaml-lint                   | `yaml-lint.yml`                   | YAML syntax                     |
| pester-tests                | `pester-tests.yml`                | PowerShell unit tests           |
| frontmatter-validation      | `frontmatter-validation.yml`      | AI artifact metadata            |
| skill-validation            | `skill-validation.yml`            | Skill directory structure       |
| link-lang-check             | `link-lang-check.yml`             | Link accessibility              |
| markdown-link-check         | `markdown-link-check.yml`         | Broken links                    |
| dependency-pinning-check    | `dependency-pinning-scan.yml`     | Dependency pinning              |
| devcontainer-lockfile-check | `devcontainer-lockfile-check.yml` | Devcontainer lockfile integrity |
| npm-audit                   | Inline                            | npm dependency vulnerabilities  |
| codeql                      | `codeql-analysis.yml`             | Code security patterns          |
| copyright-headers           | `copyright-headers.yml`           | Copyright header compliance     |
| plugin-validation           | `plugin-validation.yml`           | Plugin and package metadata     |
| gitleaks-scan               | `gitleaks-scan.yml`               | Secret detection                |

All jobs run in parallel with no dependencies, enabling fast feedback (typically under 3 minutes).

## Main Branch Pipeline

`release-stable.yml` opens the reviewed `main` to `release/stable` promotion after validating `main` and confirming that the prior Stable metadata has returned to `main`. It does not run release-please, package artifacts, create a tag, or publish a release.

```mermaid
flowchart LR
    V1[spell-check] --> PREP[prepare-promotion]
    V2[markdown-lint] --> PREP
    V3[table-format] --> PREP
    V4[dependency-pinning-scan] --> PREP
    V5[action-version-consistency-scan] --> PREP
    V6[gitleaks-scan] --> PREP
    V7[pester-tests] --> PREP
    V8[docusaurus-tests] --> PREP
    V9[discover-python-projects] --> PREP
    V9 --> V10[python-lint]
    V9 --> V11[pytest]
    V10 --> PREP
    V11 --> PREP
    PREP --> PR[open-promotion-pr]
```

### Main Branch Jobs

| Job                             | Purpose                                          | Dependencies             |
|---------------------------------|--------------------------------------------------|--------------------------|
| spell-check                     | Post-merge spelling validation                   | None                     |
| markdown-lint                   | Post-merge Markdown validation                   | None                     |
| table-format                    | Post-merge table validation                      | None                     |
| dependency-pinning-scan         | Dependency pinning security check                | None                     |
| action-version-consistency-scan | Action version consistency check                 | None                     |
| gitleaks-scan                   | Secret detection scanning                        | None                     |
| pester-tests                    | PowerShell unit tests                            | None                     |
| docusaurus-tests                | Documentation site build and tests               | None                     |
| discover-python-projects        | Enumerate Python projects                        | None                     |
| python-lint                     | Python lint (ruff)                               | discover-python-projects |
| pytest                          | Python unit tests                                | discover-python-projects |
| prepare-promotion               | Verify source state and determine promotion need | All validation jobs      |
| open-promotion-pr               | Open or update the reviewed `main` promotion     | prepare-promotion        |

After the promotion merges, `release-stable-publish.yml` runs release-please on `release/stable`. Release-please owns the managed Stable release PR and draft Stable release. The workflow synchronizes version fields and the immutable plugin locator on the managed PR.

After review and merge, it validates the released commit, packages and attests release assets, publishes the immutable `plugins-v<version>` snapshot, finalizes the draft, and opens a non-auto-merged `release/stable` to `main` metadata synchronization PR.

## Security Workflows

### Weekly Security Maintenance

The `weekly-security-maintenance.yml` workflow runs every Sunday at 2AM UTC, providing scheduled security posture review.

| Job              | Purpose                              |
|------------------|--------------------------------------|
| validate-pinning | Verify dependency pinning compliance |
| check-staleness  | Detect outdated SHA references       |
| codeql-analysis  | Full CodeQL security scan            |
| summary          | Aggregate security status report     |

### Security Validation Tools

| Tool               | Script                            | Checks                                                                        |
|--------------------|-----------------------------------|-------------------------------------------------------------------------------|
| Dependency Pinning | `Test-DependencyPinning.ps1`      | Actions use SHA refs; npm uses exact versions                                 |
| SHA Staleness      | `Test-SHAStaleness.ps1`           | SHAs reference recent commits                                                 |
| audit-ci           | `audit-ci --config audit-ci.json` | Known vulnerabilities in dependencies, using the allowlist in `audit-ci.json` |
| CodeQL             | GitHub native                     | Code patterns indicating security issues                                      |
| Gitleaks           | `gitleaks`                        | Secret detection in repository history                                        |
| Dependency Review  | GitHub native                     | Dependency vulnerability analysis                                             |

## Extension Publishing

The `release-marketplace-stable.yml` and `release-marketplace-prerelease.yml` workflows discover active package IDs from the catalog and process one VSIX per matrix entry. Stable uses the reviewed `release/stable` release source, while PreRelease uses an explicit `main` source commit. The channels differ in source ownership, cadence, and version policy, not in active package membership or component maturity.

```mermaid
flowchart TD
    subgraph Stable["release-marketplace-stable.yml"]
        NV[normalize-version] --> PKG1["package (matrix)"]
        PKG1 --> PUB1["publish (matrix)"]
    end
    subgraph PreRelease["release-marketplace-prerelease.yml"]
        VV[validate-version] --> PKG2["package (matrix)"]
        PKG2 --> PUB2["publish (matrix)"]
    end
```

### Publishing Jobs

| Job               | Purpose                                                               | Workflow                             |
|-------------------|-----------------------------------------------------------------------|--------------------------------------|
| normalize-version | Ensure Stable version consistency                                     | `release-marketplace-stable.yml`     |
| validate-version  | Enforce the PreRelease odd-minor version convention                   | `release-marketplace-prerelease.yml` |
| discover/package  | Resolve the catalog matrix and build one source-explicit VSIX per row | Both                                 |
| publish           | Upload each selected VSIX through OIDC and `vsce`                     | Both                                 |

### Marketplace Build

`Get-MarketplacePackageMatrix.ps1` emits a sorted, nonempty matrix from active catalog entries. Stable and PreRelease must resolve the same package-name set and the same active component and maturity projection for every package. The matrix, not a literal package count or a package-specific workflow branch, controls packaging and publication.

`hve-core` retains the unsuffixed HVE Core extension identity. Every other active catalog entry receives a deterministic package-specific extension identity and plugin root.

A single immutable `plugins-v<version>` snapshot contains every active package root and the projected catalog that references them. Each package remains self-contained; the release model does not use package dependencies or aggregate metadata.

Lifecycle inclusion rules:

| Lifecycle Level | Build Inclusion                                 |
|-----------------|-------------------------------------------------|
| Deprecated      | Excluded from both channels                     |
| Removed         | Excluded from both channels                     |
| Experimental    | Included in both Stable and PreRelease channels |
| Preview         | Included in both Stable and PreRelease channels |
| Stable          | Included in both Stable and PreRelease channels |

Lifecycle labels are disclosure and governance metadata. Channel selection does not filter active components.

### Version Channels

| Channel     | Version Pattern    | Marketplace      |
|-------------|--------------------|------------------|
| Stable      | Even minor (1.2.0) | Main listing     |
| Pre-release | Odd minor (1.3.0)  | Pre-release flag |

## npm Script Mapping

Workflows invoke validation through npm scripts defined in `package.json`:

| npm Script                      | Command                                                                                               | Used By                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------------|---------------------------------------------|
| `lint:md`                       | `markdownlint-cli2`                                                                                   | markdown-lint.yml                           |
| `lint:md:fix`                   | `markdownlint-cli2 --fix`                                                                             | Local                                       |
| `spell-check`                   | `cspell`                                                                                              | spell-check.yml                             |
| `spell-check:fix`               | `cspell --show-suggestions`                                                                           | Local                                       |
| `lint:frontmatter`              | `Validate-MarkdownFrontmatter.ps1`                                                                    | frontmatter-validation.yml                  |
| `lint:md-links`                 | `Markdown-Link-Check.ps1`                                                                             | markdown-link-check.yml                     |
| `lint:links`                    | `Invoke-LinkLanguageCheck.ps1`                                                                        | link-lang-check.yml                         |
| `lint:yaml`                     | `Invoke-YamlLint.ps1`                                                                                 | yaml-lint.yml                               |
| `lint:ps`                       | `Invoke-PSScriptAnalyzer.ps1`                                                                         | ps-script-analyzer.yml                      |
| `lint:marketplace`              | `Validate-Marketplace.ps1`                                                                            | plugin-validation.yml                       |
| `lint:version-consistency`      | `Test-ActionVersionConsistency.ps1`                                                                   | Local                                       |
| `validate:local`                | Local-safe repository validation aggregate                                                            | Local-safe default                          |
| `validate:docs`                 | Docusaurus lint, label registry, typecheck, and component tests                                       | Local-safe docs default                     |
| `ci:docs:test:e2e`              | Delegates to the Docusaurus Playwright E2E suite                                                      | CI-owned browser lane                       |
| `ci:docs:setup:e2e`             | Provisions Chrome for the Docusaurus browser lane                                                     | CI-owned browser setup                      |
| `format:tables`                 | `markdown-table-formatter`                                                                            | table-format.yml                            |
| `test:ps`                       | `Invoke-PesterTests.ps1`                                                                              | pester-tests.yml                            |
| `validate:skills`               | `Validate-SkillStructure.ps1`                                                                         | skill-validation.yml                        |
| `validate:copyright`            | `Test-CopyrightHeaders.ps1`                                                                           | copyright-headers.yml                       |
| `extension:prepare`             | `pwsh ./scripts/extension/Prepare-Extension.ps1 && npm run extension:postprocess`                     | extension-package.yml                       |
| `extension:prepare:prerelease`  | `pwsh ./scripts/extension/Prepare-Extension.ps1 -Channel PreRelease && npm run extension:postprocess` | extension-package.yml                       |
| `extension:postprocess`         | `markdownlint-cli2 + markdown-table-formatter (extension/**/*.md)`                                    | extension-package.yml                       |
| `extension:package`             | `Package-Extension.ps1`                                                                               | extension-package.yml                       |
| `package:extension`             | Alias for `extension:package`                                                                         | extension-package.yml                       |
| `extension:package:prerelease`  | `Package-Extension.ps1 -PreRelease`                                                                   | extension-package.yml                       |
| `plugin:generate`               | `Generate-Plugins.ps1` + post-process                                                                 | plugin-package.yml                          |
| `plugin:validate`               | Marketplace package metadata and closure validation                                                   | plugin-validation.yml                       |
| `lint:py`                       | `ruff check`                                                                                          | python-lint.yml                             |
| `lint:models`                   | `Validate-ModelReferences.ps1`                                                                        | model-validation.yml                        |
| `lint:ai-artifacts`             | `Validate-PlannerArtifacts.ps1 -FailOnMissing`                                                        | ai-artifact-validation.yml                  |
| `lint:permissions`              | `Test-WorkflowPermissions.ps1`                                                                        | workflow-permissions-scan.yml               |
| `lint:ps-module-pins`           | `Test-PSModulePins.ps1`                                                                               | Local                                       |
| `lint:dependency-pinning`       | `Test-DependencyPinning.ps1`                                                                          | dependency-pinning-scan.yml                 |
| `audit:npm`                     | `audit-ci --config audit-ci.json`                                                                     | pr-validation.yml                           |
| `test:py`                       | `uv run pytest`                                                                                       | pytest-tests.yml                            |
| `ci:eval:lint:vally`            | `Build-AgentBehaviorSpec.ps1 -WhatIf && vally lint --eval-spec evals/`                                | CI-owned static lane                        |
| `ci:eval:lint:schema`           | `Test-EvalSpec.ps1`                                                                                   | CI-owned static lane                        |
| `ci:eval:lint:text`             | `Test-EvalSpecText.ps1`                                                                               | CI-owned static lane                        |
| `ci:eval:lint:safety`           | `Test-VallyTestSafety.ps1`                                                                            | CI-owned static lane                        |
| `ci:eval:lint:skills`           | `vally lint .github/skills/`                                                                          | CI-owned static lane                        |
| `ci:eval:run`                   | Runs all eval suites                                                                                  | CI-owned model-backed lane                  |
| `ci:eval:run:skills`            | `vally eval --suite skill-quality`                                                                    | CI-owned model-backed lane                  |
| `ci:eval:run:agents`            | `vally eval --suite agent-behavior`                                                                   | CI-owned model-backed lane                  |
| `ci:eval:run:scripts`           | `vally eval --suite script-validation`                                                                | CI-owned model-backed lane                  |
| `ci:eval:equivalence`           | `Invoke-BaselineEquivalence.ps1`                                                                      | CI-owned model-backed comparison lane       |
| `ci:eval:presence`              | `Test-StimulusPresence.ps1` (changed-artifact eval-spec coverage gate)                                | CI-owned manifest lane                      |
| `ci:eval:execute`               | `Invoke-VallyEvals.ps1` (run evals for changed artifacts)                                             | CI-owned model-backed lane                  |
| `ci:eval:moderate`              | `Invoke-ContentModeration.ps1`                                                                        | CI-owned moderation lane                    |
| `ci:eval:moderate:corpus`       | `Invoke-CorpusModeration.ps1`                                                                         | CI-owned moderation lane                    |
| `ci:eval:moderate:artifacts`    | `Invoke-ArtifactModeration.ps1`                                                                       | CI-owned moderation lane                    |
| `ci:eval:moderate:test`         | Runs `Invoke-ContentModeration.Tests.ps1`                                                             | CI-owned test lane                          |
| `ci:eval:dashboard`             | `New-EquivalenceDashboard.ps1`                                                                        | CI-owned noninteractive report lane         |
| `ci:eval:run:equivalence`       | Runs baseline and customized equivalence specs                                                        | CI-owned model-backed lane                  |
| `ci:eval:behavior-prompts`      | `vally eval --eval-spec evals/behavior-conformance/prompts.eval.yaml`                                 | CI-owned model-backed lane                  |
| `ci:eval:behavior-instructions` | `vally eval --eval-spec evals/behavior-conformance/instructions.eval.yaml`                            | CI-owned model-backed lane                  |
| `ci:eval:behavior-skills`       | `vally eval --eval-spec evals/behavior-conformance/skill-behavior.eval.yaml`                          | CI-owned model-backed lane                  |
| `ci:eval:agent`                 | `Invoke-AgentMatrix.ps1` (agent behavior matrix)                                                      | CI-owned model-backed lane                  |
| `ci:eval:agent:matrix`          | `Invoke-AgentMatrix.ps1 -All -Tier nightly`                                                           | CI-owned model-backed lane                  |
| `ci:eval:agent:matrix:dryrun`   | `Invoke-AgentMatrix.ps1 -All -Tier nightly -WhatIf`                                                   | CI-owned dry-run lane                       |
| `ci:eval:agent:changed`         | `Invoke-AgentMatrix.ps1` for changed agents (PR tier)                                                 | CI-owned model-backed lane                  |
| `ci:eval:agent:dashboard`       | `New-AgentMatrixDashboard.ps1`                                                                        | CI-owned noninteractive report lane         |
| `ci:eval:agent:dashboard:open`  | `New-AgentMatrixDashboard.ps1 -Open`                                                                  | CI-owned interactive lane                   |
| `ci:eval:agent:report`          | Runs `ci:eval:agent:matrix` then `ci:eval:agent:dashboard`                                            | CI-owned noninteractive report lane         |
| `ci:eval:agent:report:dryrun`   | Runs `ci:eval:agent:matrix:dryrun` then `ci:eval:agent:dashboard`                                     | CI-owned noninteractive dry-run report lane |

## Related Documentation

* [Testing Architecture](testing.md) - PowerShell Pester test infrastructure
* [Scripts README](https://github.com/microsoft/hve-core/blob/main/scripts/README.md) - Script organization and usage
* [Validation Commands and CI-Owned Lanes](../contributing/validation) - Local-safe defaults, CI-owned lane prerequisites, and reproduction guidance

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
