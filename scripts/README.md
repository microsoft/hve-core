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
├── linting/         PowerShell linting and validation scripts
└── security/        Security scanning and SHA pinning scripts
```

## Linting Scripts

The `linting/` directory contains scripts for validating code quality and documentation:

* **PSScriptAnalyzer**: Static analysis for PowerShell files
* **Markdown Frontmatter**: Validate YAML frontmatter in markdown files
* **Link Language Check**: Detect en-us language paths in URLs
* **Markdown Link Check**: Validate markdown links
* **Shared Module**: Common helper functions for GitHub Actions integration

See [linting/README.md](linting/README.md) for detailed documentation.

## Security Scripts

The `security/` directory contains scripts for security scanning and dependency management:

* **Dependency Pinning**: Validate SHA pinning compliance
* **SHA Staleness**: Check for outdated SHA pins
* **SHA Updates**: Automate updating GitHub Actions SHA pins

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
2. Support `-Verbose` and `-Debug` parameters
3. Add GitHub Actions integration using `LintingHelpers` module functions
4. Include inline help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE`
5. Document in relevant README files
6. Test locally before creating PR

## Related Documentation

* [Linting Scripts Documentation](linting/README.md)
* [GitHub Workflows Documentation](../.github/workflows/README.md)
* [Contributing Guidelines](../CONTRIBUTING.md)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
