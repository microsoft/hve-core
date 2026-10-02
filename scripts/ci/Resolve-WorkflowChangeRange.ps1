#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Resolves an immutable workflow change range or selects full validation.
.DESCRIPTION
    Verifies explicit base and head commit IDs, confirms the checked-out HEAD
    matches the requested head, and proves the range can be diffed. Any missing,
    malformed, unavailable, mismatched, or non-diffable input returns full mode.
.PARAMETER BaseSha
    Candidate immutable base commit ID supplied by the calling workflow.
.PARAMETER HeadSha
    Candidate immutable head commit ID supplied by the calling workflow.
.PARAMETER RepoRoot
    Repository directory containing the checked-out head commit.
.EXAMPLE
    ./scripts/ci/Resolve-WorkflowChangeRange.ps1 -BaseSha $BaseSha -HeadSha $HeadSha
.NOTES
    Writes mode, base-sha, and head-sha as GitHub Actions step outputs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$BaseSha = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$HeadSha = '',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Join-Path $PSScriptRoot '../..')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function New-FullValidationResult {
    <#
    .SYNOPSIS
        Creates the fail-safe full-validation result.
    .OUTPUTS
        [pscustomobject] with empty immutable range values.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    return [pscustomobject][ordered]@{
        mode       = 'full'
        'base-sha' = ''
        'head-sha' = ''
    }
}

function Resolve-GitCommit {
    <#
    .SYNOPSIS
        Resolves an immutable candidate commit ID.
    .PARAMETER RepoRoot
        Repository directory containing the commit.
    .PARAMETER Candidate
        Candidate hexadecimal Git object ID.
    .OUTPUTS
        [string] containing the canonical commit ID, or no output when invalid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Candidate
    )

    if ($Candidate -notmatch '^[0-9a-fA-F]{40,64}$') {
        return
    }

    $ResolvedCommit = & git -C $RepoRoot rev-parse --verify --end-of-options "$Candidate`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ResolvedCommit)) {
        return
    }

    return $ResolvedCommit.Trim()
}

function Test-WorkflowGitDiff {
    <#
    .SYNOPSIS
        Tests whether Git can compute the requested immutable range.
    .PARAMETER RepoRoot
        Repository directory containing the commits.
    .PARAMETER BaseSha
        Canonical base commit ID.
    .PARAMETER HeadSha
        Canonical head commit ID.
    .OUTPUTS
        [bool] indicating whether Git accepted the range.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseSha,

        [Parameter(Mandatory = $true)]
        [string]$HeadSha
    )

    & git -C $RepoRoot diff --name-only "$BaseSha..$HeadSha" -- *> $null
    return $LASTEXITCODE -eq 0
}

function Resolve-WorkflowChangeRange {
    <#
    .SYNOPSIS
        Resolves a verified immutable range or selects full validation.
    .PARAMETER BaseSha
        Candidate immutable base commit ID.
    .PARAMETER HeadSha
        Candidate immutable head commit ID.
    .PARAMETER RepoRoot
        Repository directory containing the checked-out head commit.
    .OUTPUTS
        [pscustomobject] with mode, base-sha, and head-sha properties.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$BaseSha,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$HeadSha,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $ResolvedBase = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate $BaseSha
    $ResolvedHead = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate $HeadSha
    $CheckedOutHead = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate (& git -C $RepoRoot rev-parse HEAD 2>$null)

    if (
        [string]::IsNullOrWhiteSpace($ResolvedBase) -or
        [string]::IsNullOrWhiteSpace($ResolvedHead) -or
        [string]::IsNullOrWhiteSpace($CheckedOutHead) -or
        $CheckedOutHead -ne $ResolvedHead -or
        -not (Test-WorkflowGitDiff -RepoRoot $RepoRoot -BaseSha $ResolvedBase -HeadSha $ResolvedHead)
    ) {
        return New-FullValidationResult
    }

    return [pscustomobject][ordered]@{
        mode       = 'range'
        'base-sha' = $ResolvedBase
        'head-sha' = $ResolvedHead
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    $Result = Resolve-WorkflowChangeRange -BaseSha $BaseSha -HeadSha $HeadSha -RepoRoot $RepoRoot

    Set-CIOutput -Name 'mode' -Value $Result.mode
    Set-CIOutput -Name 'base-sha' -Value $Result.'base-sha'
    Set-CIOutput -Name 'head-sha' -Value $Result.'head-sha'

    Write-Host "Workflow change-range mode: $($Result.mode)"
}

#endregion Main Execution
