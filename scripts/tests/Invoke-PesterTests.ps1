#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PesterTests.ps1
#
# Purpose: Pester test runner that writes summary and failure details to logs/
# Author: HVE Core Team

#Requires -Version 7.0

<#
.SYNOPSIS
    Runs Pester tests and writes structured output to the logs/ directory.

.DESCRIPTION
    Wraps Invoke-Pester with the repository's Pester configuration and writes
    logs/pester-summary.json (pass/fail counts, duration) and
    logs/pester-failures.json (failure details with error messages and stack traces).

.PARAMETER TestPath
    One or more paths to test files or directories. Defaults to the scripts/tests/ directory.

.PARAMETER CI
    Enables CI mode: NUnit XML output, exit-on-failure, and GitHub Actions log format.

.PARAMETER CodeCoverage
    Enables JaCoCo code coverage reporting to logs/coverage.xml.

.EXAMPLE
    ./scripts/tests/Invoke-PesterTests.ps1

.EXAMPLE
    ./scripts/tests/Invoke-PesterTests.ps1 -TestPath "scripts/tests/linting/"

.EXAMPLE
    ./scripts/tests/Invoke-PesterTests.ps1 -CI -CodeCoverage
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$TestPath,

    [Parameter(Mandatory = $false)]
    [switch]$CI,

    [Parameter(Mandatory = $false)]
    [switch]$CodeCoverage
)

$ErrorActionPreference = 'Stop'

$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$logsDir = Join-Path $repoRoot 'logs'
$configScript = Join-Path $PSScriptRoot 'pester.config.ps1'
$summaryPath = Join-Path $logsDir 'pester-summary.json'
$failuresPath = Join-Path $logsDir 'pester-failures.json'

if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
}

# Build config arguments
$configArgs = @{}
if ($CI) {
    $configArgs['CI'] = $true
}
if ($CodeCoverage) {
    $configArgs['CodeCoverage'] = $true
}
if ($TestPath) {
    $resolvedPaths = @($TestPath | ForEach-Object {
        $p = if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $repoRoot $_ }
        if (-not (Test-Path $p)) {
            Write-Warning "Test path not found: $_"
        }
        $p
    })
    if ($resolvedPaths.Count -gt 0) {
        $configArgs['TestPath'] = $resolvedPaths
    }
}

$configuration = & $configScript @configArgs

# Ensure PassThru and file output are enabled regardless of CI flag
$configuration.Run.PassThru = $true

Write-Host "🧪 Running Pester tests..." -ForegroundColor Cyan
if ($TestPath) {
    Write-Host "   Test paths: $($TestPath -join ', ')" -ForegroundColor Cyan
}

$result = Invoke-Pester -Configuration $configuration

# Build summary
$summary = [ordered]@{
    Timestamp    = (Get-Date -Format 'o')
    Result       = $result.Result
    TotalCount   = $result.TotalCount
    PassedCount  = $result.PassedCount
    FailedCount  = $result.FailedCount
    SkippedCount = $result.SkippedCount
    Duration     = $result.Duration.ToString()
}

if ($CodeCoverage -and $result.CodeCoverage) {
    $summary['CoveragePercent'] = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
}

$summary | ConvertTo-Json -Depth 3 | Out-File -FilePath $summaryPath -Encoding utf8

# Build failures list
$failures = @()
foreach ($test in $result.Tests) {
    if ($test.Result -eq 'Failed') {
        $failures += [ordered]@{
            Name         = $test.ExpandedName
            Path         = $test.ScriptBlock.File
            ErrorMessage = ($test.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join "`n"
            StackTrace   = ($test.ErrorRecord | ForEach-Object { $_.ScriptStackTrace }) -join "`n"
        }
    }
}

# Recursively collect failures from containers when Tests are nested
function Get-FailedTests {
    param([object[]]$Blocks)
    $collected = @()
    foreach ($block in $Blocks) {
        if ($block.Tests) {
            foreach ($test in $block.Tests) {
                if ($test.Result -eq 'Failed') {
                    $collected += [ordered]@{
                        Name         = $test.ExpandedName
                        Path         = if ($test.ScriptBlock.File) { $test.ScriptBlock.File } else { '' }
                        ErrorMessage = ($test.ErrorRecord | ForEach-Object { $_.Exception.Message }) -join "`n"
                        StackTrace   = ($test.ErrorRecord | ForEach-Object { $_.ScriptStackTrace }) -join "`n"
                    }
                }
            }
        }
        if ($block.Blocks) {
            $collected += Get-FailedTests -Blocks $block.Blocks
        }
    }
    return $collected
}

# If top-level Tests didn't capture failures, walk the container tree
if ($failures.Count -eq 0 -and $result.FailedCount -gt 0) {
    $failures = @(Get-FailedTests -Blocks $result.Containers)
}

$failures | ConvertTo-Json -Depth 5 | Out-File -FilePath $failuresPath -Encoding utf8

# Report
if ($result.FailedCount -gt 0) {
    Write-Host "`n❌ $($result.FailedCount) test(s) failed. See logs/pester-summary.json and logs/pester-failures.json" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`n✅ All $($result.PassedCount) tests passed." -ForegroundColor Green
    exit 0
}
