#!/usr/bin/env pwsh
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
#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/yaml-lint-results.json"
)

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force

Write-Host "🔍 Running YAML Lint (actionlint)..." -ForegroundColor Cyan

# Check if actionlint is available
$actionlintPath = Get-Command actionlint -ErrorAction SilentlyContinue
if (-not $actionlintPath) {
    Write-Error "actionlint is not installed. See script help for installation instructions."
    exit 1
}

Write-Verbose "Using actionlint: $($actionlintPath.Source)"

# Get files to analyze
$workflowPath = ".github/workflows"
$filesToAnalyze = @()

if ($ChangedFilesOnly) {
    Write-Host "Detecting changed workflow files..." -ForegroundColor Cyan
    $changedFiles = Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.yml', '*.yaml')
    $filesToAnalyze = $changedFiles | Where-Object { $_ -like "$workflowPath/*" }
}
else {
    Write-Host "Analyzing all workflow files..." -ForegroundColor Cyan
    if (Test-Path $workflowPath) {
        $filesToAnalyze = Get-ChildItem -Path $workflowPath -File | Where-Object { $_.Extension -in '.yml', '.yaml' } | ForEach-Object { $_.FullName }
    }
}

if ($filesToAnalyze.Count -eq 0) {
    Write-Host "✅ No workflow files to analyze" -ForegroundColor Green
    Set-GitHubOutput -Name "count" -Value "0"
    Set-GitHubOutput -Name "issues" -Value "0"
    exit 0
}

Write-Host "Analyzing $($filesToAnalyze.Count) workflow files..." -ForegroundColor Cyan
Set-GitHubOutput -Name "count" -Value $filesToAnalyze.Count

#region Main Execution
try {
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
        
        # Create GitHub annotation
        Write-GitHubAnnotation `
            -Type 'error' `
            -Message $issue.message `
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
    Set-GitHubOutput -Name "issues" -Value $summary.TotalIssues
    Set-GitHubOutput -Name "errors" -Value $summary.Errors

    if ($hasErrors) {
        Set-GitHubEnv -Name "YAML_LINT_FAILED" -Value "true"
    }

    # Write summary
    Write-GitHubStepSummary -Content "## YAML Lint Results`n"

    if ($summary.TotalIssues -eq 0) {
        Write-GitHubStepSummary -Content "✅ **Status**: Passed`n`nAll $($summary.TotalFiles) workflow files passed validation."
        Write-Host "`n✅ All workflow files passed YAML linting!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-GitHubStepSummary -Content @"
❌ **Status**: Failed

| Metric | Count |
|--------|-------|
| Files Analyzed | $($summary.TotalFiles) |
| Total Issues | $($summary.TotalIssues) |
| Errors | $($summary.Errors) |
"@
        
        Write-Host "`n❌ YAML Lint found $($summary.TotalIssues) issue(s)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "YAML Lint failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion