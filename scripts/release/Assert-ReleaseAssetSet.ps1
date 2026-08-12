#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies that a published release carries its exact expected asset set.
.DESCRIPTION
    Reconciles the actual asset names on an immutable published release against
    the identities the released marketplace catalog and channel package policy
    require. Plugin ZIP and VSIX identities both derive from that catalog, so no
    expected count is maintained by hand and no release asset defines the
    expectation it is verified against. The release's own
    plugin-release-evidence.json is still schema, version, and count validated,
    and its package set must match the catalog-derived set exactly.

    All identity comparison is ordinal and case sensitive. Missing, unexpected,
    duplicate, and sidecar-incomplete primary assets are all reported together
    and any finding is terminal. Verification is read-only: it never uploads,
    clobbers, or otherwise repairs published state.
.PARAMETER AssetNamePath
    File containing one actual release asset name per line.
.PARAMETER EvidencePath
    Path to the release's downloaded plugin-release-evidence.json, reconciled
    against the catalog-derived package set.
.PARAMETER RequiredAssetPath
    File containing one required singleton asset name per line.
.PARAMETER Channel
    Release channel whose package policy selects the expected VSIX identities.
.PARAMETER Version
    Released MAJOR.MINOR.PATCH version.
.PARAMETER ReleaseTag
    Released channel tag, used only in reporting.
.PARAMETER CatalogPath
    Marketplace catalog at the released ref.
.EXAMPLE
    ./Assert-ReleaseAssetSet.ps1 -AssetNamePath assets.txt -EvidencePath evidence.json `
        -RequiredAssetPath required.txt -CatalogPath .github/plugin/marketplace.json `
        -Channel PreRelease -Version 3.3.0 -ReleaseTag prerelease-v3.3.0
.NOTES
    Invoked by the published-release recovery path of release-prerelease.yml and
    release-stable-publish.yml.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AssetNamePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$EvidencePath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RequiredAssetPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../../.github/plugin/marketplace.json')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../extension/Modules/ExtensionIdentity.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

Set-Variable -Name ReleaseAssetSidecarSuffix -Value @('.spdx.json', '.sigstore.json', '.intoto.jsonl') -Option ReadOnly -Scope Script -Force

# Plugin packaging discovers its package set with the PreRelease eligibility
# policy on both release channels, so the plugin ZIP expectation follows that
# policy rather than the release channel.
Set-Variable -Name ReleasePluginPackagingChannel -Value 'PreRelease' -Option ReadOnly -Scope Script -Force

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
    return $sorted
}

function Get-ReleaseCatalogPackageName {
    <#
    .SYNOPSIS
        Resolves the package names a released catalog publishes for a channel.
    .PARAMETER Channel
        Release channel whose package policy applies.
    .PARAMETER CatalogPath
        Marketplace catalog at the released ref.
    .OUTPUTS
        [string[]] Ordinally sorted package names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogPath
    )

    # Dot-sourced inside this function so the discovery script's own parameters
    # stay contained instead of overwriting the caller's scope.
    . (Join-Path $PSScriptRoot '../extension/Get-MarketplacePackageMatrix.ps1') -Channel $Channel -CatalogPath $CatalogPath
    return Get-SortedReleaseAssetName -Name ([string[]]@((Get-MarketplacePackageMatrixCore -Channel $Channel -CatalogPath $CatalogPath).Names))
}

function Get-ReleaseExpectedPluginZipName {
    <#
    .SYNOPSIS
        Resolves the plugin ZIP identities a release must carry.
    .DESCRIPTION
        Membership comes from the released catalog under the plugin packaging
        policy, so a mutable release asset can never define the expectation it
        is checked against. The release's own evidence document is still schema,
        version, and count validated, and its package set must match that
        catalog-derived set exactly before verification continues.
    .PARAMETER Evidence
        Parsed plugin-release-evidence.json document.
    .PARAMETER Version
        Released version the evidence must record.
    .PARAMETER CatalogPath
        Marketplace catalog at the released ref.
    .OUTPUTS
        [string[]] Expected plugin ZIP asset names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Evidence,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogPath
    )

    foreach ($field in @('version', 'packageCount', 'packages')) {
        if (-not $Evidence.Contains($field)) {
            throw "plugin-release-evidence.json declares no '$field' field"
        }
    }
    if ([string]$Evidence['version'] -cne $Version) {
        throw "plugin-release-evidence.json records version $($Evidence['version']) but the release is $Version"
    }

    $declaredCount = [int]$Evidence['packageCount']
    $packages = @($Evidence['packages'])
    if ($declaredCount -lt 1) {
        throw "plugin-release-evidence.json declares packageCount $declaredCount"
    }
    if ($packages.Count -ne $declaredCount) {
        throw "plugin-release-evidence.json declares packageCount $declaredCount but carries $($packages.Count) package entries"
    }

    $names = [string[]]@($packages | ForEach-Object { [string]$_['name'] })
    if (@($names | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
        throw 'plugin-release-evidence.json carries a package entry without a name'
    }
    $evidenceName = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$names, [System.StringComparer]::Ordinal)
    if ($evidenceName.Count -ne $names.Count) {
        throw 'plugin-release-evidence.json carries duplicate package names'
    }

    # A self-consistent evidence document still proves nothing on its own: an
    # incomplete or tampered package list must disagree with the catalog the
    # release was built from.
    $catalogName = [string[]]@(Get-ReleaseCatalogPackageName -Channel $script:ReleasePluginPackagingChannel -CatalogPath $CatalogPath)
    $catalogLookup = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$catalogName, [System.StringComparer]::Ordinal)
    $omitted = [string[]]@($catalogName | Where-Object { -not $evidenceName.Contains($_) })
    if ($omitted.Count -gt 0) {
        throw "plugin-release-evidence.json omits released catalog package(s): $($omitted -join ', ')"
    }
    $foreign = Get-SortedReleaseAssetName -Name ([string[]]@($names | Where-Object { -not $catalogLookup.Contains($_) }))
    if ($foreign.Count -gt 0) {
        throw "plugin-release-evidence.json records package(s) the released catalog does not publish: $($foreign -join ', ')"
    }

    return [string[]]@($catalogName | ForEach-Object { $_ + '.zip' })
}

function Get-ReleaseExpectedVsixName {
    <#
    .SYNOPSIS
        Resolves the VSIX identities a release must carry.
    .DESCRIPTION
        Membership comes from the shared package-discovery source at the released
        ref, and each package name resolves through the shared extension identity
        map, so the expected set follows current channel policy rather than a
        hand-maintained count.
    .PARAMETER Channel
        Release channel whose package policy applies.
    .PARAMETER Version
        Released version each VSIX filename carries.
    .PARAMETER CatalogPath
        Marketplace catalog at the released ref.
    .OUTPUTS
        [string[]] Expected VSIX asset names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogPath
    )

    $packageName = [string[]]@(Get-ReleaseCatalogPackageName -Channel $Channel -CatalogPath $CatalogPath)

    return Get-SortedReleaseAssetName -Name ([string[]]@($packageName | ForEach-Object {
                (Get-ExtensionIdentity -PackageId $_) + "-$Version.vsix"
            }))
}

#endregion Expected identities

#region Reconciliation

function Test-ReleaseAssetSet {
    <#
    .SYNOPSIS
        Reconciles actual release assets against their expected identities.
    .DESCRIPTION
        Reports every missing, unexpected, duplicate, and sidecar-incomplete
        asset rather than stopping at the first one, so a partial release is
        described exactly once per finding. Every comparison is ordinal and case
        sensitive, so two names differing only by case are two distinct assets.
    .PARAMETER AssetName
        Actual release asset names.
    .PARAMETER ExpectedPluginZip
        Expected plugin ZIP asset names.
    .PARAMETER ExpectedVsix
        Expected VSIX asset names.
    .PARAMETER RequiredAsset
        Required singleton asset names.
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
        [string[]]$ExpectedPluginZip,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ExpectedVsix,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$RequiredAsset
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
            Kind     = 'plugin ZIP'
            Expected = [string[]]@($ExpectedPluginZip)
            Actual   = Get-SortedReleaseAssetName -Name ([string[]]@($present | Where-Object { $_.EndsWith('.zip', [System.StringComparison]::Ordinal) }))
        }
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
        Fails unless a published release carries its exact expected asset set.
    .PARAMETER AssetNamePath
        File containing one actual release asset name per line.
    .PARAMETER EvidencePath
        Path to the release's plugin-release-evidence.json.
    .PARAMETER RequiredAssetPath
        File containing one required singleton asset name per line.
    .PARAMETER Channel
        Release channel whose package policy applies.
    .PARAMETER Version
        Released MAJOR.MINOR.PATCH version.
    .PARAMETER ReleaseTag
        Released channel tag, used only in reporting.
    .PARAMETER CatalogPath
        Marketplace catalog at the released ref.
    .OUTPUTS
        [pscustomobject] The verified plugin ZIP and VSIX identities.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AssetNamePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$EvidencePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RequiredAssetPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ReleaseTag,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogPath
    )

    $assetName = Get-ReleaseAssetNameFromFile -Path $AssetNamePath
    if ($assetName.Count -eq 0) {
        throw "published $ReleaseTag carries no release assets"
    }
    $requiredAsset = Get-ReleaseAssetNameFromFile -Path $RequiredAssetPath
    if ($requiredAsset.Count -eq 0) {
        throw "No required singleton assets were supplied for published $ReleaseTag"
    }

    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        throw "published $ReleaseTag carries no readable plugin-release-evidence.json"
    }
    $evidence = Get-Content -LiteralPath $EvidencePath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($evidence -isnot [System.Collections.IDictionary]) {
        throw "published $ReleaseTag carries an unreadable plugin-release-evidence.json document"
    }

    $expectedPluginZip = Get-ReleaseExpectedPluginZipName -Evidence $evidence -Version $Version -CatalogPath $CatalogPath
    $expectedVsix = Get-ReleaseExpectedVsixName -Channel $Channel -Version $Version -CatalogPath $CatalogPath

    $findings = Test-ReleaseAssetSet -AssetName $assetName `
        -ExpectedPluginZip $expectedPluginZip `
        -ExpectedVsix $expectedVsix `
        -RequiredAsset $requiredAsset

    if ($findings.Count -gt 0) {
        foreach ($finding in $findings) {
            Write-CIAnnotation -Message "published ${ReleaseTag}: $finding" -Level Error
        }
        throw "published $ReleaseTag has incomplete release assets: $($findings.Count) findings; reconcile it before rerunning"
    }

    Write-Host "Verified $($expectedVsix.Count) VSIX and $($expectedPluginZip.Count) plugin ZIP assets with complete sidecars on published $ReleaseTag"
    return [pscustomobject]@{
        ReleaseTag = $ReleaseTag
        Channel    = $Channel
        Version    = $Version
        PluginZip  = $expectedPluginZip
        Vsix       = $expectedVsix
    }
}

#endregion Reconciliation

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        [void](Assert-ReleaseAssetSet -AssetNamePath $AssetNamePath `
                -EvidencePath $EvidencePath `
                -RequiredAssetPath $RequiredAssetPath `
                -Channel $Channel `
                -Version $Version `
                -ReleaseTag $ReleaseTag `
                -CatalogPath $CatalogPath)
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Assert-ReleaseAssetSet failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
