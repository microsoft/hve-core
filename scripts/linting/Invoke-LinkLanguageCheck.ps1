#!/usr/bin/env pwsh
#
# Invoke-LinkLanguageCheck.ps1
#
# Purpose: Wrapper for Link-Lang-Check.ps1 with GitHub Actions integration
# Author: HVE Core Team
# Created: 2025-11-05

[CmdletBinding()]
param(
    [string[]]$ExcludePaths = @()
)

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force

# Get repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not in a git repository"
    exit 1
}

# Create logs directory if it doesn't exist
$logsDir = Join-Path $repoRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

Write-Host "🔍 Checking for URLs with language paths..." -ForegroundColor Cyan

#region Main Execution

try {
    # Run the language check script
    $scriptArgs = @{}
    if ($ExcludePaths.Count -gt 0) {
        $scriptArgs['ExcludePaths'] = $ExcludePaths
    }
    $jsonOutput = & (Join-Path $PSScriptRoot "Link-Lang-Check.ps1") @scriptArgs 2>&1

    $results = $jsonOutput | ConvertFrom-Json
    
    if ($results -and $results.Count -gt 0) {
        Write-Host "Found $($results.Count) URLs with 'en-us' language paths`n" -ForegroundColor Yellow
        
        # Create annotations
        foreach ($item in $results) {
            Write-GitHubAnnotation `
                -Type 'warning' `
                -Message "URL contains language path: $($item.original_url)" `
                -File $item.file `
                -Line $item.line_number
        }
        
        # Save results
        $outputData = @{
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
            script = "link-lang-check"
            summary = @{
                total_issues = $results.Count
                files_affected = ($results | Select-Object -ExpandProperty file -Unique).Count
            }
            issues = $results
        }
        $outputData | ConvertTo-Json -Depth 3 | Out-File (Join-Path $logsDir "link-lang-check-results.json") -Encoding utf8
        
        Set-GitHubOutput -Name "issues" -Value $results.Count
        Set-GitHubEnv -Name "LINK_LANG_FAILED" -Value "true"
        
        # Write summary
        $uniqueFiles = $results | Select-Object -ExpandProperty file -Unique
        
        Write-GitHubStepSummary -Content @"
## Link Language Path Check Results

⚠️ **Status**: Issues Found

Found $($results.Count) URL(s) containing language path 'en-us'.

**Why this matters:**
Language-specific URLs don't adapt to user preferences and may break for non-English users.

**To fix locally:**
``````powershell
scripts/linting/Link-Lang-Check.ps1 -Fix
``````

**Files affected:**
$(($uniqueFiles | ForEach-Object { $count = ($results | Where-Object file -eq $_).Count; "- $_ ($count occurrence(s))" }) -join "`n")
"@
    
        exit 1
    }
    else {
        Write-Host "✅ No URLs with language paths found" -ForegroundColor Green
        
        # Save empty results
        $emptyResults = @{
            timestamp = (Get-Date).ToUniversalTime().ToString("o")
            script = "link-lang-check"
            summary = @{
                total_issues = 0
                files_affected = 0
            }
            issues = @()
        }
        $emptyResults | ConvertTo-Json -Depth 3 | Out-File (Join-Path $logsDir "link-lang-check-results.json") -Encoding utf8
        
        Set-GitHubOutput -Name "issues" -Value "0"
        
        Write-GitHubStepSummary -Content @"
## Link Language Path Check Results

✅ **Status**: Passed

No URLs with language-specific paths detected.
"@
    
        exit 0
    }
}
catch {
    Write-Error "Link-language check failed: $($_.Exception.Message)"
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Output "::error::$($_.Exception.Message)"
    }
    exit 1
}

#endregion