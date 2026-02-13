#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Validates YAML files using actionlint for GitHub Actions workflows.

.DESCRIPTION
    Runs actionlint to validate GitHub Actions workflow files. Supports changed-files-only
    mode for PR validation and exports JSON results for CI integration.

.PARAMETER ChangedFilesOnly
    Validate only changed YAML files.

.PARAMETER BaseBranch
    Base branch for detecting changed files (default: origin/main).

.PARAMETER OutputPath
    Path for JSON results output (default: logs/yaml-lint-results.json).

.EXAMPLE
    ./scripts/linting/Invoke-YamlLint.ps1 -Verbose

.EXAMPLE
    ./scripts/linting/Invoke-YamlLint.ps1 -ChangedFilesOnly

.NOTES
    Requires actionlint to be installed. Install via:
    - Windows: choco install actionlint -or- scoop install actionlint -or- winget install actionlint
    - macOS: brew install actionlint
    - Linux: go install github.com/rhysd/actionlint/cmd/actionlint@latest
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/yaml-lint-results.json"
)

$ErrorActionPreference = 'Stop'

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Functions

function Invoke-YamlLintCore {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/yaml-lint-results.json"
    )

    Write-Host "🔍 Running YAML Lint (actionlint)..." -ForegroundColor Cyan

    # Check if actionlint is available
    $actionlintPath = Get-Command actionlint -ErrorAction SilentlyContinue
    if (-not $actionlintPath) {
        throw "actionlint is not installed. See script help for installation instructions."
    }

    Write-Verbose "Using actionlint: $($actionlintPath.Source)"

    # Get files to analyze
    $workflowPath = ".github/workflows"
    $filesToAnalyze = @()

    if ($ChangedFilesOnly) {
        Write-Host "Detecting changed workflow files..." -ForegroundColor Cyan
        $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.yml', '*.yaml'))
        $filesToAnalyze = @($changedFiles | Where-Object { $_ -like "$workflowPath/*" })
    }
    else {
        Write-Host "Analyzing all workflow files..." -ForegroundColor Cyan
        if (Test-Path $workflowPath) {
            $filesToAnalyze = @(Get-ChildItem -Path $workflowPath -File | Where-Object { $_.Extension -in '.yml', '.yaml' } | ForEach-Object { $_.FullName })
        }
    }

    if (@($filesToAnalyze).Count -eq 0) {
        Write-Host "✅ No workflow files to analyze" -ForegroundColor Green
        Set-CIOutput -Name "count" -Value "0"
        Set-CIOutput -Name "issues" -Value "0"
        return
    }

    Write-Host "Analyzing $($filesToAnalyze.Count) workflow files..." -ForegroundColor Cyan
    Set-CIOutput -Name "count" -Value $filesToAnalyze.Count

    # Run actionlint with JSON output
    $actionlintArgs = @('-format', '{{json .}}')
    if ($ChangedFilesOnly -and $filesToAnalyze.Count -gt 0) {
        $actionlintArgs += $filesToAnalyze
    }

    $rawOutput = & actionlint @actionlintArgs 2>&1
    # actionlint exit code is not used; errors are parsed from JSON output

    # Parse JSON output
    $issues = @()
    if ($rawOutput -and $rawOutput -ne "null") {
        try {
            $issues = $rawOutput | ConvertFrom-Json -ErrorAction Stop
            if ($null -eq $issues) { $issues = @() }
            if ($issues -isnot [array]) { $issues = @($issues) }
        }
        catch {
            Write-Warning "Failed to parse actionlint output: $($_.Exception.Message)"
            Write-Verbose "Raw output: $rawOutput"
        }
    }

    # Process issues and create annotations
    $hasErrors = $false
    foreach ($issue in $issues) {
        $hasErrors = $true
        
        Write-CIAnnotation `
            -Message $issue.message `
            -Level Error `
            -File $issue.filepath `
            -Line $issue.line `
            -Column $issue.column
        
        Write-Host "  ❌ $($issue.filepath):$($issue.line):$($issue.column): $($issue.message)" -ForegroundColor Red
    }

    # Export results
    $summary = @{
        TotalFiles  = $filesToAnalyze.Count
        TotalIssues = $issues.Count
        Errors      = $issues.Count
        Warnings    = 0
        HasErrors   = $hasErrors
        Timestamp   = (Get-Date -Format "o")
        Tool        = "actionlint"
    }

    # Ensure logs directory exists
    $logsDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    }

    $issues | ConvertTo-Json -Depth 5 | Out-File $OutputPath
    $summary | ConvertTo-Json | Out-File "logs/yaml-lint-summary.json"

    # Set outputs
    Set-CIOutput -Name "issues" -Value $summary.TotalIssues
    Set-CIOutput -Name "errors" -Value $summary.Errors

    if ($hasErrors) {
        Set-CIEnv -Name "YAML_LINT_FAILED" -Value "true"
    }

    # Write summary
    Write-CIStepSummary -Content "## YAML Lint Results`n"

    if ($summary.TotalIssues -eq 0) {
        Write-CIStepSummary -Content "✅ **Status**: Passed`n`nAll $($summary.TotalFiles) workflow files passed validation."
        Write-Host "`n✅ All workflow files passed YAML linting!" -ForegroundColor Green
        return
    }
    else {
        Write-CIStepSummary -Content @"
❌ **Status**: Failed

| Metric | Count |
|--------|-------|
| Files Analyzed | $($summary.TotalFiles) |
| Total Issues | $($summary.TotalIssues) |
| Errors | $($summary.Errors) |
"@
        
        Write-Host "`n❌ YAML Lint found $($summary.TotalIssues) issue(s)" -ForegroundColor Red
        throw "YAML Lint found $($summary.TotalIssues) issue(s)"
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-YamlLintCore -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -OutputPath $OutputPath
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "YAML Lint failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
