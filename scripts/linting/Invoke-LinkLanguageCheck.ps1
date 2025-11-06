#!/usr/bin/env pwsh
#
# Invoke-LinkLanguageCheck.ps1
#
# Purpose: Wrapper for Link-Lang-Check.ps1 with GitHub Actions integration
# Author: HVE Core Team
# Created: 2025-11-05

[CmdletBinding()]
param()

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force

Write-Host "🔍 Checking for URLs with language paths..." -ForegroundColor Cyan

# Run the language check script
$jsonOutput = & (Join-Path $PSScriptRoot "Link-Lang-Check.ps1") 2>&1

try {
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
        $results | ConvertTo-Json -Depth 3 | Out-File 'logs/link-lang-check-results.json'
        
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
        @() | ConvertTo-Json | Out-File 'logs/link-lang-check-results.json'
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
    Write-Error "Error parsing results: $_"
    Write-Host "Raw output: $jsonOutput"
    exit 1
}
