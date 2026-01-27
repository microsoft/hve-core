#!/usr/bin/env pwsh
#
# Invoke-PSScriptAnalyzer.ps1
#
# Purpose: Wrapper for PSScriptAnalyzer with GitHub Actions integration
# Author: HVE Core Team
# Created: 2025-11-05

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

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force

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
    $filesToAnalyze = Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.ps1', '*.psm1', '*.psd1')
}
else {
    Write-Host "Analyzing all PowerShell files..." -ForegroundColor Cyan
    $gitignorePath = Join-Path (git rev-parse --show-toplevel 2>$null) ".gitignore"
    $filesToAnalyze = Get-FilesRecursive -Path "." -Include @('*.ps1', '*.psm1', '*.psd1') -GitIgnorePath $gitignorePath
}

if ($filesToAnalyze.Count -eq 0) {
    Write-Host "✅ No PowerShell files to analyze" -ForegroundColor Green
    Set-GitHubOutput -Name "count" -Value "0"
    Set-GitHubOutput -Name "issues" -Value "0"
    exit 0
}

Write-Host "Analyzing $($filesToAnalyze.Count) PowerShell files..." -ForegroundColor Cyan
Set-GitHubOutput -Name "count" -Value $filesToAnalyze.Count

#region Main Execution
try {
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
                # Create GitHub annotation
                Write-GitHubAnnotation `
                    -Type $result.Severity.ToString().ToLower() `
                    -Message "$($result.RuleName): $($result.Message)" `
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
        TotalFiles     = $filesToAnalyze.Count
        TotalIssues    = $allResults.Count
        Errors         = ($allResults | Where-Object Severity -eq 'Error').Count
        Warnings       = ($allResults | Where-Object Severity -eq 'Warning').Count
        Information    = ($allResults | Where-Object Severity -eq 'Information').Count
        HasErrors      = $hasErrors
    }

    $allResults | ConvertTo-Json -Depth 5 | Out-File $OutputPath
    $summary | ConvertTo-Json | Out-File "logs/psscriptanalyzer-summary.json"

    # Set outputs
    Set-GitHubOutput -Name "issues" -Value $summary.TotalIssues
    Set-GitHubOutput -Name "errors" -Value $summary.Errors
    Set-GitHubOutput -Name "warnings" -Value $summary.Warnings

    if ($hasErrors) {
        Set-GitHubEnv -Name "PSSCRIPTANALYZER_FAILED" -Value "true"
    }

    # Write summary
    Write-GitHubStepSummary -Content "## PSScriptAnalyzer Results`n"

    if ($summary.TotalIssues -eq 0) {
        Write-GitHubStepSummary -Content "✅ **Status**: Passed`n`nAll $($summary.TotalFiles) PowerShell files passed linting checks."
        Write-Host "`n✅ All PowerShell files passed PSScriptAnalyzer checks!" -ForegroundColor Green
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
| Warnings | $($summary.Warnings) |
| Information | $($summary.Information) |
"@
    
        Write-Host "`n❌ PSScriptAnalyzer found $($summary.TotalIssues) issue(s)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Error "PSScriptAnalyzer failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}
#endregion