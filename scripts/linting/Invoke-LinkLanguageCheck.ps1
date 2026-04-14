#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Checks for URLs with language paths and outputs results to JSON.
.DESCRIPTION
    Wrapper for Link-Lang-Check.ps1 with GitHub Actions integration.
    Validates URLs and writes results to a specified output path.
.PARAMETER ExcludePaths
    Array of paths to exclude from the check.
.PARAMETER OutputPath
    Path where the JSON result file will be written. 
    Defaults to "logs/link-lang-check-results.json".
.EXAMPLE
    Invoke-LinkLanguageCheck.ps1
.EXAMPLE
    Invoke-LinkLanguageCheck.ps1 -OutputPath "custom/results.json"
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string[]]$ExcludePaths = @(),
    [string]$OutputPath = "logs/link-lang-check-results.json"
)

$ErrorActionPreference = 'Stop'

# Import shared helpers
Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

function Invoke-LinkLanguageCheckCore {
    [CmdletBinding()]
    param(
        [string[]]$ExcludePaths = @(),
        [string]$OutputPath   # no default; outer script always supplies the value
    )

    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not in a git repository"
        return 1
    }

    
    if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath = Join-Path $repoRoot $OutputPath
    }

    Write-Host "🔍 Checking for URLs with language paths..." -ForegroundColor Cyan

    try {
        $scriptArgs = @{}
        if ($ExcludePaths.Count -gt 0) {
            $scriptArgs['ExcludePaths'] = $ExcludePaths
        }
        $jsonOutput = & (Join-Path $PSScriptRoot "Link-Lang-Check.ps1") @scriptArgs 2>&1

        $results = $jsonOutput | ConvertFrom-Json

        if ($results -and $results.Count -gt 0) {
            Write-Host "Found $($results.Count) URLs with 'en-us' language paths`n" -ForegroundColor Yellow

            $fileGroups = $results | Group-Object -Property file
            $uniqueFiles = $fileGroups | ForEach-Object { $_.Name }

            foreach ($fileGroup in $fileGroups) {
                Write-Host "📄 $($fileGroup.Name)" -ForegroundColor Cyan
                foreach ($item in $fileGroup.Group) {
                    Write-Host "  ⚠️ Line $($item.line_number): $($item.original_url)" -ForegroundColor Yellow
                }
            }

            foreach ($item in $results) {
                Write-CIAnnotation `
                    -Message "URL contains language path: $($item.original_url)" `
                    -Level Warning `
                    -File $item.file `
                    -Line $item.line_number
            }

            $outputData = @{
                Timestamp = Get-StandardTimestamp
                script = "link-lang-check"
                summary = @{
                    total_issues = $results.Count
                    files_affected = $uniqueFiles.Count
                }
                issues = $results
            }

            # Ensure output directory exists
            $outputDir = Split-Path -Parent $OutputPath
            if ($outputDir -and -not (Test-Path $outputDir)) {
                New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
            }

            # Write JSON to file
            $outputData | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding utf8

            Set-CIOutput -Name "issues" -Value $results.Count
            Set-CIEnv -Name "LINK_LANG_FAILED" -Value "true"

            Write-CIStepSummary -Content @"
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
$(($uniqueFiles | ForEach-Object { 
    $count = ($results | Where-Object file -eq $_).Count
    $safePath = if ((Get-CIPlatform) -eq 'azdo') {
        ConvertTo-AzureDevOpsEscaped -Value $_
    } else { $_ }
    "- $safePath ($count occurrence(s))"
}) -join "`n")
"@

            Write-Host "❌ Link language check failed with $($results.Count) issue(s) in $($uniqueFiles.Count) file(s)." -ForegroundColor Red

            return 1
        }

        Write-Host "✅ No URLs with language paths found" -ForegroundColor Green

        $emptyResults = @{
            Timestamp = Get-StandardTimestamp
            script = "link-lang-check"
            summary = @{
                total_issues = 0
                files_affected = 0
            }
            issues = @()
        }

        # Ensure output directory exists
        $outputDir = Split-Path -Parent $OutputPath
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Write JSON to file
        $emptyResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath -Encoding utf8
        Set-CIOutput -Name "issues" -Value "0"

        Write-CIStepSummary -Content @"
## Link Language Path Check Results

✅ **Status**: Passed

No URLs with language-specific paths detected.
"@

        return 0
    }
    catch {
        Write-Error -ErrorAction Continue "Link-language check failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message "Link-language check failed: $($_.Exception.Message)" -Level Error
        return 1
    }
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-LinkLanguageCheckCore -ExcludePaths $ExcludePaths -OutputPath $OutputPath
        exit $exitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-LinkLanguageCheck failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution

