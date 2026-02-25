---
title: Scripts
description: PowerShell scripts for linting, validation, and security automation
author: HVE Core Team
ms.date: 2025-11-05
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
├── collections/     Collection validation and shared helpers
├── extension/       VS Code extension packaging utilities
├── lib/             Shared utility modules
├── linting/         PowerShell linting and validation scripts
├── plugins/         Copilot CLI plugin generation
├── security/        Security scanning and SHA pinning scripts
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

## Linting Scripts

The `linting/` directory contains scripts for validating code quality and documentation:

| Script                             | Purpose                                            |
|------------------------------------|----------------------------------------------------|
| `Invoke-PSScriptAnalyzer.ps1`      | Static analysis for PowerShell files               |
| `Validate-MarkdownFrontmatter.ps1` | Validate YAML frontmatter in markdown files        |
| `Validate-SkillStructure.ps1`      | Validate skill directory structure and frontmatter |
| `Invoke-LinkLanguageCheck.ps1`     | Detect en-us language paths in URLs                |
| `Link-Lang-Check.ps1`              | Link language checking entry point                 |
| `Markdown-Link-Check.ps1`          | Validate markdown links                            |
| `Invoke-YamlLint.ps1`              | YAML file validation                               |
| `Test-CopyrightHeaders.ps1`        | Validate copyright headers in source files         |

See [linting/README.md](linting/README.md) for detailed documentation.

## Security Scripts

The `security/` directory contains scripts for security scanning and dependency management:

| Script                              | Purpose                                   |
|-------------------------------------|-------------------------------------------|
| `Test-DependencyPinning.ps1`        | Validate SHA pinning compliance           |
| `Test-SHAStaleness.ps1`             | Check for outdated SHA pins               |
| `Update-ActionSHAPinning.ps1`       | Automate updating GitHub Actions SHA pins |
| `Test-ActionVersionConsistency.ps1` | Validate action version consistency       |

## Plugins

Copilot CLI plugin generation and validation.

| Script                     | Purpose                                   |
|----------------------------|-------------------------------------------|
| `Generate-Plugins.ps1`     | Generate plugin packages from collections |
| `Validate-Marketplace.ps1` | Validate marketplace metadata             |

## Collections

Collection validation and shared helpers.

| Script                     | Purpose                                    |
|----------------------------|--------------------------------------------|
| `Validate-Collections.ps1` | Validate collection metadata and structure |

## Tests

Pester test organization matching the scripts structure.

| Directory      | Tests For                 |
|----------------|---------------------------|
| `collections/` | Collection helpers tests  |
| `extension/`   | Extension packaging tests |
| `lib/`         | Library utility tests     |
| `linting/`     | Linting script tests      |
| `security/`    | Security validation tests |
| `plugins/`     | Plugin generation tests   |
| `Fixtures/`    | Shared test fixtures      |
| `Mocks/`       | Shared mock data          |

Run all tests:

```bash
npm run test:ps
```

## Usage

All scripts are designed to run both locally and in GitHub Actions workflows. They support common parameters like `-Verbose` and `-Debug` for troubleshooting.

**Local Testing**:

```powershell
# Test PSScriptAnalyzer on changed files
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -ChangedFilesOnly -Verbose

# Validate markdown frontmatter
./scripts/linting/Validate-MarkdownFrontmatter.ps1 -Verbose

# Check for language paths in URLs
./scripts/linting/Invoke-LinkLanguageCheck.ps1 -Verbose
```

**GitHub Actions Integration**:

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

All production scripts use a dot-source guard that enables Pester tests to import functions without executing main logic. Extract main logic into an `Invoke-*` orchestrator function and wrap direct execution in a guard block:

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

Key rules:

* The `if` guard wraps `try`/`catch` (not the reverse)
* Name the orchestrator `Invoke-*` matching the script noun
* Use `#region Functions` and `#region Main Execution` markers
* See [Package-Extension.ps1](extension/Package-Extension.ps1) for a canonical example

## Related Documentation

* [Collection Scripts Documentation](collections/README.md)
* [Extension Packaging Documentation](extension/README.md)
* [Library Utilities Documentation](lib/README.md)
* [Linting Scripts Documentation](linting/README.md)
* [Plugin Generation Documentation](plugins/README.md)
* [Security Scripts Documentation](security/README.md)
* [Test Organization Documentation](tests/README.md)
* [GitHub Workflows Documentation](../.github/workflows/README.md)
* [Contributing Guidelines](../CONTRIBUTING.md)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
