#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4
<#
.SYNOPSIS
    Validates JSON files for strict well-formedness using System.Text.Json.

.DESCRIPTION
    Parses each target JSON file with System.Text.Json.JsonDocument, which rejects
    trailing commas, comments, and trailing content after the root value (such as
    accidentally concatenated objects). This catches malformed JSON that the more
    lenient ConvertFrom-Json silently accepts.

    By default it lints schema and fixture JSON under scripts/linting/schemas and
    scripts/tests/fixtures. Supports changed-files-only mode for PR validation and
    exports JSON results for CI integration.

    Fixtures whose file name matches an ExcludePatterns entry (by default any
    invalid-*.json) are skipped, since some fixtures are intentionally malformed to
    exercise parser error handling.

.PARAMETER Paths
    Directories (or files) to lint. Defaults to the schema and fixture trees.

.PARAMETER ExcludePatterns
    File-name wildcard patterns to skip. Defaults to intentionally-invalid fixtures.

.PARAMETER ChangedFilesOnly
    Validate only changed JSON files within the target paths.

.PARAMETER BaseBranch
    Base branch for detecting changed files (default: origin/main).

.PARAMETER OutputPath
    Path for JSON results output (default: logs/json-lint-results.json).

.EXAMPLE
    ./scripts/linting/Invoke-JsonLint.ps1 -Verbose

.EXAMPLE
    ./scripts/linting/Invoke-JsonLint.ps1 -ChangedFilesOnly

.NOTES
    Requires no external tooling; uses the .NET System.Text.Json parser bundled
    with PowerShell 7.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('scripts/linting/schemas', 'scripts/tests/fixtures'),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePatterns = @('invalid-*.json'),

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/json-lint-results.json"
)

$ErrorActionPreference = 'Stop'

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Functions

function Test-JsonFile {
    <#
    .SYNOPSIS
        Strictly parses a JSON file and returns an issue object when invalid.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $content = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }
    catch {
        return @{
            File    = $Path
            Line    = 0
            Column  = 0
            Message = "Unable to read file: $($_.Exception.Message)"
        }
    }

    if ([string]::IsNullOrWhiteSpace($content)) {
        return @{
            File    = $Path
            Line    = 0
            Column  = 0
            Message = "File is empty or contains only whitespace"
        }
    }

    # JsonDocumentOptions defaults are strict: no trailing commas, comments disallowed.
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($content, $options)
        $document.Dispose()
        return $null
    }
    catch [System.Text.Json.JsonException] {
        $jsonError = $_.Exception
        return @{
            File    = $Path
            Line    = if ($null -ne $jsonError.LineNumber) { [int]$jsonError.LineNumber + 1 } else { 0 }
            Column  = if ($null -ne $jsonError.BytePositionInLine) { [int]$jsonError.BytePositionInLine + 1 } else { 0 }
            Message = $jsonError.Message
        }
    }
    catch {
        return @{
            File    = $Path
            Line    = 0
            Column  = 0
            Message = $_.Exception.Message
        }
    }
}

function Invoke-JsonLintCore {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Paths = @('scripts/linting/schemas', 'scripts/tests/fixtures'),

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePatterns = @('invalid-*.json'),

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/json-lint-results.json"
    )

    Write-Host "🔍 Running JSON Lint (System.Text.Json strict parse)..." -ForegroundColor Cyan

    # Get files to analyze
    $filesToAnalyze = @()

    if ($ChangedFilesOnly) {
        Write-Host "Detecting changed JSON files..." -ForegroundColor Cyan
        $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.json'))
        $filesToAnalyze = @($changedFiles | Where-Object {
                $candidate = $_
                ($Paths | Where-Object { $candidate -like "$_/*" -or $candidate -eq $_ }).Count -gt 0
            })
    }
    else {
        Write-Host "Analyzing all JSON files..." -ForegroundColor Cyan
        foreach ($targetPath in $Paths) {
            if (-not (Test-Path $targetPath)) {
                Write-Verbose "Skipping missing path: $targetPath"
                continue
            }

            if (Test-Path $targetPath -PathType Leaf) {
                if ($targetPath -like '*.json') { $filesToAnalyze += $targetPath }
                continue
            }

            $filesToAnalyze += @(
                Get-ChildItem -Path $targetPath -File -Recurse |
                    Where-Object { $_.Extension -eq '.json' } |
                    ForEach-Object { $_.FullName }
            )
        }
    }

    if ($ExcludePatterns -and $ExcludePatterns.Count -gt 0) {
        $filesToAnalyze = @($filesToAnalyze | Where-Object {
                $leaf = Split-Path $_ -Leaf
                -not @($ExcludePatterns | Where-Object { $leaf -like $_ }).Count
            })
    }

    $filesToAnalyze = @($filesToAnalyze | Sort-Object -Unique)

    if (@($filesToAnalyze).Count -eq 0) {
        Write-Host "✅ No JSON files to analyze" -ForegroundColor Green
        Set-CIOutput -Name "count" -Value "0"
        Set-CIOutput -Name "issues" -Value "0"
        return
    }

    Write-Host "Analyzing $($filesToAnalyze.Count) JSON files..." -ForegroundColor Cyan
    Set-CIOutput -Name "count" -Value $filesToAnalyze.Count

    # Validate each file
    $issues = @()
    foreach ($file in $filesToAnalyze) {
        $issue = Test-JsonFile -Path $file
        if ($null -ne $issue) {
            $issues += $issue

            Write-CIAnnotation `
                -Message $issue.Message `
                -Level Error `
                -File $issue.File `
                -Line $issue.Line `
                -Column $issue.Column

            Write-Host "  ❌ $($issue.File):$($issue.Line):$($issue.Column): $($issue.Message)" -ForegroundColor Red
        }
    }

    $hasErrors = $issues.Count -gt 0

    # Export results
    $summary = @{
        TotalFiles  = $filesToAnalyze.Count
        TotalIssues = $issues.Count
        Errors      = $issues.Count
        Warnings    = 0
        HasErrors   = $hasErrors
        Timestamp   = Get-StandardTimestamp
        Tool        = "System.Text.Json"
    }

    # Ensure logs directory exists
    $logsDir = Split-Path $OutputPath -Parent
    if ($logsDir -and -not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    }

    $issues | ConvertTo-Json -Depth 5 | Out-File $OutputPath
    $summary | ConvertTo-Json | Out-File "logs/json-lint-summary.json"

    # Set outputs
    Set-CIOutput -Name "issues" -Value $summary.TotalIssues
    Set-CIOutput -Name "errors" -Value $summary.Errors

    if ($hasErrors) {
        Set-CIEnv -Name "JSON_LINT_FAILED" -Value "true"
    }

    # Write summary
    Write-CIStepSummary -Content "## JSON Lint Results`n"

    if ($summary.TotalIssues -eq 0) {
        Write-CIStepSummary -Content "✅ **Status**: Passed`n`nAll $($summary.TotalFiles) JSON files passed validation."
        Write-Host "`n✅ All JSON files passed strict validation!" -ForegroundColor Green
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

        Write-Host "`n❌ JSON Lint found $($summary.TotalIssues) issue(s)" -ForegroundColor Red
        throw "JSON Lint found $($summary.TotalIssues) issue(s)"
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-JsonLintCore -Paths $Paths -ExcludePatterns $ExcludePatterns -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -OutputPath $OutputPath
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "JSON Lint failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
