#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies that a release carries its exact expected asset set.
.DESCRIPTION
    Reconciles the actual asset names on a draft or immutable published release
    against the one hve-core VSIX identity the released version defines, its
    complete sidecar set, and the channel's required singleton assets. The VSIX
    identity is derived from the released version alone, so no release asset
    defines the expectation it is verified against.

    All identity comparison is ordinal and case sensitive. Missing, unexpected,
    duplicate, sidecar-incomplete, and otherwise unapproved assets are all
    reported together and any finding is terminal. Verification is read-only:
    it never uploads, clobbers, or otherwise repairs published state.
.PARAMETER AssetNamePath
    File containing one actual release asset name per line.
.PARAMETER RequiredAssetPath
    File containing one required singleton asset name per line.
.PARAMETER OptionalAssetPath
    Optional file containing singleton asset names that may be present.
.PARAMETER Version
    Released MAJOR.MINOR.PATCH version.
.PARAMETER ReleaseTag
    Released channel tag, used only in reporting.
.EXAMPLE
    ./Assert-ReleaseAssetSet.ps1 -AssetNamePath assets.txt `
        -RequiredAssetPath required.txt -Version 3.3.0 -ReleaseTag prerelease-v3.3.0
.NOTES
    This helper validates the current one-plugin release shape only. Historical
    release records are not replay inputs, and legacy asset shapes remain
    rejected.

    Invoked by the published-release verification path of
    release-vsix-publish.yml. A rerun of the immutable tag-push event verifies
    an already published release without rebuilding or replacing assets.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AssetNamePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredAssetPath,

    [Parameter(Mandatory = $false)]
    [string]$OptionalAssetPath = '',

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\z')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

Set-Variable -Name ReleaseAssetSidecarSuffix -Value @('.spdx.json', '.sigstore.json', '.intoto.jsonl') -Option ReadOnly -Scope Script -Force

# The repository publishes one extension identity, so the released version is
# the only variable in its asset name.
Set-Variable -Name ReleaseExtensionName -Value 'hve-core' -Option ReadOnly -Scope Script -Force

#region Expected identities

function Get-SortedReleaseAssetName {
    <#
    .SYNOPSIS
        Sorts asset names under the one ordinal identity regime.
    .PARAMETER Name
        Asset names to sort.
    .OUTPUTS
        [string[]] Ordinally sorted names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Name
    )

    $sorted = [string[]]@($Name)
    [array]::Sort($sorted, [System.StringComparer]::Ordinal)
    # Comma-wrapped so an empty result stays an empty array instead of
    # unrolling to null for the caller.
    return , $sorted
}

function Get-ReleaseExpectedVsixName {
    <#
    .SYNOPSIS
        Resolves the VSIX identity a release must carry.
    .PARAMETER Version
        Released version the VSIX filename carries.
    .OUTPUTS
        [string[]] Expected VSIX asset names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    return [string[]]@("$script:ReleaseExtensionName-$Version.vsix")
}

#endregion Expected identities

#region Reconciliation

function Test-ReleaseAssetSet {
    <#
    .SYNOPSIS
        Reconciles actual release assets against their expected identities.
    .DESCRIPTION
        Reports every missing, unexpected, duplicate, sidecar-incomplete, and
        otherwise unapproved asset rather than stopping at the first one, so a
        partial release is described exactly once per finding. Every comparison
        is ordinal and case sensitive, so two names differing only by case are
        two distinct assets.
    .PARAMETER AssetName
        Actual release asset names.
    .PARAMETER ExpectedVsix
        Expected VSIX asset names.
    .PARAMETER RequiredAsset
        Required singleton asset names.
    .PARAMETER OptionalAsset
        Singleton asset names that are allowed but not required.
    .OUTPUTS
        [string[]] Findings, empty when the asset set is complete.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$AssetName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ExpectedVsix,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$RequiredAsset,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$OptionalAsset = @()
    )

    $findings = [System.Collections.Generic.List[string]]::new()

    $occurrence = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    foreach ($name in $AssetName) {
        $seen = 0
        [void]$occurrence.TryGetValue($name, [ref]$seen)
        $occurrence[$name] = $seen + 1
    }
    foreach ($name in (Get-SortedReleaseAssetName -Name ([string[]]@($occurrence.Keys)))) {
        if ($occurrence[$name] -gt 1) {
            $findings.Add("duplicate asset '$name' appears $($occurrence[$name]) times")
        }
    }

    $present = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$AssetName, [System.StringComparer]::Ordinal)

    foreach ($required in $RequiredAsset) {
        if (-not $present.Contains($required)) {
            $findings.Add("missing required asset '$required'")
        }
    }

    $primaryKinds = @(
        @{
            Kind     = 'VSIX'
            Expected = [string[]]@($ExpectedVsix)
            Actual   = Get-SortedReleaseAssetName -Name ([string[]]@($present | Where-Object { $_.EndsWith('.vsix', [System.StringComparison]::Ordinal) }))
        }
    )

    foreach ($kind in $primaryKinds) {
        $expectedLookup = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]$kind.Expected, [System.StringComparer]::Ordinal)
        $actualLookup = [System.Collections.Generic.HashSet[string]]::new(
            [string[]]$kind.Actual, [System.StringComparer]::Ordinal)

        foreach ($missing in @($kind.Expected | Where-Object { -not $actualLookup.Contains($_) })) {
            $findings.Add("missing $($kind.Kind) asset '$missing'")
        }
        foreach ($unexpected in @($kind.Actual | Where-Object { -not $expectedLookup.Contains($_) })) {
            $findings.Add("unexpected $($kind.Kind) asset '$unexpected'")
        }
        # Sidecars are proved only for primaries that are actually present; a
        # missing primary is already reported once and needs no echo per sidecar.
        foreach ($primary in $kind.Actual) {
            foreach ($suffix in $script:ReleaseAssetSidecarSuffix) {
                $sidecar = $primary + $suffix
                if (-not $present.Contains($sidecar)) {
                    $findings.Add("missing sidecar '$sidecar' for $($kind.Kind) asset '$primary'")
                }
            }
        }
    }

    $allowed = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@($RequiredAsset + $OptionalAsset), [System.StringComparer]::Ordinal)
    foreach ($kind in $primaryKinds) {
        foreach ($primary in ([string[]]@($kind.Expected) + [string[]]@($kind.Actual))) {
            [void]$allowed.Add($primary)
            foreach ($suffix in $script:ReleaseAssetSidecarSuffix) {
                [void]$allowed.Add($primary + $suffix)
            }
        }
    }
    foreach ($extra in (Get-SortedReleaseAssetName -Name ([string[]]@($present | Where-Object { -not $allowed.Contains($_) })))) {
        $findings.Add("unexpected asset '$extra'")
    }

    return [string[]]@($findings)
}

function Get-ReleaseAssetNameFromFile {
    <#
    .SYNOPSIS
        Reads a newline-delimited asset name list.
    .PARAMETER Path
        List file path.
    .OUTPUTS
        [string[]] Non-empty trimmed names in file order.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Asset list not found: $Path"
    }
    return [string[]]@(Get-Content -LiteralPath $Path -Encoding utf8 |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ })
}

function Assert-ReleaseAssetSet {
    <#
    .SYNOPSIS
        Fails unless a release carries its exact expected asset set.
    .PARAMETER AssetNamePath
        File containing one actual release asset name per line.
    .PARAMETER RequiredAssetPath
        File containing one required singleton asset name per line.
    .PARAMETER OptionalAssetPath
        Optional file containing singleton asset names that may be present.
    .PARAMETER Version
        Released MAJOR.MINOR.PATCH version.
    .PARAMETER ReleaseTag
        Released channel tag, used only in reporting.
    .OUTPUTS
        [pscustomobject] The verified VSIX identity.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AssetNamePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredAssetPath,

        [Parameter(Mandatory = $false)]
        [string]$OptionalAssetPath = '',

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseTag
    )

    $assetName = Get-ReleaseAssetNameFromFile -Path $AssetNamePath
    if ($assetName.Count -eq 0) {
        throw "$ReleaseTag release carries no release assets"
    }
    $requiredAsset = Get-ReleaseAssetNameFromFile -Path $RequiredAssetPath
    if ($requiredAsset.Count -eq 0) {
        throw "No required singleton assets were supplied for $ReleaseTag release"
    }
    $optionalAsset = if ($OptionalAssetPath) {
        Get-ReleaseAssetNameFromFile -Path $OptionalAssetPath
    }
    else {
        [string[]]@()
    }

    $expectedVsix = Get-ReleaseExpectedVsixName -Version $Version

    $findings = Test-ReleaseAssetSet -AssetName $assetName `
        -ExpectedVsix $expectedVsix `
        -RequiredAsset $requiredAsset `
        -OptionalAsset $optionalAsset

    if ($findings.Count -gt 0) {
        foreach ($finding in $findings) {
            Write-CIAnnotation -Message "${ReleaseTag} release: $finding" -Level Error
        }
        throw "$ReleaseTag release has incomplete release assets: $($findings.Count) findings; reconcile it before rerunning"
    }

    Write-Host "Verified $($expectedVsix.Count) VSIX, $($requiredAsset.Count) required singleton assets, and $($optionalAsset.Count) optional singleton assets with complete sidecars on $ReleaseTag release"
    return [pscustomobject]@{
        ReleaseTag = $ReleaseTag
        Version    = $Version
        Vsix       = $expectedVsix
    }
}

#endregion Reconciliation

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        [void](Assert-ReleaseAssetSet -AssetNamePath $AssetNamePath `
                -RequiredAssetPath $RequiredAssetPath `
                -OptionalAssetPath $OptionalAssetPath `
                -Version $Version `
                -ReleaseTag $ReleaseTag)
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Assert-ReleaseAssetSet failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
