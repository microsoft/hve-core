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

* **PSScriptAnalyzer**: Static analysis for PowerShell files
* **Markdown Frontmatter**: Validate YAML frontmatter in markdown files
* **Skill Structure**: Validate skill directory structure and frontmatter
* **Link Language Check**: Detect en-us language paths in URLs
* **Markdown Link Check**: Validate markdown links
* **Shared Module**: Common helper functions for GitHub Actions integration

See [linting/README.md](linting/README.md) for detailed documentation.

## Security Scripts

The `security/` directory contains scripts for security scanning and dependency management:

* **Dependency Pinning**: Validate SHA pinning compliance
* **SHA Staleness**: Check for outdated SHA pins
* **SHA Updates**: Automate updating GitHub Actions SHA pins

## Tests

Pester test organization matching the scripts structure.

| Directory      | Tests For                 |
|----------------|---------------------------|
| `collections/` | Collection helpers tests  |
| `extension/`   | Extension packaging tests |
| `lib/`         | Library utility tests     |
| `linting/`     | Linting script tests      |
| `security/`    | Security validation tests |

Run all tests:

```bash
npm run test
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

* [Linting Scripts Documentation](linting/README.md)
* [GitHub Workflows Documentation](../.github/workflows/README.md)
* [Contributing Guidelines](../CONTRIBUTING.md)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
