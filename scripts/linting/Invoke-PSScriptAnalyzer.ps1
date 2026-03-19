#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PSScriptAnalyzer.ps1
#
# Purpose: Wrapper for PSScriptAnalyzer with GitHub Actions integration
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = (Join-Path $PSScriptRoot "PSScriptAnalyzer.psd1"),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "logs/psscriptanalyzer-results.json"
)

$ErrorActionPreference = 'Stop'

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Functions

function Invoke-PSScriptAnalyzerCore {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = (Join-Path $PSScriptRoot "PSScriptAnalyzer.psd1"),

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "logs/psscriptanalyzer-results.json"
    )

    Write-Host "🔍 Running PSScriptAnalyzer..." -ForegroundColor Cyan

    # Ensure PSScriptAnalyzer is available
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Host "Installing PSScriptAnalyzer module..." -ForegroundColor Yellow
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -Repository PSGallery
    }

    Import-Module PSScriptAnalyzer

    # Get files to analyze
    $filesToAnalyze = @()

    if ($ChangedFilesOnly) {
        Write-Host "Detecting changed PowerShell files..." -ForegroundColor Cyan
        $filesToAnalyze = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.ps1', '*.psm1', '*.psd1'))
    }
    else {
        Write-Host "Analyzing all PowerShell files..." -ForegroundColor Cyan
        $filesToAnalyze = @(Get-FilesRecursive -Path "." -Include @('*.ps1', '*.psm1', '*.psd1'))
    }

    if (@($filesToAnalyze).Count -eq 0) {
        Write-Host "✅ No PowerShell files to analyze" -ForegroundColor Green
        Set-CIOutput -Name "count" -Value "0"
        Set-CIOutput -Name "issues" -Value "0"
        return
    }

    Write-Host "Analyzing $($filesToAnalyze.Count) PowerShell files..." -ForegroundColor Cyan
    Set-CIOutput -Name "count" -Value $filesToAnalyze.Count

    # Run PSScriptAnalyzer
    $allResults = @()
    $hasErrors = $false

    foreach ($file in $filesToAnalyze) {
        $filePath = if ($file -is [System.IO.FileInfo]) { $file.FullName } else { $file }
        Write-Host "`n📄 Analyzing: $filePath" -ForegroundColor Cyan
        
        $results = Invoke-ScriptAnalyzer -Path $filePath -Settings $ConfigPath
        
        if ($results) {
            $allResults += $results
            
            foreach ($result in $results) {
                $annotationLevel = switch ($result.Severity) {
                    'Error' { 'Error' }
                    'Warning' { 'Warning' }
                    'Information' { 'Notice' }
                    default { 'Notice' }
                }

                Write-CIAnnotation `
                    -Message "$($result.RuleName): $($result.Message)" `
                    -Level $annotationLevel `
                    -File $filePath `
                    -Line $result.Line `
                    -Column $result.Column
                
                $icon = switch ($result.Severity) {
                    'Error' { '❌'; $hasErrors = $true }
                    'Warning' { '⚠️' }
                    default { 'ℹ️' }
                }
                
                Write-Host "  $icon [$($result.Severity)] $($result.RuleName): $($result.Message) (Line $($result.Line))" -ForegroundColor $(
                    if ($result.Severity -eq 'Error') { 'Red' }
                    elseif ($result.Severity -eq 'Warning') { 'Yellow' }
                    else { 'Cyan' }
                )
            }
        }
        else {
            Write-Host "  ✅ No issues found" -ForegroundColor Green
        }
    }

    # Export results
    $summary = @{
        TotalFiles     = @($filesToAnalyze).Count
        TotalIssues    = @($allResults).Count
        Errors         = @($allResults | Where-Object Severity -eq 'Error').Count
        Warnings       = @($allResults | Where-Object Severity -eq 'Warning').Count
        Information    = @($allResults | Where-Object Severity -eq 'Information').Count
        HasErrors      = $hasErrors
    }

    # Ensure logs directory exists
    $logsDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    }

    $allResults | ConvertTo-Json -Depth 5 | Out-File $OutputPath
    $summary | ConvertTo-Json | Out-File (Join-Path $logsDir "psscriptanalyzer-summary.json")

    # Set outputs
    Set-CIOutput -Name "issues" -Value $summary.TotalIssues
    Set-CIOutput -Name "errors" -Value $summary.Errors
    Set-CIOutput -Name "warnings" -Value $summary.Warnings

    if ($hasErrors) {
        Set-CIEnv -Name "PSSCRIPTANALYZER_FAILED" -Value "true"
    }

    # Write summary
    Write-CIStepSummary -Content "## PSScriptAnalyzer Results`n"

    if ($summary.TotalIssues -eq 0) {
        Write-CIStepSummary -Content "✅ **Status**: Passed`n`nAll $($summary.TotalFiles) PowerShell files passed linting checks."
        Write-Host "`n✅ All PowerShell files passed PSScriptAnalyzer checks!" -ForegroundColor Green
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
| Warnings | $($summary.Warnings) |
| Information | $($summary.Information) |
"@
    
        Write-Host "`n❌ PSScriptAnalyzer found $($summary.TotalIssues) issue(s)" -ForegroundColor Red
        throw "PSScriptAnalyzer found $($summary.TotalIssues) issue(s)"
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    # Strip /mnt/* paths from PATH to avoid slow 9P cross-filesystem
    # lookups in WSL. PSScriptAnalyzer resolves commands by scanning every
    # PATH directory per file; Windows mount points add ~40s per file.
    $env:PATH = ($env:PATH -split [System.IO.Path]::PathSeparator |
        Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator

    try {
        Invoke-PSScriptAnalyzerCore -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -ConfigPath $ConfigPath -OutputPath $OutputPath
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "PSScriptAnalyzer failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
