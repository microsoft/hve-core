#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Records and verifies deterministic evidence for a plugin release.

.DESCRIPTION
    Binds four values into one invariant: the immutable source commit, the
    package version, the release locator, and a digest computed over the package
    content. The digest covers repository-relative paths and file content only,
    so it is reproducible from a clean checkout of the same source commit.

    Evidence digests each package's declared canonical git-tracked source set
    resolved from the marketplace catalog, so it needs no generated tree and no
    staging root, and its locator addresses the exact channel release tag,
    'prerelease-v<version>' or 'v<version>', without a package path.

    Default mode records evidence. Supplying -ExpectedEvidencePath verifies a
    previously recorded document against freshly computed values and fails when
    the source commit, version, locator, package set, or digest disagree.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to the enclosing repository.

.PARAMETER CatalogPath
    Marketplace catalog declaring package membership, absolute or relative to
    RepoRoot.

.PARAMETER Channel
    Release channel whose eligibility policy selects packages and whose tag
    namespace the release locator addresses.

.PARAMETER SourceCommit
    Full 40-character commit id the evidence was computed from. Resolved from
    git when omitted.

.PARAMETER Version
    Package version. Read from package.json when omitted.

.PARAMETER ReleaseTag
    Immutable channel release tag. Derived from Channel and Version when
    omitted.

.PARAMETER OutputPath
    Destination for the evidence document, absolute or relative to RepoRoot.

.PARAMETER ExpectedEvidencePath
    Previously recorded evidence document to verify against.

.PARAMETER ExpectedPackageCount
    Cutover precondition. When greater than zero, the evidence must cover
    exactly this many packages.

.EXAMPLE
    ./Assert-PluginReleaseEvidence.ps1 -OutputPath logs/plugin-release-evidence.json

.EXAMPLE
    ./Assert-PluginReleaseEvidence.ps1 -ExpectedEvidencePath logs/plugin-release-evidence.json

.NOTES
    Runs via: npm run plugin:evidence
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = '.github/plugin/marketplace.json',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'PreRelease',

    [Parameter(Mandatory = $false)]
    [string]$SourceCommit,

    [Parameter(Mandatory = $false)]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$ReleaseTag,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/plugin-release-evidence.json',

    [Parameter(Mandatory = $false)]
    [string]$ExpectedEvidencePath,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 1000)]
    [int]$ExpectedPackageCount = 0
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/MarketplaceHelpers.psm1') -Force

Set-Variable -Name PluginCanonicalEvidenceSchema -Value 'hve-core/plugin-release-evidence/v2' -Option Constant -Scope Script -Force

#region Digest

function Get-PluginPathSetDigest {
    <#
    .SYNOPSIS
        Computes a deterministic digest over an explicit set of tracked files.

    .DESCRIPTION
        Hashes an ordinal-sorted manifest of repository-relative forward-slash
        paths paired with the SHA-256 of each file's bytes. Enumeration order,
        timestamps, permissions, and sizes are excluded, so the digest reproduces
        across machines and clean checkouts.

    .PARAMETER RepoRoot
        Absolute path to the repository working tree.

    .PARAMETER RelativePath
        Repository-relative forward-slash paths to digest.

    .OUTPUTS
        [hashtable] Report with Digest, FileCount, and TotalBytes keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$RelativePath
    )

    $entries = [System.Collections.Generic.List[string]]::new()
    $totalBytes = [long]0

    foreach ($relative in $RelativePath) {
        $absolute = Join-Path -Path $RepoRoot -ChildPath $relative
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            throw "Declared canonical source '$relative' is recorded in the git index but absent from the working tree."
        }
        $bytes = [System.IO.File]::ReadAllBytes($absolute)
        $contentHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $entries.Add("$relative $contentHash")
        $totalBytes += $bytes.LongLength
    }

    $entries.Sort([System.StringComparer]::Ordinal)

    $manifest = if ($entries.Count -eq 0) { '' } else { ($entries -join "`n") + "`n" }
    $digest = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($manifest))
    ).ToLowerInvariant()

    return @{
        Digest     = $digest
        FileCount  = $entries.Count
        TotalBytes = $totalBytes
    }
}

function Expand-PluginTrackedComponentPath {
    <#
    .SYNOPSIS
        Expands one declared canonical component to its git-tracked files.

    .DESCRIPTION
        A file-valued component resolves to itself. A directory-valued component,
        such as a skill or a hook payload directory, expands to every tracked
        path beneath it. Only the git index is consulted, so ignored or purely
        local working-tree residue can never enter a digest.

    .PARAMETER SourcePath
        Repository-relative canonical component path.

    .PARAMETER TrackedLookup
        Ordinal set of git-tracked repository-relative paths.

    .PARAMETER SortedTrackedPath
        Ordinally sorted array of the same tracked paths.

    .OUTPUTS
        [string[]] Tracked repository-relative paths the component covers.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$TrackedLookup,

        [Parameter(Mandatory = $true)]
        [string[]]$SortedTrackedPath
    )

    if ($TrackedLookup.Contains($SourcePath)) {
        return [string[]]@($SourcePath)
    }

    $prefix = "$SourcePath/"
    $start = [array]::BinarySearch($SortedTrackedPath, $prefix, [System.StringComparer]::Ordinal)
    if ($start -lt 0) {
        $start = -$start - 1
    }

    $matched = [System.Collections.Generic.List[string]]::new()
    for ($index = $start; $index -lt $SortedTrackedPath.Length; $index++) {
        if (-not $SortedTrackedPath[$index].StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            break
        }
        $matched.Add($SortedTrackedPath[$index])
    }

    return [string[]]$matched.ToArray()
}

function Get-PluginCanonicalPackageEvidence {
    <#
    .SYNOPSIS
        Digests each declared package from its canonical git-tracked sources.

    .DESCRIPTION
        Resolves channel-eligible catalog membership, including transitive agent
        closure, into canonical repository-relative source paths and digests each
        package over the git-tracked files those paths cover. No generated tree
        and no staging root participate, so a third party reproduces the same
        values from a clean checkout of the tagged commit.

        The total digest hashes the ordinal-sorted 'name digest' manifest of
        every package, so a content change, a membership change, and a package
        set change each move it.

    .PARAMETER RepoRoot
        Absolute path to the repository working tree.

    .PARAMETER CatalogPath
        Marketplace catalog path, absolute or relative to RepoRoot.

    .PARAMETER Channel
        Release channel whose eligibility policy selects packages.

    .OUTPUTS
        [hashtable] Report with Digest, Packages, FileCount, and TotalBytes keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CatalogPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $resolvedCatalogPath = if ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        $CatalogPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $CatalogPath
    }

    $catalog = Get-MarketplaceCatalog -Path $resolvedCatalogPath
    $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $RepoRoot

    $trackedIndex = Get-PluginTrackedPathIndex -RepoRoot $RepoRoot
    $sortedTracked = [string[]]@($trackedIndex.Paths)
    [array]::Sort($sortedTracked, [System.StringComparer]::Ordinal)

    $eligible = @($catalog['plugins'] | Where-Object { Test-MarketplaceEntryEligible -Entry $_ -Channel $Channel })

    $packages = @()
    $manifestEntries = [System.Collections.Generic.List[string]]::new()
    $totalFileCount = 0
    $totalBytes = [long]0

    foreach ($entry in ($eligible | Sort-Object { [string]$_['name'] })) {
        $name = [string]$entry['name']
        $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

        foreach ($item in @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $agentIndex)) {
            $sourcePath = [string]$item.SourcePath
            $expanded = @(Expand-PluginTrackedComponentPath -SourcePath $sourcePath `
                    -TrackedLookup $trackedIndex.Lookup -SortedTrackedPath $sortedTracked)
            if ($expanded.Count -eq 0) {
                throw "Package '$name' declares component '$sourcePath', which matches no git-tracked canonical source."
            }

            # A hook manifest also delivers its sibling payload directory, which
            # is the manifest path without its .json extension.
            if ($item.Kind -eq 'hook') {
                $payloadRoot = $sourcePath -replace '\.json$', ''
                $expanded += @(Expand-PluginTrackedComponentPath -SourcePath $payloadRoot `
                        -TrackedLookup $trackedIndex.Lookup -SortedTrackedPath $sortedTracked)
            }

            foreach ($file in $expanded) {
                [void]$files.Add($file)
            }
        }

        if ($files.Count -eq 0) {
            throw "Package '$name' resolves to no git-tracked canonical source file."
        }

        $packageFiles = [string[]]@($files)
        [array]::Sort($packageFiles, [System.StringComparer]::Ordinal)
        $packageReport = Get-PluginPathSetDigest -RepoRoot $RepoRoot -RelativePath $packageFiles

        $packages += [ordered]@{
            name      = $name
            digest    = $packageReport.Digest
            fileCount = $packageReport.FileCount
        }
        $manifestEntries.Add("$name $($packageReport.Digest)")
        $totalFileCount += $packageReport.FileCount
        $totalBytes += $packageReport.TotalBytes
    }

    $manifestEntries.Sort([System.StringComparer]::Ordinal)
    $manifest = if ($manifestEntries.Count -eq 0) { '' } else { ($manifestEntries -join "`n") + "`n" }
    $digest = [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($manifest))
    ).ToLowerInvariant()

    return @{
        Digest     = $digest
        FileCount  = $totalFileCount
        TotalBytes = $totalBytes
        Packages   = $packages
    }
}

#endregion Digest

#region Evidence

function New-PluginCanonicalEvidenceDocument {
    <#
    .SYNOPSIS
        Builds the canonical evidence document for an ordinary release tag.

    .DESCRIPTION
        Binds the immutable source commit, the package version, the pathless
        channel release locator, and the canonical package digests. The locator
        carries no package path because the evidence addresses the repository
        at the release tag rather than a projected package tree.

    .PARAMETER SourceCommit
        Full 40-character commit id the evidence was computed from.

    .PARAMETER Version
        Package version the release carries.

    .PARAMETER Locator
        Pathless release locator from New-PluginReleaseLocator.

    .PARAMETER PackageEvidence
        Report from Get-PluginCanonicalPackageEvidence.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Evidence document.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceCommit,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [hashtable]$Locator,

        [Parameter(Mandatory = $true)]
        [hashtable]$PackageEvidence
    )

    if ($SourceCommit -cnotmatch '^[0-9a-f]{40}$') {
        throw "Source commit '$SourceCommit' must be a full 40-character lowercase commit id."
    }

    $expectedRefs = @("v$Version", "prerelease-v$Version")
    if ($Locator.Ref -cnotin $expectedRefs) {
        throw "Release locator '$($Locator.Ref)' does not match package version '$Version' (expected '$($expectedRefs -join "' or '")')."
    }

    $packages = @($PackageEvidence.Packages)
    if ($packages.Count -eq 0) {
        throw 'Canonical release evidence must cover at least one package.'
    }

    foreach ($package in $packages) {
        if ([int]$package['fileCount'] -le 0) {
            throw "Package '$($package['name'])' resolves to no canonical source file."
        }
    }

    # generatedAt is recorded for operators and deliberately excluded from every
    # compared field, so it can never influence the deterministic invariant.
    return [ordered]@{
        schema       = $script:PluginCanonicalEvidenceSchema
        sourceCommit = $SourceCommit
        version      = $Version
        locator      = [ordered]@{
            source = 'github'
            repo   = $Locator.Repo
            ref    = $Locator.Ref
        }
        packageCount = $packages.Count
        packages     = $packages
        fileCount    = $PackageEvidence.FileCount
        totalBytes   = $PackageEvidence.TotalBytes
        digest       = $PackageEvidence.Digest
        generatedAt  = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Compare-PluginReleaseEvidence {
    <#
    .SYNOPSIS
        Compares recorded evidence against freshly computed evidence.

    .DESCRIPTION
        Reports every disagreement across schema, source commit, version,
        locator, package set, and digest. Incidental metadata is not compared.

    .PARAMETER Expected
        Previously recorded evidence document.

    .PARAMETER Actual
        Freshly computed evidence document.

    .OUTPUTS
        [string[]] Disagreement messages, empty when the invariant holds.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Expected,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Actual
    )

    $differences = @()

    foreach ($field in @('schema', 'sourceCommit', 'version', 'digest')) {
        if ($null -eq $Expected[$field]) {
            $differences += "recorded evidence is missing required field '$field'"
            continue
        }

        if ([string]$Expected[$field] -cne [string]$Actual[$field]) {
            $differences += "$field disagreement: recorded '$($Expected[$field])', actual '$($Actual[$field])'"
        }
    }

    $expectedLocator = $Expected['locator']
    if ($expectedLocator -isnot [System.Collections.IDictionary]) {
        $differences += "recorded evidence is missing required field 'locator'"
    }
    else {
        # The compared field set is the union of both documents, so a locator
        # field present in only one of them is reported rather than silently
        # skipped.
        $locatorFields = [System.Collections.Generic.List[string]]::new()
        foreach ($field in @($expectedLocator.Keys) + @($Actual['locator'].Keys)) {
            $name = [string]$field
            if (-not $locatorFields.Contains($name)) {
                $locatorFields.Add($name)
            }
        }
        $locatorFields.Sort([System.StringComparer]::Ordinal)

        foreach ($field in $locatorFields) {
            if ([string]$expectedLocator[$field] -cne [string]$Actual['locator'][$field]) {
                $differences += "locator.$field disagreement: recorded '$($expectedLocator[$field])', actual '$($Actual['locator'][$field])'"
            }
        }
    }

    $expectedPackages = @($Expected['packages'])
    $actualPackages = @($Actual['packages'])

    $expectedNames = @($expectedPackages | ForEach-Object { [string]$_['name'] })
    $actualNames = @($actualPackages | ForEach-Object { [string]$_['name'] })

    foreach ($missing in ($actualNames | Where-Object { $expectedNames -notcontains $_ })) {
        $differences += "package '$missing' is present in the snapshot but absent from recorded evidence"
    }

    foreach ($extra in ($expectedNames | Where-Object { $actualNames -notcontains $_ })) {
        $differences += "package '$extra' is recorded in evidence but absent from the snapshot"
    }

    foreach ($expectedPackage in $expectedPackages) {
        $name = [string]$expectedPackage['name']
        $actualPackage = @($actualPackages | Where-Object { [string]$_['name'] -eq $name })[0]
        if ($null -ne $actualPackage -and [string]$expectedPackage['digest'] -cne [string]$actualPackage['digest']) {
            $differences += "package '$name' digest disagreement: recorded '$($expectedPackage['digest'])', actual '$($actualPackage['digest'])'"
        }
    }

    return [string[]]$differences
}

#endregion Evidence

#region Orchestration

function Invoke-PluginReleaseEvidence {
    <#
    .SYNOPSIS
        Records or verifies deterministic plugin release evidence.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER CatalogPath
        Marketplace catalog declaring package membership.

    .PARAMETER Channel
        Release channel whose eligibility policy selects packages and whose tag
        namespace the release locator addresses.

    .PARAMETER SourceCommit
        Full commit id. Resolved from git when omitted.

    .PARAMETER Version
        Package version. Read from package.json when omitted.

    .PARAMETER ReleaseTag
        Immutable channel release tag. Derived from the channel and version when
        omitted.

    .PARAMETER OutputPath
        Destination for the evidence document.

    .PARAMETER ExpectedEvidencePath
        Recorded evidence document to verify against.

    .PARAMETER ExpectedPackageCount
        Cutover precondition on the number of packages the evidence covers.

    .OUTPUTS
        [hashtable] Report with Success, ErrorCount, Errors, and Evidence keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$CatalogPath = '.github/plugin/marketplace.json',

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'PreRelease',

        [Parameter(Mandatory = $false)]
        [string]$SourceCommit,

        [Parameter(Mandatory = $false)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$ReleaseTag,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$ExpectedEvidencePath,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 1000)]
        [int]$ExpectedPackageCount = 0
    )

    if ([string]::IsNullOrWhiteSpace($Version)) {
        $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
        if (-not (Test-Path -LiteralPath $packageJsonPath)) {
            throw "package.json not found at $packageJsonPath."
        }
        $Version = (Get-Content -LiteralPath $packageJsonPath -Raw | ConvertFrom-Json).version
    }

    if ([string]::IsNullOrWhiteSpace($SourceCommit)) {
        $SourceCommit = (git -C $RepoRoot rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($SourceCommit)) {
            throw 'Source commit could not be resolved from git. Pass -SourceCommit explicitly.'
        }
        $SourceCommit = $SourceCommit.Trim()
    }

    $locator = if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
        New-PluginReleaseLocator -Version $Version -Channel $Channel
    }
    else {
        New-PluginReleaseLocator -Tag $ReleaseTag -Channel $Channel
    }

    $packageEvidence = Get-PluginCanonicalPackageEvidence -RepoRoot $RepoRoot -CatalogPath $CatalogPath -Channel $Channel
    $evidence = New-PluginCanonicalEvidenceDocument `
        -SourceCommit $SourceCommit `
        -Version $Version `
        -Locator $locator `
        -PackageEvidence $packageEvidence

    Write-Host 'Plugin release evidence' -ForegroundColor Cyan
    Write-Host "  Schema:        $($evidence.schema)"
    Write-Host "  Source commit: $($evidence.sourceCommit)"
    Write-Host "  Version:       $($evidence.version)"
    Write-Host "  Locator:       $($evidence.locator.repo)@$($evidence.locator.ref)"
    Write-Host "  Packages:      $($evidence.packageCount)"
    Write-Host ("  Size:          {0:N1} MB in {1} files" -f ($evidence.totalBytes / 1MB), $evidence.fileCount)
    Write-Host "  Digest:        $($evidence.digest)"

    $errors = @()

    if ($ExpectedPackageCount -gt 0 -and $evidence.packageCount -ne $ExpectedPackageCount) {
        $errors += "package count precondition failed: expected $ExpectedPackageCount, snapshot has $($evidence.packageCount)"
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedEvidencePath)) {
        $resolvedExpectedPath = if ([System.IO.Path]::IsPathRooted($ExpectedEvidencePath)) {
            $ExpectedEvidencePath
        }
        else {
            Join-Path -Path $RepoRoot -ChildPath $ExpectedEvidencePath
        }

        if (-not (Test-Path -LiteralPath $resolvedExpectedPath -PathType Leaf)) {
            $errors += "recorded evidence not found: $ExpectedEvidencePath"
        }
        else {
            $expected = $null
            try {
                $expected = Get-Content -LiteralPath $resolvedExpectedPath -Raw | ConvertFrom-Json -AsHashtable
            }
            catch {
                $errors += "recorded evidence is not valid JSON: $($_.Exception.Message)"
            }

            if ($expected -isnot [System.Collections.IDictionary]) {
                if ($errors.Count -eq 0) {
                    $errors += 'recorded evidence is not an evidence document'
                }
            }
            else {
                $errors += @(Compare-PluginReleaseEvidence -Expected $expected -Actual $evidence)
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
            $OutputPath
        }
        else {
            Join-Path -Path $RepoRoot -ChildPath $OutputPath
        }

        $outputDir = Split-Path -Path $resolvedOutputPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
        Write-Host "  Evidence:      $resolvedOutputPath"
    }

    foreach ($validationError in $errors) {
        Write-Host "    x $validationError" -ForegroundColor Red
    }

    return @{
        Success    = ($errors.Count -eq 0)
        ErrorCount = $errors.Count
        Errors     = @($errors)
        Evidence   = $evidence
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $resolvedRepoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
            (Get-Item "$ScriptDir/../..").FullName
        }
        else {
            $RepoRoot
        }

        $result = Invoke-PluginReleaseEvidence `
            -RepoRoot $resolvedRepoRoot `
            -CatalogPath $CatalogPath `
            -Channel $Channel `
            -SourceCommit $SourceCommit `
            -Version $Version `
            -ReleaseTag $ReleaseTag `
            -OutputPath $OutputPath `
            -ExpectedEvidencePath $ExpectedEvidencePath `
            -ExpectedPackageCount $ExpectedPackageCount

        if (-not $result.Success) {
            throw "Plugin release evidence disagreement: $($result.ErrorCount) finding(s)."
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Plugin release evidence failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
