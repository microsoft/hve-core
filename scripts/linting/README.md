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

| Component                                         | Description                                                                                 |
|---------------------------------------------------|---------------------------------------------------------------------------------------------|
| Wrapper Scripts (`Invoke-*.ps1`)                  | Entry points that orchestrate validation logic                                              |
| Core Scripts                                      | Existing validation logic (e.g., `Link-Lang-Check.ps1`, `Validate-MarkdownFrontmatter.ps1`) |
| Shared Module (`Modules/LintingHelpers.psm1`)     | Common functions for file discovery and git operations                                      |
| CI Helpers (`scripts/lib/Modules/CIHelpers.psm1`) | CI annotations, outputs, env flags, and step summaries                                      |
| Configuration Files                               | Tool-specific settings (e.g., `PSScriptAnalyzer.psd1`, `markdown-link-check.config.json`)   |

## Scripts

### PowerShell Linting

#### `Invoke-PSScriptAnalyzer.ps1`

Static analysis for PowerShell scripts using PSScriptAnalyzer.

**Purpose**: Enforce PowerShell best practices and detect common issues.

**Features**:

* Detects changed PowerShell files via Git
* Supports analyzing all files or changed files only
* Creates CI annotations for violations
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

* Workflow: `.github/workflows/ps-script-analyzer.yml`
* Artifacts: `psscriptanalyzer-results` (JSON + markdown)
* Exit Code: Non-zero if violations found

#### `PSScriptAnalyzer.psd1`

Configuration file for PSScriptAnalyzer rules.

**Enforced Rules**:

| Rule Category  | Description                                       |
|----------------|---------------------------------------------------|
| Severity       | Error and Warning levels                          |
| Best Practices | Avoid aliases, use approved verbs, singular nouns |
| Help           | Require comment-based help                        |
| Security       | Check for credentials in code                     |
| Performance    | Identify inefficient patterns                     |

**Excluded Rules**:

* `PSAvoidUsingWriteHost` - Allowed for script output

### YAML Linting

#### `Invoke-YamlLint.ps1`

Static analysis for GitHub Actions workflow files using actionlint.

**Purpose**: Validate GitHub Actions workflow YAML syntax and best practices.

**Features**:

* Validates `.github/workflows/*.yml` and `.yaml` files
* Detects changed workflow files via Git
* Supports analyzing all files or changed files only
* Creates CI annotations for violations
* Exports JSON results and markdown summary
* Configurable via `.github/actionlint.yaml`

**Parameters**:

* `-ChangedFilesOnly` (switch) - Analyze only files changed in current branch
* `-BaseBranch` (string) - Base branch for comparison (default: `origin/main`)
* `-OutputPath` (string) - Output path for JSON results (default: `logs/yaml-lint-results.json`)

**Usage**:

```powershell
# Analyze all workflow files
./scripts/linting/Invoke-YamlLint.ps1 -Verbose

# Analyze only changed files
./scripts/linting/Invoke-YamlLint.ps1 -ChangedFilesOnly

# View detailed output
./scripts/linting/Invoke-YamlLint.ps1 -Verbose -Debug
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/yaml-lint.yml`
* Configuration: `.github/actionlint.yaml`
* Artifacts: `yaml-lint-results` (JSON)
* Exit Code: Non-zero if violations found

### Markdown Validation

#### `Validate-MarkdownFrontmatter.ps1`

Validates YAML frontmatter and footer format in markdown files.

**Purpose**: Ensure consistent metadata across documentation.

**Features**:

* Validates required frontmatter fields
* Checks footer format and copyright notice
* Supports changed files only mode
* Configurable warnings-as-errors
* Creates CI annotations for all issues
* Exports JSON results with detailed statistics
* Generates comprehensive step summary

**Parameters**:

* `-ChangedFilesOnly` (switch) - Validate only changed markdown files
* `-SkipFooterValidation` (switch) - Skip footer checks
* `-WarningsAsErrors` (switch) - Treat warnings as errors
* `-EnableSchemaValidation` (switch) - Enable JSON Schema validation (advisory only)

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
* Creates CI warning annotations
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
* Creates CI annotations for broken links
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

### Skill Structure Validation

#### `Validate-SkillStructure.ps1`

Validates the structural integrity of skill directories under `.github/skills/`.

**Purpose**: Ensure all skill packages comply with the agentskills.io specification and hve-core conventions.

**Features**:

* Validates SKILL.md presence in each skill directory
* Checks frontmatter for required `name` and `description` fields
* Verifies `name` matches directory name
* When `scripts/` subdirectory exists, requires both `.ps1` and `.sh` files for cross-platform support
* Warns on unrecognized directories
* Supports changed-files-only mode via Git
* Creates CI annotations for violations
* Exports JSON results to `logs/skill-validation-results.json`

**Parameters**:

* `-SkillsPath` (string) - Root path containing skill directories (default: `.github/skills`)
* `-WarningsAsErrors` (switch) - Treat warnings as errors
* `-ChangedFilesOnly` (switch) - Validate only skills with changed files
* `-BaseBranch` (string) - Git reference for changed file detection (default: `origin/main`)

**Usage**:

```powershell
# Validate all skills
./scripts/linting/Validate-SkillStructure.ps1

# Validate with warnings as errors
./scripts/linting/Validate-SkillStructure.ps1 -WarningsAsErrors

# Validate only changed skills
./scripts/linting/Validate-SkillStructure.ps1 -ChangedFilesOnly
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/skill-validation.yml`
* Artifacts: `skill-validation-results` (JSON)
* Exit Code: Non-zero if validation fails

### Copyright Header Validation

#### `Test-CopyrightHeaders.ps1`

Validates copyright and SPDX license headers in source files.

**Purpose**: Ensure all PowerShell and shell scripts include the required Microsoft copyright notice and MIT SPDX license identifier in their first 15 lines.

**Features**:

* Scans `.ps1`, `.psm1`, `.psd1`, and `.sh` files recursively
* Checks for `Copyright (c) Microsoft Corporation` header
* Checks for `SPDX-License-Identifier: MIT` identifier
* Configurable file extensions and exclude paths
* Exports JSON results with per-file compliance details
* Calculates compliance percentage across all scanned files

**Parameters**:

* `-Path` (string) - Root path to scan (default: repository root via `git rev-parse --show-toplevel`)
* `-FileExtensions` (string[]) - File extensions to check (default: `@('*.ps1', '*.psm1', '*.psd1', '*.sh')`)
* `-OutputPath` (string) - Path for JSON results (default: `logs/copyright-header-results.json`)
* `-FailOnMissing` (switch) - Exit with code 1 if any files lack required headers
* `-ExcludePaths` (string[]) - Directories to exclude (default: `@('node_modules', '.git', 'vendor', 'logs')`)

**Usage**:

```powershell
# Check all source files (report only)
./scripts/linting/Test-CopyrightHeaders.ps1

# Check and fail on missing headers
./scripts/linting/Test-CopyrightHeaders.ps1 -FailOnMissing

# Check specific path with verbose output
./scripts/linting/Test-CopyrightHeaders.ps1 -Path ./scripts -FailOnMissing -Verbose
```

**GitHub Actions Integration**:

* Workflow: `.github/workflows/copyright-headers.yml`
* Artifacts: `copyright-header-results` (JSON)
* Exit Code: Non-zero if validation fails (with `-FailOnMissing`)

## Shared Module

### `Modules/LintingHelpers.psm1`

Common helper functions for file discovery and git operations.

**Exported Functions**:

#### `Get-ChangedFilesFromGit`

Detects files changed in current branch compared to main.

**Parameters**:

* `-BaseBranch` (string) - Base branch to compare against (default: `origin/main`)
* `-FileExtensions` (string[]) - Array of file patterns to filter (e.g., `@('*.ps1', '*.md')`)

**Returns**: Array of changed file paths

**Fallbacks**:

1. `git merge-base` with specified base branch
2. `git diff HEAD~1` when merge-base fails
3. `git diff HEAD` for staged/unstaged files

#### `Get-FilesRecursive`

Finds files matching patterns using `git ls-files` with a `Get-ChildItem` fallback.

**Parameters**:

* `-Path` (string, required) - Root directory to search from
* `-Include` (string[], required) - File patterns to include (e.g., `@('*.ps1', '*.psm1')`)
* `-GitIgnorePath` (string) - Path to `.gitignore` file for exclusion patterns (fallback path only)

**Returns**: Array of FileInfo objects

**Behavior**:

* Inside a git repository, uses `git ls-files --cached --others --exclude-standard` scoped to the given path. Git natively handles `.gitignore` exclusions.
* Outside a git repository (or when `git` is unavailable), falls back to `Get-ChildItem -Recurse` with optional `-GitIgnorePath` filtering.

#### `Get-GitIgnorePatterns`

Parses `.gitignore` into PowerShell wildcard patterns.

**Parameters**:

* `-GitIgnorePath` (string, required) - Path to `.gitignore` file

**Returns**: Array of wildcard patterns using platform-appropriate separators

### `scripts/lib/Modules/CIHelpers.psm1`

CI helper functions for annotations, outputs, environment flags, and summaries.

**Exported Functions**:

#### `Write-CIAnnotation`

Creates a CI annotation.

**Parameters**:

* `-Level` ('Error'|'Warning'|'Notice') - Annotation severity
* `-Message` (string) - Annotation text
* `-File` (string, optional) - File path
* `-Line` (int, optional) - Line number
* `-Column` (int, optional) - Column number

**Output**: CI annotation command

#### `Write-CIAnnotations`

Writes CI annotations from a validation summary.

**Parameters**:

* `-Summary` (ValidationSummary) - Validation results to annotate

#### `Set-CIOutput`

Sets a CI output variable.

**Parameters**:

* `-Name` (string) - Variable name
* `-Value` (string) - Variable value

#### `Set-CIEnv`

Sets a CI environment variable.

**Parameters**:

* `-Name` (string) - Variable name
* `-Value` (string) - Variable value

#### `Write-CIStepSummary`

Appends content to the CI step summary.

**Parameters**:

* `-Content` (string) - Markdown content

**Usage Example**:

```powershell
Import-Module ./Modules/LintingHelpers.psm1

# Get changed PowerShell files
$files = Get-ChangedFilesFromGit -FileExtension '.ps1'

# Create error annotation
Write-CIAnnotation -Level 'Error' -Message 'Syntax error' -File 'script.ps1' -Line 42

# Set output variable
Set-CIOutput -Name 'files-analyzed' -Value $files.Count

# Add to step summary
Write-CIStepSummary -Content "## Results`n`nAnalyzed $($files.Count) files"
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

| Script                 | Workflow                                       |
|------------------------|------------------------------------------------|
| PSScriptAnalyzer       | `.github/workflows/ps-script-analyzer.yml`     |
| YAML Lint              | `.github/workflows/yaml-lint.yml`              |
| Frontmatter Validation | `.github/workflows/frontmatter-validation.yml` |
| Link Language Check    | `.github/workflows/link-lang-check.yml`        |
| Markdown Link Check    | `.github/workflows/markdown-link-check.yml`    |

See [GitHub Workflows Documentation](../../.github/workflows/README.md) for details.

## Adding New Linting Scripts

To add a new linting script:

1. **Create wrapper script** following `Invoke-*.ps1` naming convention
2. **Import LintingHelpers and CIHelpers modules** for file discovery and CI integration
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

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Invoke-MyValidatorCore {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [switch]$ChangedFilesOnly
    )

    Write-Host "🔍 Running MyValidator..."

    if ($ChangedFilesOnly) {
        $files = Get-ChangedFilesFromGit -FileExtension '.ext'
    }
    else {
        $files = Get-FilesRecursive -Path (Get-Location) -Pattern '*.ext'
    }

    if ($files.Count -eq 0) {
        Write-Host "✅ No files to validate"
        return
    }

    # Perform validation
    $issues = @()
    foreach ($file in $files) {
        # Validation logic here
        if ($issue) {
            $issues += $issue
            Write-CIAnnotation -Level 'Error' -Message 'Issue found' -File $file
        }
    }

    Write-CIStepSummary -Content "## Validation Results`n`nFound $($issues.Count) issues"

    if ($issues.Count -gt 0) {
        throw "Found $($issues.Count) issues"
    }

    Write-Host "✅ All files validated successfully"
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-MyValidatorCore @PSBoundParameters
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-MyValidator failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
```

## Contributing

When modifying linting scripts:

1. Follow PowerShell best practices (PSScriptAnalyzer compliant)
2. Maintain CI integration patterns
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
