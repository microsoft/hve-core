#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Updates version strings across all version-tracked files in the repository.

.DESCRIPTION
    Central version bump script for the version-tracked files that must agree
    for a release or moving catalog. Updates:

    - package.json
    - package-lock.json (version and packages[""].version)
    - extension/templates/package.template.json
    - .github/plugin/marketplace.json (metadata.version and plugins[*].version),
      left byte-for-byte unchanged when a candidate is recorded
    - .github/plugin/release-candidate.json, when a candidate action is selected
    - The selected release-please manifest, unless SkipManifest is set

    After updating the files, runs 'npm run plugin:generate' against the
    caller-supplied staging root unless generation is skipped.

    The same canonical serialization and digest functions serve the promotion
    that records a candidate and the managed synchronization that reapplies it,
    so both sides compare identical bytes.

.PARAMETER Version
    The version string to write (e.g. '3.3.0').

.PARAMETER Channel
    Required catalog source-ref policy. Every channel deletes source.sha.
    PreRelease writes prerelease-v<version>; Stable writes v<version>.

.PARAMETER RepoRoot
    Optional. Repository root directory. Defaults to the git working tree root.

.PARAMETER ManifestPath
    Optional. Repository-relative manifest path to update. Defaults to
    .release-please-manifest.json.

.PARAMETER SkipManifest
    Optional. Update shared version metadata without changing a release-please
    manifest. Cannot be combined with ManifestPath.

.PARAMETER SkipPluginGenerate
    Optional. Skip running 'npm run plugin:generate' after updating files.

.PARAMETER CandidateAction
    Optional. Record writes a release candidate record from the immutable
    source catalog and leaves the committed catalog byte-for-byte unchanged;
    Apply verifies the retained record against current release intent and
    rebuilds the catalog from it; Verify rechecks the record against the
    committed catalog and writes nothing, and additionally replays the
    deterministic candidate resolution when CandidateSourceCommit,
    CandidateSourceCatalog, and BaselineTag are supplied together.

.PARAMETER CandidateVersion
    Future release version bound into a recorded candidate.

.PARAMETER CandidateSourceCommit
    Full 40-character commit id of the immutable candidate source.

.PARAMETER CandidateSourceCatalog
    File holding the marketplace catalog read from CandidateSourceCommit.

.PARAMETER BaselineTag
    Baseline locator of the target branch the candidate advances from. Either
    the reserved OMITTED locator, used only while the target branch still
    carries the ref-less bootstrap catalog, or the exact channel tag
    prerelease-v<version> for PreRelease and v<version> for Stable.

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0' -Channel PreRelease

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0' -Channel Stable -RepoRoot '/path/to/repo'

.NOTES
    Requires Node.js and npm dependencies installed when SkipPluginGenerate is
    not set. The caller must also supply package staging outside the repository.
    Catalog ref updates are explicit because release-please's extra-files
    updaters cannot express property insertion or removal.
#>

[CmdletBinding(DefaultParameterSetName = 'Manifest')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\z')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('PreRelease', 'Stable')]
    [string]$Channel,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = "",

    [Parameter(Mandatory = $false, ParameterSetName = 'Manifest')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            -not [System.IO.Path]::IsPathRooted($_) -and
            $_ -notmatch '(^|[\\/])\.\.([\\/]|$)'
        })]
    [string]$ManifestPath = '.release-please-manifest.json',

    [Parameter(Mandatory = $true, ParameterSetName = 'SkipManifest')]
    [switch]$SkipManifest,

    [Parameter(Mandatory = $false)]
    [ValidateSet('None', 'Record', 'Apply', 'Verify')]
    [string]$CandidateAction = 'None',

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^\d+\.\d+\.\d+\z')]
    [string]$CandidateVersion,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-f]{40}\z')]
    [string]$CandidateSourceCommit,

    [Parameter(Mandatory = $false)]
    [string]$CandidateSourceCatalog,

    [Parameter(Mandatory = $false)]
    [string]$BaselineTag,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPluginGenerate
)

$ErrorActionPreference = 'Stop'

$script:ReleaseCandidateSchema = 'hve-core/release-candidate/v1'
$script:OmittedBaselineLocator = 'OMITTED'
$script:MarketplaceCatalogFile = '.github/plugin/marketplace.json'
$script:ReleaseCandidateFile = '.github/plugin/release-candidate.json'

#region Helpers

function Resolve-RepoRoot {
    <#
    .SYNOPSIS
        Resolves the repository root directory.
    #>
    param([string]$Supplied)

    if ($Supplied) {
        return (Resolve-Path $Supplied).Path
    }

    # Walk up from script location to find the repo root
    $candidate = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    if (Test-Path (Join-Path $candidate ".git")) {
        return $candidate
    }

    throw "Unable to determine repository root. Pass -RepoRoot explicitly."
}

function Update-JsonVersion {
    <#
    .SYNOPSIS
        Updates a version field in a JSON file using a script block.
    #>
    param(
        [string]$FilePath,
        [string]$Description,
        [scriptblock]$Transform,
        [switch]$AsHashtable
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "  ⏭️  Skipping $Description — file not found: $FilePath" -ForegroundColor Yellow
        return
    }

    $convertParams = @{ Depth = 20 }
    if ($AsHashtable) { $convertParams['AsHashtable'] = $true }
    $raw = Get-Content -Raw $FilePath
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "File is empty or whitespace-only: $FilePath"
    }
    $hadFinalNewline = $raw.EndsWith("`n", [System.StringComparison]::Ordinal)
    $json = $raw | ConvertFrom-Json @convertParams
    $json = & $Transform $json
    $content = $json | ConvertTo-Json -Depth 20
    if ($hadFinalNewline) {
        $content += "`n"
    }
    $content | Set-Content -Path $FilePath -Encoding UTF8 -NoNewline
    Write-Host "  ✅ Updated $Description" -ForegroundColor Green
}

function Get-MarketplaceChannelRef {
    <#
    .SYNOPSIS
        Returns the exact catalog source ref a channel pins for a version.

    .PARAMETER Channel
        Catalog source-ref policy.

    .PARAMETER Version
        Exact version the ref addresses.

    .OUTPUTS
        [string] Channel ref.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version
    )

    switch ($Channel) {
        'PreRelease' { return "prerelease-v$Version" }
        'Stable' { return "v$Version" }
    }
}

function Assert-BaselineLocator {
    <#
    .SYNOPSIS
        Fails closed unless a baseline locator is reserved or channel-exact.

    .DESCRIPTION
        OMITTED is the only non-tag locator, and it describes the ref-less
        bootstrap catalog a release branch is seeded with. Every later baseline
        is the exact tag its own channel writes, so a legacy namespace, a
        cross-channel tag, or any other value is rejected rather than carried
        into a candidate record.

    .PARAMETER Channel
        Release channel that owns the baseline.

    .PARAMETER BaselineTag
        Baseline locator to validate.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$BaselineTag
    )

    if ($BaselineTag -ceq $script:OmittedBaselineLocator) {
        return
    }

    $pattern = switch ($Channel) {
        'PreRelease' { '^prerelease-v\d+\.\d+\.\d+\z' }
        'Stable' { '^v\d+\.\d+\.\d+\z' }
    }
    if ($BaselineTag -cnotmatch $pattern) {
        throw "Baseline locator '$BaselineTag' is neither '$script:OmittedBaselineLocator' nor an exact $Channel channel tag."
    }
}

function Update-MarketplaceCatalogVersion {
    <#
    .SYNOPSIS
        Advances marketplace versions and applies an explicit channel policy.

    .DESCRIPTION
        Deletes source.sha from every entry on every channel, then applies the
        channel ref policy, so no entry pins a commit id and channel identity
        rests entirely on the ref.

    .PARAMETER Catalog
        Parsed marketplace catalog.

    .PARAMETER Version
        Exact version written to catalog metadata and every package.

    .PARAMETER Channel
        PreRelease writes prerelease-v<version>; Stable writes v<version>.

    .OUTPUTS
        [object] Updated marketplace catalog.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Catalog,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel
    )

    $ref = Get-MarketplaceChannelRef -Channel $Channel -Version $Version
    $Catalog.metadata.version = $Version
    foreach ($plugin in $Catalog.plugins) {
        $plugin.version = $Version
        $plugin.source.PSObject.Properties.Remove('sha')
        $plugin.source | Add-Member -NotePropertyName ref -NotePropertyValue $ref -Force
    }
    return $Catalog
}

function Get-MarketplaceCatalogDigest {
    <#
    .SYNOPSIS
        Returns the canonical lowercase SHA-256 digest of a catalog.

    .DESCRIPTION
        Digests the UTF-8, no-BOM, no-final-newline bytes of the compressed
        serialization, so producer and verifier compare the same bytes whatever
        on-disk formatting each side happens to hold.

    .PARAMETER Catalog
        Parsed marketplace catalog.

    .OUTPUTS
        [string] Lowercase SHA-256 hex digest.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Catalog
    )

    $canonical = $Catalog | ConvertTo-Json -Compress -Depth 20
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($canonical)
    return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Get-MarketplaceCatalogFile {
    <#
    .SYNOPSIS
        Parses a marketplace catalog file through the canonical JSON path.

    .PARAMETER Path
        Catalog file path.

    .OUTPUTS
        [object] Parsed catalog preserving source property ordering.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Marketplace catalog not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Marketplace catalog is empty or whitespace-only: $Path"
    }
    return ($raw | ConvertFrom-Json -Depth 20)
}

function Copy-MarketplaceCatalog {
    <#
    .SYNOPSIS
        Returns an independent copy of a parsed catalog.

    .PARAMETER Catalog
        Parsed marketplace catalog.

    .OUTPUTS
        [object] Deep copy preserving property ordering.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Catalog
    )

    return ($Catalog | ConvertTo-Json -Compress -Depth 20 | ConvertFrom-Json -Depth 20)
}

function Get-ReleaseCandidateRecordFile {
    <#
    .SYNOPSIS
        Parses a release candidate record file.

    .PARAMETER Path
        Record file path.

    .OUTPUTS
        [object] Parsed candidate record.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Release candidate record not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Release candidate record is empty or whitespace-only: $Path"
    }
    return ($raw | ConvertFrom-Json -Depth 20)
}

function New-ReleaseCandidateRecord {
    <#
    .SYNOPSIS
        Builds the immutable candidate record a reviewed promotion commits.

    .PARAMETER Channel
        Release channel that owns the candidate.

    .PARAMETER SourceCommit
        Full 40-character commit id of the immutable candidate source.

    .PARAMETER BaselineTag
        Baseline locator of the target branch the candidate advances from.

    .PARAMETER Version
        Future release version the candidate carries.

    .PARAMETER SourceCatalog
        Catalog parsed from SourceCommit.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Candidate record.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}\z')]
        [string]$SourceCommit,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaselineTag,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [object]$SourceCatalog
    )

    Assert-BaselineLocator -Channel $Channel -BaselineTag $BaselineTag

    $transformed = Update-MarketplaceCatalogVersion `
        -Catalog (Copy-MarketplaceCatalog -Catalog $SourceCatalog) `
        -Version $Version `
        -Channel $Channel

    return [ordered]@{
        schema                   = $script:ReleaseCandidateSchema
        channel                  = $Channel
        sourceCommit             = $SourceCommit
        baselineTag              = $BaselineTag
        version                  = $Version
        sourceCatalogDigest      = Get-MarketplaceCatalogDigest -Catalog $SourceCatalog
        transformedCatalogDigest = Get-MarketplaceCatalogDigest -Catalog $transformed
    }
}

function Write-ReleaseCandidateRecordFile {
    <#
    .SYNOPSIS
        Writes a candidate record, creating or replacing the channel authority.

    .PARAMETER Path
        Record file path.

    .PARAMETER Record
        Candidate record to persist.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Record
    )

    $directory = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }
    (($Record | ConvertTo-Json -Depth 20) + "`n") | Set-Content -LiteralPath $Path -Encoding UTF8 -NoNewline
}

function Assert-ReleaseCandidateIdentity {
    <#
    .SYNOPSIS
        Fails closed unless a record matches current release intent.

    .PARAMETER Record
        Parsed candidate record.

    .PARAMETER Channel
        Requested release channel.

    .PARAMETER Version
        Release version the managed head carries.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record,

        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version
    )

    foreach ($field in @('schema', 'channel', 'sourceCommit', 'baselineTag', 'version', 'sourceCatalogDigest', 'transformedCatalogDigest')) {
        if ([string]::IsNullOrWhiteSpace([string]$Record.$field)) {
            throw "Release candidate record is missing required field '$field'."
        }
    }
    if ([string]$Record.schema -cne $script:ReleaseCandidateSchema) {
        throw "Release candidate record schema '$($Record.schema)' is not '$script:ReleaseCandidateSchema'."
    }
    if ([string]$Record.channel -cne $Channel) {
        throw "Release candidate record channel '$($Record.channel)' does not match the requested channel '$Channel'."
    }
    if ([string]$Record.version -cne $Version) {
        throw "Release candidate record version '$($Record.version)' does not match the managed release version '$Version'."
    }
    if ([string]$Record.sourceCommit -cnotmatch '^[0-9a-f]{40}\z') {
        throw "Release candidate record sourceCommit '$($Record.sourceCommit)' is not a full lowercase commit id."
    }
    Assert-BaselineLocator -Channel $Channel -BaselineTag ([string]$Record.baselineTag)
    foreach ($field in @('sourceCatalogDigest', 'transformedCatalogDigest')) {
        if ([string]$Record.$field -cnotmatch '^[0-9a-f]{64}\z') {
            throw "Release candidate record $field '$($Record.$field)' is not a lowercase SHA-256 digest."
        }
    }
}

function Resolve-ReleaseCandidateCatalog {
    <#
    .SYNOPSIS
        Verifies a candidate record and rebuilds its deterministic catalog.

    .PARAMETER Record
        Parsed candidate record retained from the reviewed promotion.

    .PARAMETER Channel
        Requested release channel.

    .PARAMETER SourceCommit
        Immutable source the managed head fetched.

    .PARAMETER BaselineTag
        Baseline locator of the target branch the candidate advances from.

    .PARAMETER Version
        Release version the managed head carries.

    .PARAMETER SourceCatalog
        Catalog parsed from SourceCommit.

    .OUTPUTS
        [object] Candidate catalog whose digest equals the recorded transform.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record,

        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}\z')]
        [string]$SourceCommit,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaselineTag,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [object]$SourceCatalog
    )

    Assert-BaselineLocator -Channel $Channel -BaselineTag $BaselineTag
    Assert-ReleaseCandidateIdentity -Record $Record -Channel $Channel -Version $Version
    if ([string]$Record.sourceCommit -cne $SourceCommit) {
        throw "Release candidate record sourceCommit '$($Record.sourceCommit)' does not match the fetched source '$SourceCommit'."
    }
    if ([string]$Record.baselineTag -cne $BaselineTag) {
        throw "Release candidate record baselineTag '$($Record.baselineTag)' does not match the target baseline '$BaselineTag'."
    }

    $sourceDigest = Get-MarketplaceCatalogDigest -Catalog $SourceCatalog
    if ($sourceDigest -cne [string]$Record.sourceCatalogDigest) {
        throw "Candidate source catalog digest $sourceDigest does not match the recorded $($Record.sourceCatalogDigest)."
    }

    $transformed = Update-MarketplaceCatalogVersion `
        -Catalog (Copy-MarketplaceCatalog -Catalog $SourceCatalog) `
        -Version $Version `
        -Channel $Channel
    $transformedDigest = Get-MarketplaceCatalogDigest -Catalog $transformed
    if ($transformedDigest -cne [string]$Record.transformedCatalogDigest) {
        throw "Candidate transformed catalog digest $transformedDigest does not match the recorded $($Record.transformedCatalogDigest)."
    }

    return $transformed
}

function Assert-ReleaseCandidateCatalog {
    <#
    .SYNOPSIS
        Fails closed unless a committed catalog is the recorded candidate.

    .PARAMETER Record
        Parsed candidate record retained through the release tag.

    .PARAMETER Channel
        Requested release channel.

    .PARAMETER Version
        Release version the committed state carries.

    .PARAMETER Catalog
        Committed marketplace catalog.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Record,

        [Parameter(Mandatory = $true)]
        [ValidateSet('PreRelease', 'Stable')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [object]$Catalog
    )

    Assert-ReleaseCandidateIdentity -Record $Record -Channel $Channel -Version $Version
    $digest = Get-MarketplaceCatalogDigest -Catalog $Catalog
    if ($digest -cne [string]$Record.transformedCatalogDigest) {
        throw "Committed catalog digest $digest does not match the recorded candidate $($Record.transformedCatalogDigest)."
    }
}

function Assert-CandidateArgument {
    <#
    .SYNOPSIS
        Fails closed when a candidate action is missing a required argument.

    .PARAMETER Action
        Selected candidate action.

    .PARAMETER Argument
        Argument names mapped to their supplied values.

    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Argument
    )

    foreach ($name in $Argument.Keys) {
        if ([string]::IsNullOrWhiteSpace([string]$Argument[$name])) {
            throw "Candidate action '$Action' requires -$name."
        }
    }
}

#endregion Helpers

#region Main

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $root = Resolve-RepoRoot -Supplied $RepoRoot
        $catalogPath = Join-Path $root $script:MarketplaceCatalogFile
        $recordPath = Join-Path $root $script:ReleaseCandidateFile

        # Verification reads committed state only, so it runs before any write
        # and never repairs a managed head it was asked to prove.
        if ($CandidateAction -eq 'Verify') {
            # The source arguments are all-or-none, so a partial invocation can
            # never silently downgrade a full replay to a record-only check.
            $sourceArgument = [ordered]@{
                CandidateSourceCommit  = $CandidateSourceCommit
                CandidateSourceCatalog = $CandidateSourceCatalog
                BaselineTag            = $BaselineTag
            }
            $suppliedSourceArgument = @($sourceArgument.Keys | Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$sourceArgument[$_])
                }).Count

            $verifiedRecord = Get-ReleaseCandidateRecordFile -Path $recordPath
            if ($suppliedSourceArgument -gt 0) {
                Assert-CandidateArgument -Action $CandidateAction -Argument $sourceArgument
                $null = Resolve-ReleaseCandidateCatalog `
                    -Record $verifiedRecord `
                    -Channel $Channel `
                    -SourceCommit $CandidateSourceCommit `
                    -BaselineTag $BaselineTag `
                    -Version $Version `
                    -SourceCatalog (Get-MarketplaceCatalogFile -Path $CandidateSourceCatalog)
                Write-Host "  ✅ Replayed $Channel candidate $Version from $CandidateSourceCommit on baseline $BaselineTag" -ForegroundColor Green
            }

            Assert-ReleaseCandidateCatalog `
                -Record $verifiedRecord `
                -Channel $Channel `
                -Version $Version `
                -Catalog (Get-MarketplaceCatalogFile -Path $catalogPath)
            Write-Host "✅ Candidate record and committed catalog agree for $Channel $Version" -ForegroundColor Green
            return
        }

        Write-Host "🔄 Updating version files to $Version" -ForegroundColor Cyan
        Write-Host "  📂 Repo root: $root" -ForegroundColor Gray

        $candidateCatalog = $null
        $candidateRecord = $null
        if ($CandidateAction -eq 'Apply') {
            Assert-CandidateArgument -Action $CandidateAction -Argument ([ordered]@{
                    CandidateSourceCommit  = $CandidateSourceCommit
                    CandidateSourceCatalog = $CandidateSourceCatalog
                    BaselineTag            = $BaselineTag
                })
            $candidateRecord = Get-ReleaseCandidateRecordFile -Path $recordPath
            $candidateCatalog = Resolve-ReleaseCandidateCatalog `
                -Record $candidateRecord `
                -Channel $Channel `
                -SourceCommit $CandidateSourceCommit `
                -BaselineTag $BaselineTag `
                -Version $Version `
                -SourceCatalog (Get-MarketplaceCatalogFile -Path $CandidateSourceCatalog)
        }

        # 1. package.json
        Update-JsonVersion `
            -FilePath (Join-Path $root "package.json") `
            -Description "package.json" `
            -Transform { param($j) $j.version = $Version; $j }

        # 2. package-lock.json (version + packages[""].version)
        Update-JsonVersion `
            -FilePath (Join-Path $root "package-lock.json") `
            -Description "package-lock.json" `
            -AsHashtable `
            -Transform {
                param($j)
                $j['version'] = $Version
                if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                    $j['packages']['']['version'] = $Version
                }
                $j
            }

        # 3. extension/templates/package.template.json
        Update-JsonVersion `
            -FilePath (Join-Path $root "extension/templates/package.template.json") `
            -Description "extension/templates/package.template.json" `
            -Transform { param($j) $j.version = $Version; $j }

        # 4. .github/plugin/marketplace.json
        # A promotion restores the complete prior catalog and records a
        # candidate against it, so Record keeps those bytes as the branch's
        # baseline identity instead of reissuing a channel-constructed ref.
        # Only the record below describes the future transform.
        if ($CandidateAction -eq 'Record') {
            Write-Host "  ⏭️  Preserving $script:MarketplaceCatalogFile — the candidate record owns the transform" -ForegroundColor Yellow
        }
        else {
            Update-JsonVersion `
                -FilePath $catalogPath `
                -Description $script:MarketplaceCatalogFile `
                -Transform {
                    param($j)
                    $source = if ($null -ne $candidateCatalog) { $candidateCatalog } else { $j }
                    Update-MarketplaceCatalogVersion -Catalog $source -Version $Version -Channel $Channel
                }
        }

        # 5. .github/plugin/release-candidate.json
        if ($CandidateAction -eq 'Record') {
            Assert-CandidateArgument -Action $CandidateAction -Argument ([ordered]@{
                    CandidateVersion       = $CandidateVersion
                    CandidateSourceCommit  = $CandidateSourceCommit
                    CandidateSourceCatalog = $CandidateSourceCatalog
                    BaselineTag            = $BaselineTag
                })
            Write-ReleaseCandidateRecordFile `
                -Path $recordPath `
                -Record (New-ReleaseCandidateRecord `
                    -Channel $Channel `
                    -SourceCommit $CandidateSourceCommit `
                    -BaselineTag $BaselineTag `
                    -Version $CandidateVersion `
                    -SourceCatalog (Get-MarketplaceCatalogFile -Path $CandidateSourceCatalog))
            Write-Host "  ✅ Recorded $Channel candidate $CandidateVersion from $CandidateSourceCommit" -ForegroundColor Green
        }
        elseif ($CandidateAction -eq 'Apply') {
            Assert-ReleaseCandidateCatalog `
                -Record $candidateRecord `
                -Channel $Channel `
                -Version $Version `
                -Catalog (Get-MarketplaceCatalogFile -Path $catalogPath)
            Write-Host "  ✅ Applied $Channel candidate $Version from $CandidateSourceCommit" -ForegroundColor Green
        }

        # 6. Selected release-please manifest
        if (-not $SkipManifest) {
            $resolvedManifestPath = Join-Path $root $ManifestPath
            if (
                $PSBoundParameters.ContainsKey('ManifestPath') -and
                -not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)
            ) {
                throw "Manifest file not found: $ManifestPath"
            }

            Update-JsonVersion `
                -FilePath $resolvedManifestPath `
                -Description $ManifestPath `
                -Transform { param($j) $j.'.' = $Version; $j }
        }
        else {
            Write-Host "  ⏭️  Skipping release-please manifest update" -ForegroundColor Yellow
        }

        # 7. Regenerate plugin outputs
        if (-not $SkipPluginGenerate) {
            Write-Host "  🔧 Running npm run plugin:generate ..." -ForegroundColor Cyan
            Push-Location $root
            try {
                npm run plugin:generate
                if ($LASTEXITCODE -ne 0) {
                    throw "npm run plugin:generate failed with exit code $LASTEXITCODE"
                }
                Write-Host "  ✅ Plugin generation complete" -ForegroundColor Green
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Host "  ⏭️  Skipping plugin:generate (SkipPluginGenerate set)" -ForegroundColor Yellow
        }

        Write-Host "✅ All version files updated to $Version" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Version update failed: $_" -ForegroundColor Red
        throw
    }
}

#endregion Main
