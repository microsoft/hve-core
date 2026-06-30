#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates devcontainer lockfile integrity and feature coverage.

.DESCRIPTION
    Checks that devcontainer-lock.json exists, all features have SHA-256 integrity
    hashes and resolved references, and that every feature declared in devcontainer.json
    is present in the lockfile. Outputs results as JSON and emits CI annotations for
    any violations found.

.PARAMETER RepoRoot
    Root directory of the repository. Defaults to the git working tree root or the
    script directory when not inside a git repository.

.PARAMETER OutputPath
    Path where validation results JSON should be saved. Defaults to
    'logs/devcontainer-lockfile-results.json'.

.PARAMETER FailOnViolation
    Exit with code 1 when any validation check fails.

.EXAMPLE
    ./Test-DevcontainerLockfile.ps1
    Validate lockfile in the current repository with default settings.

.EXAMPLE
    ./Test-DevcontainerLockfile.ps1 -FailOnViolation
    Validate lockfile and exit with error code on failures.

.NOTES
    Runs via: npm run validate:devcontainer-lockfile
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/devcontainer-lockfile-results.json',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnViolation
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = $PSScriptRoot }

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Test-LockfileExists {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $lockfilePath = Join-Path $RepoRoot '.devcontainer/devcontainer-lock.json'
    if (Test-Path $lockfilePath) {
        return @{
            Passed  = $true
            Message = "Lockfile exists at $lockfilePath"
        }
    }

    return @{
        Passed  = $false
        Message = "Lockfile not found at $lockfilePath"
    }
}

function Test-FeatureIntegrity {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockfilePath
    )

    $lockData = Get-Content -Path $LockfilePath -Raw | ConvertFrom-Json
    $violations = @()

    foreach ($feature in $lockData.features.PSObject.Properties) {
        $name = $feature.Name
        $value = $feature.Value

        if (-not $value.resolved) {
            $violations += "Feature '$name' is missing a resolved reference"
        }
        if (-not $value.integrity) {
            $violations += "Feature '$name' is missing an integrity hash"
        }
        elseif (-not $value.integrity.StartsWith('sha256:')) {
            $violations += "Feature '$name' has non-SHA-256 integrity: $($value.integrity)"
        }
    }

    return @{
        Passed     = ($violations.Count -eq 0)
        Violations = $violations
    }
}

function Test-FeatureCoverage {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockfilePath,

        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    $lockData = Get-Content -Path $LockfilePath -Raw | ConvertFrom-Json
    $configData = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json

    $lockKeys = @($lockData.features.PSObject.Properties |
        ForEach-Object { $_.Name.ToLowerInvariant() })
    $configKeys = @($configData.features.PSObject.Properties |
        ForEach-Object { $_.Name.ToLowerInvariant() })

    $missingKeys = @($configKeys | Where-Object { $_ -notin $lockKeys })

    return @{
        Passed      = ($missingKeys.Count -eq 0)
        MissingKeys = $missingKeys
    }
}

function Invoke-LockfileValidation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $lockfilePath = Join-Path $RepoRoot '.devcontainer/devcontainer-lock.json'
    $configPath = Join-Path $RepoRoot '.devcontainer/devcontainer.json'

    $details = @()

    # Check 1: Lockfile exists
    $existsResult = Test-LockfileExists -RepoRoot $RepoRoot
    $details += @{
        CheckName = 'LockfileExists'
        Passed    = $existsResult.Passed
        Message   = $existsResult.Message
    }

    if (-not $existsResult.Passed) {
        Write-CIAnnotation -Level Error -Message $existsResult.Message
        return @{
            TotalChecks  = 1
            PassedChecks = 0
            FailedChecks = 1
            Details      = $details
        }
    }

    # Check 2: Feature integrity
    $integrityResult = Test-FeatureIntegrity -LockfilePath $lockfilePath
    $details += @{
        CheckName  = 'FeatureIntegrity'
        Passed     = $integrityResult.Passed
        Violations = $integrityResult.Violations
    }

    if (-not $integrityResult.Passed) {
        foreach ($violation in $integrityResult.Violations) {
            Write-CIAnnotation -Level Error -Message $violation
        }
    }

    # Check 3: Feature coverage
    $coverageResult = Test-FeatureCoverage -LockfilePath $lockfilePath -ConfigPath $configPath
    $details += @{
        CheckName   = 'FeatureCoverage'
        Passed      = $coverageResult.Passed
        MissingKeys = $coverageResult.MissingKeys
    }

    if (-not $coverageResult.Passed) {
        foreach ($key in $coverageResult.MissingKeys) {
            Write-CIAnnotation -Level Error -Message "Feature '$key' declared in devcontainer.json but missing from lockfile"
        }
    }

    $passedCount = ($details | Where-Object { $_.Passed }).Count
    $failedCount = ($details | Where-Object { -not $_.Passed }).Count

    return @{
        TotalChecks  = $details.Count
        PassedChecks = $passedCount
        FailedChecks = $failedCount
        Details      = $details
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent) | Out-Null
        $result = Invoke-LockfileValidation -RepoRoot $RepoRoot
        $result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding UTF8

        if ($result.FailedChecks -gt 0) {
            Write-CIAnnotation -Level Error -Message "Devcontainer lockfile integrity check failed with $($result.FailedChecks) error(s)"
            if ($FailOnViolation) {
                exit 1
            }
        }
        else {
            Write-Host "[PASS] Lockfile covers all features with SHA-256 integrity"
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Test-DevcontainerLockfile failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
