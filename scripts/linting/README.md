---
title: Linting Scripts
description: PowerShell scripts for code quality validation and documentation checks
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - powershell
  - linting
  - validation
  - code quality
  - markdown
estimated_reading_time: 10
---

This directory contains PowerShell scripts for validating code quality and documentation standards in the `hve-core` repository.

## Architecture

The linting scripts follow a **modular architecture** with shared helper functions:

* **Wrapper Scripts** (`Invoke-*.ps1`) - Entry points that orchestrate validation logic
* **Core Scripts** - Existing validation logic (e.g., `Link-Lang-Check.ps1`, `Validate-MarkdownFrontmatter.ps1`)
* **Shared Module** (`Modules/LintingHelpers.psm1`) - Common functions for GitHub Actions integration
* **Configuration Files** - Tool-specific settings (e.g., `PSScriptAnalyzer.psd1`, `markdown-link-check.config.json`)

## Scripts

### PowerShell Linting

#### `Invoke-PSScriptAnalyzer.ps1`

Static analysis for PowerShell scripts using PSScriptAnalyzer.

**Purpose**: Enforce PowerShell best practices and detect common issues.

**Features**:

* Detects changed PowerShell files via Git
* Supports analyzing all files or changed files only
* Creates GitHub Actions annotations for violations
* Exports JSON results and markdown summary
* Configurable via `PSScriptAnalyzer.psd1`

**Parameters**:

* `-ChangedFilesOnly` (switch) - Analyze only files changed in current branch

**Usage**:

```powershell
# Analyze all PowerShell files
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -Verbose

# Analyze only changed files
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -ChangedFilesOnly

# View detailed output
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -Verbose -Debug
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/psscriptanalyzer.yml`
* Artifacts: `psscriptanalyzer-results` (JSON + markdown)
* Exit Code: Non-zero if violations found

#### `PSScriptAnalyzer.psd1`

Configuration file for PSScriptAnalyzer rules.

**Enforced Rules**:

* **Severity**: Error and Warning levels
* **Best Practices**: Avoid aliases, use approved verbs, singular nouns
* **Help**: Require comment-based help
* **Security**: Check for credentials in code
* **Performance**: Identify inefficient patterns

**Excluded Rules**:

* `PSAvoidUsingWriteHost` - Allowed for script output

### Markdown Validation

#### `Validate-MarkdownFrontmatter.ps1`

Validates YAML frontmatter and footer format in markdown files.

**Purpose**: Ensure consistent metadata across documentation.

**Features**:

* Validates required frontmatter fields
* Checks footer format and copyright notice
* Supports changed files only mode
* Configurable warnings-as-errors
* Creates GitHub Actions annotations for all issues
* Exports JSON results with detailed statistics
* Generates comprehensive step summary

**Parameters**:

* `-ChangedFilesOnly` (switch) - Validate only changed markdown files
* `-SkipFooterValidation` (switch) - Skip footer checks
* `-WarningsAsErrors` (switch) - Treat warnings as errors

**Artifacts Generated**:

* `logs/frontmatter-validation-results.json` - Complete validation results including:
  * Timestamp and script name
  * Summary statistics (total files, error/warning counts)
  * Lists of all errors and warnings

**Usage**:

```powershell
# Validate all markdown files
./scripts/linting/Validate-MarkdownFrontmatter.ps1

# Validate only changed files
./scripts/linting/Validate-MarkdownFrontmatter.ps1 -ChangedFilesOnly

# Skip footer validation
./scripts/linting/Validate-MarkdownFrontmatter.ps1 -SkipFooterValidation
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/frontmatter-validation.yml`
* Artifacts: `frontmatter-validation-results` (JSON)
* Annotations: Errors and warnings with file paths
* Exit Code: Non-zero if validation fails

#### `Invoke-LinkLanguageCheck.ps1`

Detects URLs with language paths (e.g., `/en-us/`) that should be removed.

**Purpose**: Ensure language-agnostic URLs for better internationalization.

**Features**:

* Scans all markdown files recursively
* Calls `Link-Lang-Check.ps1` for detection logic
* Creates GitHub Actions warning annotations
* Provides fix instructions in summary

**Usage**:

```powershell
# Check all markdown files
./scripts/linting/Invoke-LinkLanguageCheck.ps1 -Verbose

# View detection details
./scripts/linting/Invoke-LinkLanguageCheck.ps1 -Debug
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/link-lang-check.yml`
* Annotations: Warnings on files with language paths
* Artifacts: `link-lang-check-results` (JSON + markdown)

#### `Link-Lang-Check.ps1`

Core logic for detecting language paths in URLs.

**Detection Pattern**: Matches `/[a-z]{2}-[a-z]{2}/` patterns in Microsoft domain URLs.

#### `Markdown-Link-Check.ps1`

Validates all links in markdown files using markdown-link-check npm package.

**Purpose**: Detect broken links before deployment.

**Features**:

* Checks internal and external links
* Configurable via `markdown-link-check.config.json`
* Retries failed links
* Respects robots.txt
* Creates GitHub Actions annotations for broken links
* Exports JSON results with link statistics
* Generates detailed step summary

**Artifacts Generated**:

* `logs/markdown-link-check-results.json` - Complete validation results including:
  * Timestamp and script name
  * Summary statistics (total files, broken links count)
  * List of all broken links with file paths

**GitHub Actions Integration**:

* Workflow: `.github/workflows/markdown-link-check.yml`
* Configuration: `markdown-link-check.config.json`
* Artifacts: `markdown-link-check-results` (JSON)
* Annotations: Error for each broken link
* Exit Code: Non-zero if broken links found

## Shared Module

### `Modules/LintingHelpers.psm1`

Common helper functions for GitHub Actions integration and file operations.

**Exported Functions**:

#### `Get-ChangedFilesFromGit`

Detects files changed in current branch compared to main.

**Parameters**:

* `-FileExtension` (string) - Filter by extension (e.g., '.ps1')

**Returns**: Array of changed file paths

**Fallbacks**:

1. `git diff` vs `origin/main`
2. `git diff` vs `main`
3. `git ls-files` (all tracked files)

#### `Get-FilesRecursive`

Recursively finds files matching pattern with gitignore support.

**Parameters**:

* `-Path` (string) - Root directory
* `-Pattern` (string) - File pattern (e.g., '*.ps1')

**Returns**: Array of matching file paths

**Respects**: `.gitignore` patterns

#### `Get-GitIgnorePatterns`

Loads and parses `.gitignore` file.

**Returns**: Array of ignore patterns

#### `Write-GitHubAnnotation`

Creates GitHub Actions annotation.

**Parameters**:

* `-Type` ('error'|'warning'|'notice') - Annotation severity
* `-Message` (string) - Annotation text
* `-File` (string, optional) - File path
* `-Line` (int, optional) - Line number
* `-Column` (int, optional) - Column number

**Output**: GitHub Actions annotation command

#### `Set-GitHubOutput`

Sets GitHub Actions output variable.

**Parameters**:

* `-Name` (string) - Variable name
* `-Value` (string) - Variable value

#### `Set-GitHubEnv`

Sets GitHub Actions environment variable.

**Parameters**:

* `-Name` (string) - Variable name
* `-Value` (string) - Variable value

#### `Write-GitHubStepSummary`

Appends content to GitHub Actions step summary.

**Parameters**:

* `-Content` (string) - Markdown content

**Usage Example**:

```powershell
Import-Module ./Modules/LintingHelpers.psm1

# Get changed PowerShell files
$files = Get-ChangedFilesFromGit -FileExtension '.ps1'

# Create error annotation
Write-GitHubAnnotation -Type 'error' -Message 'Syntax error' -File 'script.ps1' -Line 42

# Set output variable
Set-GitHubOutput -Name 'files-analyzed' -Value $files.Count

# Add to step summary
Write-GitHubStepSummary -Content "## Results`n`nAnalyzed $($files.Count) files"
```

## Configuration Files

### Configuration: `PSScriptAnalyzer.psd1`

PSScriptAnalyzer rule configuration.

**Key Settings**:

* Severity: Error, Warning
* IncludeRules: Best practices, security, performance
* ExcludeRules: `PSAvoidUsingWriteHost`

### `markdown-link-check.config.json`

Markdown link checker configuration.

**Key Settings**:

* Retry attempts: 3
* Timeout: 10 seconds
* Ignore patterns: Localhost, example.com

## Testing

All scripts support local testing before running in GitHub Actions:

```powershell
# Test PSScriptAnalyzer
./scripts/linting/Invoke-PSScriptAnalyzer.ps1 -Verbose

# Test frontmatter validation
./scripts/linting/Validate-MarkdownFrontmatter.ps1 -ChangedFilesOnly

# Test link language check
./scripts/linting/Invoke-LinkLanguageCheck.ps1

# Test markdown links
./scripts/linting/Markdown-Link-Check.ps1

# Test shared module
Import-Module ./scripts/linting/Modules/LintingHelpers.psm1
Get-Command -Module LintingHelpers
```

## GitHub Actions Workflows

All linting scripts are integrated into GitHub Actions workflows:

* **PSScriptAnalyzer**: `.github/workflows/psscriptanalyzer.yml`
* **Frontmatter Validation**: `.github/workflows/frontmatter-validation.yml`
* **Link Language Check**: `.github/workflows/link-lang-check.yml`
* **Markdown Link Check**: `.github/workflows/markdown-link-check.yml`

See [GitHub Workflows Documentation](../../.github/workflows/README.md) for details.

## Adding New Linting Scripts

To add a new linting script:

1. **Create wrapper script** following `Invoke-*.ps1` naming convention
2. **Import LintingHelpers module** for GitHub Actions integration
3. **Implement core validation logic** with clear error reporting
4. **Support common parameters**: `-Verbose`, `-Debug`, `-ChangedFilesOnly` (if applicable)
5. **Create GitHub Actions workflow** in `.github/workflows/`
6. **Add to PR validation** in `.github/workflows/pr-validation.yml`
7. **Document** in this README and workflows README
8. **Test locally** before creating PR

**Template**:

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Brief description of validation.

.DESCRIPTION
    Detailed description.

.PARAMETER ChangedFilesOnly
    Validate only changed files.

.EXAMPLE
    ./scripts/linting/Invoke-MyValidator.ps1 -Verbose
#>

[CmdletBinding()]
param(
    [switch]$ChangedFilesOnly
)

# Import shared helpers
$scriptPath = $PSScriptRoot
Import-Module "$scriptPath/Modules/LintingHelpers.psm1" -Force

# Main validation logic
Write-Host "🔍 Running MyValidator..."

if ($ChangedFilesOnly) {
    $files = Get-ChangedFilesFromGit -FileExtension '.ext'
} else {
    $files = Get-FilesRecursive -Path (Get-Location) -Pattern '*.ext'
}

if ($files.Count -eq 0) {
    Write-Host "✅ No files to validate"
    exit 0
}

# Perform validation
$issues = @()
foreach ($file in $files) {
    # Validation logic here
    if ($issue) {
        $issues += $issue
        Write-GitHubAnnotation -Type 'error' -Message 'Issue found' -File $file
    }
}

# Export results
if ($env:GITHUB_ACTIONS) {
    Write-GitHubStepSummary -Content "## Validation Results`n`nFound $($issues.Count) issues"
}

if ($issues.Count -gt 0) {
    Write-Host "❌ Found $($issues.Count) issues"
    exit 1
}

Write-Host "✅ All files validated successfully"
exit 0
```

## Contributing

When modifying linting scripts:

1. Follow PowerShell best practices (PSScriptAnalyzer compliant)
2. Maintain GitHub Actions integration patterns
3. Keep scripts testable locally without GitHub Actions
4. Update documentation in README files
5. Test thoroughly before creating PR
6. Get CODEOWNERS approval

## Related Documentation

* [Scripts Documentation](../README.md)
* [GitHub Workflows Documentation](../../.github/workflows/README.md)
* [Contributing Guidelines](../../CONTRIBUTING.md)

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
