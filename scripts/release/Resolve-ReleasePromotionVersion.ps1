#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Resolves an exact version for a release branch promotion.
.DESCRIPTION
    Applies two deterministic next-minor rules. A PreRelease promotion reads only
    the current PreRelease version and advances to the next odd minor with patch
    zero. A Stable promotion derives the next even minor from the promoted
    PreRelease version with patch zero, and uses the current Stable version only
    to reject a candidate that does not advance the Stable line.
.PARAMETER Channel
    Channel receiving the promotion.
.PARAMETER CurrentPreReleaseVersion
    Current numeric PreRelease version. Required for PreRelease.
.PARAMETER PromotedSourceVersion
    Numeric version associated with the promoted source. Required for Stable.
.PARAMETER CurrentStableVersion
    Current numeric Stable version. Required for Stable and used only as an
    advancement guard.
.PARAMETER AsJson
    Emit a compressed JSON object instead of a PowerShell object.
.EXAMPLE
    ./Resolve-ReleasePromotionVersion.ps1 -Channel PreRelease `
        -CurrentPreReleaseVersion 3.3.101
.EXAMPLE
    ./Resolve-ReleasePromotionVersion.ps1 -Channel Stable `
        -PromotedSourceVersion 3.5.0 -CurrentStableVersion 3.2.2 -AsJson
.NOTES
    This script performs no repository or network access. Promotion workflows
    supply the current branch state.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PreRelease', 'Stable')]
    [string]$Channel,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$CurrentPreReleaseVersion,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$PromotedSourceVersion,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$CurrentStableVersion,

    [Parameter(Mandatory = $false)]
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'

#region Functions

function Resolve-ReleasePromotionVersion {
    <#
    .SYNOPSIS
        Resolves and validates the next channel version.
    .PARAMETER Channel
        Channel receiving the promotion.
    .PARAMETER CurrentPreReleaseVersion
        Current PreRelease version. Required for PreRelease.
    .PARAMETER PromotedSourceVersion
        Version associated with the promoted source. Required for Stable.
    .PARAMETER CurrentStableVersion
        Current Stable version. Required for Stable and used only as an
        advancement guard.
    .OUTPUTS
        [pscustomobject] The resolved version and its channel inputs.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [version]$CurrentPreReleaseVersion,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [version]$PromotedSourceVersion,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [version]$CurrentStableVersion
    )

    $preReleaseInput = $null
    $promotedInput = $null
    $stableInput = $null

    if ($Channel -eq 'PreRelease') {
        if ($null -eq $CurrentPreReleaseVersion) {
            throw 'CurrentPreReleaseVersion is required for PreRelease resolution'
        }
        if ($CurrentPreReleaseVersion.Minor % 2 -eq 0) {
            throw "PreRelease baseline must have an odd minor: $CurrentPreReleaseVersion"
        }

        $candidate = [version]::new(
            $CurrentPreReleaseVersion.Major,
            $CurrentPreReleaseVersion.Minor + 2,
            0
        )

        $preReleaseInput = $CurrentPreReleaseVersion.ToString(3)
    }
    else {
        if ($null -eq $PromotedSourceVersion) {
            throw 'PromotedSourceVersion is required for Stable resolution'
        }
        if ($null -eq $CurrentStableVersion) {
            throw 'CurrentStableVersion is required for Stable resolution'
        }
        if ($PromotedSourceVersion.Minor % 2 -eq 0) {
            throw "Stable promotion source must have an odd minor: $PromotedSourceVersion"
        }
        if ($CurrentStableVersion.Minor % 2 -ne 0) {
            throw "Stable baseline must have an even minor: $CurrentStableVersion"
        }

        $candidate = [version]::new(
            $PromotedSourceVersion.Major,
            $PromotedSourceVersion.Minor + 1,
            0
        )

        if ($candidate -le $CurrentStableVersion) {
            throw "Resolved Stable version must be greater than the Stable baseline: $candidate"
        }

        $promotedInput = $PromotedSourceVersion.ToString(3)
        $stableInput = $CurrentStableVersion.ToString(3)
    }

    return [pscustomobject]@{
        Version                  = $candidate.ToString(3)
        Channel                  = $Channel
        CurrentPreReleaseVersion = $preReleaseInput
        PromotedSourceVersion    = $promotedInput
        CurrentStableVersion     = $stableInput
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    $result = Resolve-ReleasePromotionVersion `
        -Channel $Channel `
        -CurrentPreReleaseVersion $(
            if ([string]::IsNullOrWhiteSpace($CurrentPreReleaseVersion)) { $null }
            else { [version]$CurrentPreReleaseVersion }
        ) `
        -PromotedSourceVersion $(
            if ([string]::IsNullOrWhiteSpace($PromotedSourceVersion)) { $null }
            else { [version]$PromotedSourceVersion }
        ) `
        -CurrentStableVersion $(
            if ([string]::IsNullOrWhiteSpace($CurrentStableVersion)) { $null }
            else { [version]$CurrentStableVersion }
        )

    if ($AsJson) {
        $result | ConvertTo-Json -Compress
    }
    else {
        $result
    }
}

#endregion Main Execution
