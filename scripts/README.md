---
title: Scripts
description: PowerShell scripts for linting, validation, and security automation
author: HVE Core Team
ms.date: 2026-08-13
ms.topic: reference
keywords:
  - powershell
  - scripts
  - automation
  - linting
  - security
estimated_reading_time: 5
---

This directory contains PowerShell scripts for automating linting, validation, and security checks in the `hve-core` repository.

## Directory Structure

```text
scripts/
├── lib/             Shared artifact and CI helpers
├── agents/          Agent activation harness and baseline snapshots
├── evals/           Eval runner and moderation automation
├── release/         Release version normalization and assurance helpers
├── devcontainer/    Devcontainer lockfile and change log validation
├── docs/            Asset documentation generator, helper modules, and templates
├── extension/       VS Code extension packaging utilities
├── lib/             Shared utility modules
├── linting/         PowerShell linting and validation scripts
├── plugins/         Copilot CLI plugin manifest synchronization
├── security/        Security scanning and dependency pinning scripts
└── tests/           Pester test organization
```

## Extension

VS Code extension packaging utilities.

| Script                  | Purpose                                  |
|-------------------------|------------------------------------------|
| `Package-Extension.ps1` | Package the VS Code extension            |
| `Prepare-Extension.ps1` | Prepare extension contents for packaging |

## Library

Shared utility modules used across scripts.

| Script                     | Purpose                              |
|----------------------------|--------------------------------------|
| `Get-VerifiedDownload.ps1` | Download files with SHA verification |

## Agents

The `agents/` directory contains the activation harness for Copilot agent cold-start validation.

| Script                                                   | Purpose                                                                              |
|----------------------------------------------------------|--------------------------------------------------------------------------------------|
| `activation-harness/Get-AgentActivationFingerprint.psm1` | Compute deterministic activation fingerprints for custom agents across scenarios     |
| `activation-harness/Update-AgentActivationBaseline.ps1`  | Regenerate baseline.json for the activation harness and support dry-run drift checks |
| `activation-harness/baseline.json`                       | Snapshot of the current activation fingerprint baseline for the ADR creation agent   |

See [activation-harness/README.md](agents/activation-harness/README.md) for the full harness contract and baseline workflow.

## Release

The `release/` directory contains version normalization, promotion resolution, release-asset reconciliation, and provenance verification helpers used by release workflows.

| Script                                | Purpose                                                    |
|---------------------------------------|------------------------------------------------------------|
| `Set-RepositoryVersion.ps1`           | Normalize the five repository-owned version targets        |
| `Resolve-ReleasePromotionVersion.ps1` | Calculate the next branch-owned channel version            |
| `Assert-ReleaseAssetSet.ps1`          | Reconcile one VSIX, sidecars, and channel singleton assets |
| `Invoke-ProvenanceVerification.ps1`   | Verify release provenance through the GitHub CLI           |

## Linting Scripts

The `linting/` directory contains scripts for validating code quality and documentation:

| Script                             | Purpose                                                   |
|------------------------------------|-----------------------------------------------------------|
| `Invoke-PSScriptAnalyzer.ps1`      | Static analysis for PowerShell files                      |
| `Validate-MarkdownFrontmatter.ps1` | Validate YAML frontmatter in markdown files               |
| `Validate-SkillStructure.ps1`      | Validate skill directory structure and frontmatter        |
| `Invoke-LinkLanguageCheck.ps1`     | Detect en-us language paths in URLs                       |
| `Link-Lang-Check.ps1`              | Link language checking entry point                        |
| `Markdown-Link-Check.ps1`          | Validate markdown links                                   |
| `Invoke-YamlLint.ps1`              | YAML file validation                                      |
| `Test-CopyrightHeaders.ps1`        | Validate copyright headers in source files                |
| `Invoke-MsDateFreshnessCheck.ps1`  | Check ms.date frontmatter freshness                       |
| `Invoke-PythonLint.ps1`            | Python linting via ruff                                   |
| `Invoke-PythonTests.ps1`           | Python tests via pytest                                   |
| `Validate-AdrConsistency.ps1`      | Validate ADR structure and Govern-phase consistency rules |
| `Validate-AssetDocs.ps1`           | Validate asset documentation coverage and sync            |
| `Validate-HookManifests.ps1`       | Validate package-scoped hook manifests                    |
| `Validate-PlannerArtifacts.ps1`    | Validate AI artifact footers and planner disclaimers      |

See [linting/README.md](linting/README.md) for detailed documentation.

## Evals

The `evals/` directory contains PowerShell entry points for agent-behavior, baseline-equivalence, moderation, and other eval automation.

| Script                                    | Purpose                                                                             |
|-------------------------------------------|-------------------------------------------------------------------------------------|
| `Build-AgentBehaviorSpec.ps1`             | Regenerate the agent-behavior eval spec from per-agent stimulus partials            |
| `Build-AgentInventory.ps1`                | Generate the authoritative agent inventory used by eval suites                      |
| `Get-AgentDependencyMap.ps1`              | Build a JSON map of agent dependencies for the baseline-equivalence dispatcher      |
| `Get-ChangedAIArtifact.ps1`               | Emit a JSON manifest of AI customization artifacts changed between two git refs     |
| `Get-ChangedSpecStimulus.ps1`             | Emit a JSON manifest of synthetic artifacts derived from changed eval specs         |
| `Invoke-AgentMatrix.ps1`                  | Run the agent-behavior matrix and aggregate per-agent summaries                     |
| `Invoke-ArtifactModeration.ps1`           | Moderate all eval specs plus changed AI artifacts as a pre-job gate                 |
| `Invoke-BaselineEquivalence.ps1`          | Run baseline-vs-customized equivalence evals for a target agent                     |
| `Invoke-ContentModeration.ps1`            | Invoke the content moderation CLI over prompt or output content                     |
| `Invoke-CorpusModeration.ps1`             | Moderate changed AI corpus content from the changed-artifact manifest               |
| `Invoke-VallyEvals.ps1`                   | Execute vally evals for changed AI artifacts                                        |
| `New-AgentMatrixDashboard.ps1`            | Render a self-contained HTML dashboard for the per-agent behavior matrix            |
| `New-AgentSurfaceSignatures.ps1`          | Generate a per-agent surface signature YAML for baseline equivalence runs           |
| `New-EquivalenceDashboard.ps1`            | Render a self-contained HTML dashboard for a local baseline-equivalence run         |
| `Test-CopilotToken.ps1`                   | Pre-flight probe for the `COPILOT_GITHUB_TOKEN` secret used by vally evals          |
| `Test-EvalSpec.ps1`                       | Validate vally eval spec files against the embedded schema                          |
| `Test-EvalSpecText.ps1`                   | Run alex.js and retext-profanities against the AI-artifact markdown corpus          |
| `Test-StimulusPresence.ps1`               | Verify every changed AI artifact has a matching eval-spec stimulus backlink         |
| `Test-VallyTestSafety.ps1`                | Repo-wide safety lint flagging eval stimuli and corpora that need refusal coverage  |
| `Update-AgentMatrixSummariesFromLogs.ps1` | Rebuild per-agent matrix JSON summaries from existing vally logs without re-running |

Most of these run through CI-owned `ci:eval:*` package scripts. See
[../docs/contributing/evals-ci.md](../docs/contributing/evals-ci.md) for the command
taxonomy and prerequisites, and [../evals/README.md](../evals/README.md) for the broader
eval framework documentation.

`Get-AgentDependencyMap.ps1`, `Get-ChangedAIArtifact.ps1`, `Get-ChangedSpecStimulus.ps1`,
`New-AgentSurfaceSignatures.ps1`, `Test-CopilotToken.ps1`, and
`Update-AgentMatrixSummariesFromLogs.ps1` have no package-script wrapper and are invoked
directly by workflows or run ad hoc with `pwsh -NoProfile -File`.

## Devcontainer Scripts

The `devcontainer/` directory contains scripts for devcontainer infrastructure validation:

| Script                            | Purpose                                                  |
|-----------------------------------|----------------------------------------------------------|
| `Test-DevcontainerLockfile.ps1`   | Validate lockfile existence, SHA-256 integrity, coverage |
| `Write-DevcontainerChangeLog.ps1` | Classify changed files and generate markdown summary     |

Run locally:

```bash
npm run validate:devcontainer-lockfile
npm run validate:devcontainer-changelog
```

## Docs

The `docs/` directory contains the asset documentation generator, shared helper modules, and templates.

| Script                     | Purpose                                                                                                                                                                                         |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Generate-AssetDocs.ps1`   | Deterministic generator that creates and refreshes reference pages, safely removes untouched orphan scaffolds, preserves authored or ambiguous orphans, and supports `-WhatIf` drift reporting. |
| `Modules/DocsHelpers.psm1` | Shared helper module for asset enumeration, path resolution, and generated-region marker split/merge.                                                                                           |

Run locally:

```bash
npm run docs:generate
npm run docs:generate:check
npm run lint:asset-docs
```

The generator removes an orphan only when its generated markers are intact and
its human-section tail still matches a canonical scaffold exactly. Other
orphans are preserved and reported for manual disposition. The asset-doc lint
fails on orphan pages, missing current pages, and generated-region drift.

## Security Scripts

The `security/` directory contains scripts for security scanning and dependency management:

| Script                              | Purpose                                                              |
|-------------------------------------|----------------------------------------------------------------------|
| `Install-PSModules.ps1`             | Install pinned PowerShell modules for local and CI environments      |
| `Invoke-PipAudit.ps1`               | Audit Python dependencies for known vulnerabilities                  |
| `Sign-PlannerArtifacts.ps1`         | Generate a SHA-256 manifest for planner artifacts and sign it        |
| `Test-ActionVersionConsistency.ps1` | Validate action version consistency                                  |
| `Test-DangerousWorkflow.ps1`        | Detect template-injection patterns in GitHub Actions workflows       |
| `Test-DependencyPinning.ps1`        | Validate dependency pinning compliance                               |
| `Test-PrValidationGate.ps1`         | Validate that the PR-validation gate job depends on every other job  |
| `Test-PSModulePins.ps1`             | Validate PowerShell module version pins against the canonical config |
| `Test-PublicDependencyFeeds.ps1`    | Validate that committed dependency metadata uses public feeds        |
| `Test-SHAStaleness.ps1`             | Check for outdated SHA pins                                          |
| `Test-WorkflowPermissions.ps1`      | Validate least-privilege permissions in workflows                    |
| `Update-ActionSHAPinning.ps1`       | Automate updating GitHub Actions SHA pins                            |

Run locally:

```bash
npm run lint:dangerous-workflow
npm run lint:pr-gate
npm run lint:ps-module-pins
npm run lint:public-dependency-feeds
npm run security:sign
```

`Install-PSModules.ps1`, `Test-SHAStaleness.ps1`, and `Update-ActionSHAPinning.ps1` have no
package-script wrapper and are invoked directly by CI: `Install-PSModules.ps1` by the
`setup-ps-modules` composite action and `copilot-setup-steps.yml`, `Test-SHAStaleness.ps1`
by `sha-staleness-check.yml`, and `Update-ActionSHAPinning.ps1` by
`weekly-security-maintenance.yml`. Run them ad hoc with `pwsh -NoProfile -File`.

See [security/README.md](security/README.md) for detailed documentation.

## Plugins

Copilot CLI plugin manifest synchronization and validation.

| Script                    | Purpose                                                            |
|---------------------------|--------------------------------------------------------------------|
| `Sync-PluginManifest.ps1` | Write deterministic membership or check manifest and locator drift |

## Tests

Pester test organization matching the scripts structure.

| Directory       | Tests For                     |
|-----------------|-------------------------------|
| `lib/`          | Shared helper tests           |
| `devcontainer/` | Devcontainer validation tests |
| `extension/`    | Extension packaging tests     |
| `plugins/`      | Plugin manifest sync tests    |
| `linting/`      | Linting script tests          |
| `security/`     | Security validation tests     |
| `Fixtures/`     | Shared test fixtures          |
| `Mocks/`        | Shared mock data              |

Run all tests:

```bash
npm run test:ps
```

## Usage

All scripts are designed to run both locally and in GitHub Actions workflows. They support common parameters like `-Verbose` and `-Debug` for troubleshooting.

### Local Testing

```powershell
# Test PSScriptAnalyzer on changed files
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -ChangedFilesOnly -Verbose

# Validate markdown frontmatter
./scripts/linting/Validate-MarkdownFrontmatter.ps1 -Verbose

# Check for language paths in URLs
./scripts/linting/Invoke-LinkLanguageCheck.ps1 -Verbose
```

### GitHub Actions Integration

All scripts automatically detect GitHub Actions environment and provide appropriate output formatting (annotations, summaries, artifacts).

## Contributing

When adding new scripts:

1. Follow PowerShell best practices (PSScriptAnalyzer compliant)
2. Include the entry point guard pattern (see below)
3. Support `-Verbose` and `-Debug` parameters
4. Add GitHub Actions integration using `LintingHelpers` module functions
5. Include inline help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE`
6. Document in relevant README files
7. Test locally before creating PR

### Entry Point Guard Pattern

All production scripts use a dot-source guard that enables Pester tests to import
functions without executing main logic. Extract main logic into an `Invoke-*`
orchestrator function and wrap direct execution in a guard block.

Use the simple variant when the orchestrator has no meaningful result beyond success or
failure:

```powershell
#region Functions

function Invoke-ScriptMain {
    [CmdletBinding()]
    param( <# script params #> )
    # Main logic here
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ScriptMain @PSBoundParameters
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "ScriptName failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
```

Use an `Invoke-*Core` name when the function is a stable in-process test surface. When
the core returns a result object, keep exit codes and command-line output in the guarded
main block:

```powershell
function Invoke-ScriptCore {
    [CmdletBinding()]
    param( <# script params #> )

    return [PSCustomObject]@{
        Outcome = 'Wrote'
        OutputPath = 'output/example.yml'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-ScriptCore @PSBoundParameters
        if ($result.Outcome -eq 'Drift') { exit 1 }
        if ($result.Outcome -in 'Wrote', 'Skipped') { $result.OutputPath }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "ScriptName failed: $($_.Exception.Message)"
        exit 1
    }
}
```

Key rules:

* The `if` guard wraps `try`/`catch` (not the reverse)
* Name the orchestrator `Invoke-*` matching the script noun; use the `Core` suffix for a function designed for direct dot-sourced tests
* Keep `exit` calls in the guarded main block so a dot-sourced core can return structured results to Pester
* Use `#region Functions` and `#region Main Execution` markers
* See [Package-Extension.ps1](extension/Package-Extension.ps1) for the established result-object pattern and [Build-AgentBehaviorSpec.ps1](evals/Build-AgentBehaviorSpec.ps1) for an `Invoke-*Core` example

## Related Documentation

* [Plugin Scripts Documentation](plugins/README.md)
* [Extension Packaging Documentation](extension/README.md)
* [Library Utilities Documentation](lib/README.md)
* [Linting Scripts Documentation](linting/README.md)
* [Security Scripts Documentation](security/README.md)
* [Test Organization Documentation](tests/README.md)
* [Agent Activation Harness Documentation](agents/activation-harness/README.md)
* [Evaluation Framework Documentation](../evals/README.md)
* [GitHub Workflows Documentation](../.github/workflows/README.md)
* [Contributing Guidelines](../CONTRIBUTING.md)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
