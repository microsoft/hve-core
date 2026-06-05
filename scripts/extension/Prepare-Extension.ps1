#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Prepares the HVE Core VS Code extension for packaging.

.DESCRIPTION
    This script prepares the VS Code extension by:
    - Auto-discovering chat agents, prompts, and instruction files
    - Filtering agents by maturity level based on channel
    - Updating package.json with discovered components
    - Updating changelog if provided

    The package.json version is not modified.

.PARAMETER ChangelogPath
    Optional. Path to a changelog file to include in the package.

.PARAMETER Channel
    Optional. Release channel controlling which maturity levels are included.
    'Stable' (default): Only includes agents with maturity 'stable'.
    'PreRelease': Includes 'stable' and 'preview' maturity levels, plus
    'experimental' for the 'hve-core-all' collection only.

.PARAMETER DryRun
    Optional. If specified, shows what would be done without making changes.

.PARAMETER Prune
    Optional. Removes generated `package.*.json` and `README.*.md` files in the
    extension directory whose suffixes do not correspond to a known collection.
    Without this switch, orphan generated files are left untouched.

.PARAMETER ManifestReviewPath
    Optional. Output root for the pre-package manifest review artifacts. The
    rendered collection manifest(s) are written to
    `<ManifestReviewPath>/<collection-id>/`. Defaults to
    `extension/manifest-review` when not specified.

.EXAMPLE
    ./Prepare-Extension.ps1
    # Prepares stable channel using existing version from package.json

.EXAMPLE
    ./Prepare-Extension.ps1 -Channel PreRelease
    # Prepares pre-release channel; experimental agents are included only for hve-core-all

.EXAMPLE
    ./Prepare-Extension.ps1 -ChangelogPath "./CHANGELOG.md"
    # Prepares with changelog

.EXAMPLE
    ./Prepare-Extension.ps1 -Prune
    # Prepares and removes stale generated package/README files for collections
    # that no longer exist

.NOTES
    Dependencies: PowerShell-Yaml module
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ChangelogPath = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'Stable',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Prune,

    [Parameter(Mandatory = $false)]
    [string]$Collection = "",

    [Parameter(Mandatory = $false)]
    [string]$ManifestReviewPath = ""
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../collections/Modules/CollectionHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../collections/Modules/CoreManifestHelpers.psm1") -Force

#region Pure Functions

#region Package Generation Functions

function Get-CollectionDisplayName {
    <#
    .SYNOPSIS
        Resolves a display name from a collection manifest.
    .DESCRIPTION
        Returns the displayName field if set, derives one from the name field,
        or falls back to a default value.
    .PARAMETER CollectionManifest
        Parsed collection manifest hashtable.
    .PARAMETER DefaultValue
        Fallback display name when the manifest provides neither displayName nor name.
    .OUTPUTS
        [string] Resolved display name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest,

        [Parameter(Mandatory = $true)]
        [string]$DefaultValue
    )

    if ($CollectionManifest.ContainsKey('displayName') -and -not [string]::IsNullOrWhiteSpace([string]$CollectionManifest.displayName)) {
        return [string]$CollectionManifest.displayName
    }

    if ($CollectionManifest.ContainsKey('name') -and -not [string]::IsNullOrWhiteSpace([string]$CollectionManifest.name)) {
        return "HVE Core - $($CollectionManifest.name)"
    }

    return $DefaultValue
}

function Resolve-CollectionDisplayName {
    <#
    .SYNOPSIS
        Resolves a channel-specific collection display name.
    .DESCRIPTION
        Uses exact-channel display name overrides when present, then falls back
        to the standard collection display name resolution rules.
    .PARAMETER CollectionManifest
        Parsed collection manifest hashtable.
    .PARAMETER Channel
        Release channel controlling which override key is considered.
    .PARAMETER DefaultDisplayName
        Fallback display name when the manifest provides no usable value.
    .OUTPUTS
        [string] Resolved collection display name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [string]$DefaultDisplayName
    )

    $overrideKey = if ($Channel -eq 'PreRelease') { 'prerelease' } else { 'stable' }
    if ($CollectionManifest.ContainsKey('displayNames') -and $CollectionManifest.displayNames -is [hashtable] -and
        $CollectionManifest.displayNames.ContainsKey($overrideKey) -and
        -not [string]::IsNullOrWhiteSpace([string]$CollectionManifest.displayNames[$overrideKey])) {
        return [string]$CollectionManifest.displayNames[$overrideKey]
    }

    return Get-CollectionDisplayName -CollectionManifest $CollectionManifest -DefaultValue $DefaultDisplayName
}

function Copy-TemplateWithOverrides {
    <#
    .SYNOPSIS
        Clones a template object and applies field overrides.
    .DESCRIPTION
        Copies all properties from Template, replacing any whose key appears in
        Overrides. Additional override keys not in the template are appended.
    .PARAMETER Template
        Source PSCustomObject to clone.
    .PARAMETER Overrides
        Hashtable of field values to override or add.
    .OUTPUTS
        [pscustomobject] New object with overrides applied.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Template,

        [Parameter(Mandatory = $true)]
        [hashtable]$Overrides
    )

    $output = [ordered]@{}

    foreach ($propertyName in $Template.PSObject.Properties.Name) {
        if ($Overrides.ContainsKey($propertyName)) {
            $output[$propertyName] = $Overrides[$propertyName]
        }
        else {
            $output[$propertyName] = $Template.$propertyName
        }
    }

    foreach ($propertyName in $Overrides.Keys | Sort-Object) {
        if (-not $output.Contains($propertyName)) {
            $output[$propertyName] = $Overrides[$propertyName]
        }
    }

    return [pscustomobject]$output
}

function Set-JsonFile {
    <#
    .SYNOPSIS
        Writes an object to a JSON file with UTF-8 encoding.
    .DESCRIPTION
        Serializes Content to JSON and writes to Path, creating parent
        directories as needed.
    .PARAMETER Path
        Destination file path.
    .PARAMETER Content
        Object to serialize.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $json = $Content | ConvertTo-Json -Depth 30
    Set-Content -Path $Path -Value $json -Encoding utf8NoBOM
}

function Remove-StaleGeneratedFiles {
    <#
    .SYNOPSIS
        Removes generated collection files that are no longer expected.
    .DESCRIPTION
        Scans extension/ for `package.*.json` and `README.*.md` files and
        removes any not in the expected set, keeping the directory clean of
        orphaned collection templates.

        Only suffixed files (e.g. `package.foo.json`, `README.foo.md`) are
        considered. The canonical `package.json` and `README.md` are skipped
        unconditionally.
    .PARAMETER RepoRoot
        Repository root path.
    .PARAMETER ExpectedFiles
        Array of absolute paths that should be retained.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ExpectedFiles
    )

    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $ExpectedFiles) {
        $null = $expected.Add([System.IO.Path]::GetFullPath($file))
    }

    $extensionDir = Join-Path $RepoRoot 'extension'

    foreach ($pattern in @('package.*.json', 'README.*.md')) {
        Get-ChildItem -Path $extensionDir -Filter $pattern -File | ForEach-Object {
            $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
            if (-not $expected.Contains($fullPath)) {
                Remove-Item -Path $_.FullName -Force
            }
        }
    }
}

function Invoke-ExtensionCollectionsGeneration {
    <#
    .SYNOPSIS
        Generates collection package files from root collection manifests.
    .DESCRIPTION
        Reads the package template and each collections/*.collection.yml file,
        producing extension/package.json (for hve-core) and
        extension/package.{id}.json for every other collection. When -Prune is
        specified, orphan `package.<id>.json` and `README.<id>.md` files whose
        suffix does not correspond to a known collection are also removed.
    .PARAMETER RepoRoot
        Repository root path containing collections/ and extension/templates/.
    .PARAMETER Channel
        Release channel controlling maturity filtering for README generation.
    .PARAMETER Prune
        When set, removes orphan generated `package.<id>.json` and
        `README.<id>.md` files in extension/ whose suffixes do not correspond
        to a current collection. Default behavior leaves orphan files intact.
    .PARAMETER Collection
        Optional path to a `*.collection.yml` manifest. When supplied, the
        resolved per-id `package.<id>.json` is also written to
        `extension/package.json` so downstream vsce packaging picks up the
        channel-resolved description for the targeted collection. Empty
        default preserves regenerate-everything behavior for local dev.
    .OUTPUTS
        [string[]] Array of generated file paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'Stable',

        [switch]$Prune,

        [string]$Collection = ""
    )

    $collectionsDir = Join-Path $RepoRoot 'collections'
    $templatesDir = Join-Path $RepoRoot 'extension/templates'

    $packageTemplatePath = Join-Path $templatesDir 'package.template.json'

    if (-not (Test-Path $packageTemplatePath)) {
        throw "Package template not found: $packageTemplatePath"
    }

    if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
        throw "Required module 'PowerShell-Yaml' is not installed."
    }

    Import-Module PowerShell-Yaml -ErrorAction Stop

    $packageTemplate = Get-Content -Path $packageTemplatePath -Raw | ConvertFrom-Json

    $coreManifestPath = Join-Path -Path $collectionsDir -ChildPath 'core-manifest.yml'
    $coreManifest = Read-CoreManifest -ManifestPath $coreManifestPath
    $collections = @(ConvertTo-CollectionManifestFromCore -CoreManifest $coreManifest -All -RepoRoot $RepoRoot | Sort-Object { $_.id })
    if ($collections.Count -eq 0) {
        throw "No collections found in $coreManifestPath"
    }

    $expectedFiles = @()
    $pinnedPackageContent = $null

    $targetCollectionId = $null
    if (-not [string]::IsNullOrWhiteSpace($Collection)) {
        try {
            $targetManifest = Get-CollectionManifest -CollectionPath $Collection
        }
        catch {
            throw "Failed to resolve -Collection '$Collection': $($_.Exception.Message)"
        }
        if ($targetManifest -isnot [System.Collections.IDictionary] -or [string]::IsNullOrWhiteSpace([string]$targetManifest.id)) {
            throw "Invalid collection manifest at '$Collection': missing id."
        }
        $targetCollectionId = ([string]$targetManifest.id).ToLowerInvariant()
    }

    foreach ($collectionManifest in $collections) {
        if ($collectionManifest -isnot [System.Collections.IDictionary]) {
            throw "Collection manifest must be a dictionary in $coreManifestPath"
        }

        $collectionId = [string]$collectionManifest.id
        if ([string]::IsNullOrWhiteSpace($collectionId)) {
            throw "Collection id is required in $coreManifestPath"
        }

        $collectionDescription = Resolve-CollectionDescription -CollectionManifest $collectionManifest -Channel $Channel -DefaultDescription ([string]$packageTemplate.description)

        $extensionName = switch ($collectionId) {
            'hve-core'     { [string]$packageTemplate.name }
            'hve-core-all' { 'hve-core-all' }
            default        { "hve-$collectionId" }
        }
        $extensionDisplayName = switch ($collectionId) {
            'hve-core'     { [string]$packageTemplate.displayName }
            'hve-core-all' { 'HVE Core - All' }
            default        { Resolve-CollectionDisplayName -CollectionManifest $collectionManifest -Channel $Channel -DefaultDisplayName ([string]$packageTemplate.displayName) }
        }

        $packageTemplateOutput = Copy-TemplateWithOverrides -Template $packageTemplate -Overrides @{
            name        = $extensionName
            displayName = $extensionDisplayName
            description = $collectionDescription
        }

        $packagePath = switch ($collectionId) {
            'hve-core'     { Join-Path $RepoRoot 'extension/package.json' }
            'hve-core-all' { Join-Path $RepoRoot 'extension/package.hve-core-all.json' }
            default        { Join-Path $RepoRoot "extension/package.$collectionId.json" }
        }

        Set-JsonFile -Path $packagePath -Content $packageTemplateOutput
        $expectedFiles += $packagePath

        if ($null -ne $targetCollectionId -and $collectionId.ToLowerInvariant() -eq $targetCollectionId) {
            $pinnedPackageContent = $packageTemplateOutput
            $pinnedPackagePath = Join-Path $RepoRoot 'extension/package.json'
            if ($packagePath -ne $pinnedPackagePath) {
                $expectedFiles += $pinnedPackagePath
            }
        }
    }

    if ($null -ne $pinnedPackageContent) {
        $pinnedPackagePath = Join-Path $RepoRoot 'extension/package.json'
        Set-JsonFile -Path $pinnedPackagePath -Content $pinnedPackageContent
    }

    # Generate README files for each collection
    $readmeTemplatePath = Join-Path $templatesDir 'README.template.md'
    foreach ($collectionManifest in $collections) {
        $collectionId = [string]$collectionManifest.id

        $collectionReadmeBody = New-CollectionReadmeBodyFromCore -CoreManifest $coreManifest -CollectionId $collectionId -RepoRoot $RepoRoot

        $readmePath = switch ($collectionId) {
            'hve-core'     { Join-Path $RepoRoot 'extension/README.md' }
            'hve-core-all' { Join-Path $RepoRoot 'extension/README.hve-core-all.md' }
            default        { Join-Path $RepoRoot "extension/README.$collectionId.md" }
        }

        New-CollectionReadme -Collection $collectionManifest -CollectionContent $collectionReadmeBody -TemplatePath $readmeTemplatePath -RepoRoot $RepoRoot -OutputPath $readmePath -AllowedMaturities (Get-AllowedMaturities -Channel $Channel -CollectionId $collectionId) -Channel $Channel
        $expectedFiles += $readmePath
    }

    if ($Prune) {
        Remove-StaleGeneratedFiles -RepoRoot $RepoRoot -ExpectedFiles $expectedFiles
    }

    return $expectedFiles
}

function New-CollectionReadme {
    <#
    .SYNOPSIS
        Generates a README.md for an extension collection from a template.
    .DESCRIPTION
        Reads a README template and replaces placeholder tokens with collection
        metadata, hand-authored body content, and auto-generated artifact tables
        with descriptions read from each artifact's YAML frontmatter.
        Tokens: {{DISPLAY_NAME}}, {{DESCRIPTION}}, {{BODY}}, {{ARTIFACTS}},
        {{FULL_EDITION}}.
        When the collection markdown file contains BEGIN/END markers, the
        generated artifact section is written back into the source file via
        Set-ContentIfChanged so the collection.md stays in sync.
    .PARAMETER Collection
        Parsed collection manifest hashtable.
    .PARAMETER CollectionMdPath
        Optional path to the legacy collection markdown body file.
    .PARAMETER CollectionContent
        Optional projected collection markdown body content.
    .PARAMETER TemplatePath
        Path to the README template file containing placeholder tokens.
    .PARAMETER RepoRoot
        Repository root path for resolving artifact file paths.
    .PARAMETER OutputPath
        Destination path for the generated README.
    .PARAMETER AllowedMaturities
        Maturity levels to include in artifact tables. Defaults to stable only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CollectionMdPath,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CollectionContent,

        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'Stable',

        [ValidateNotNullOrEmpty()]
        [string[]]$AllowedMaturities = @('stable')
    )

    $collectionId = [string]$Collection.id
    $displayName = switch ($collectionId) {
        'hve-core'     { 'HVE Core' }
        'hve-core-all' { 'HVE Core - All' }
        default        { Resolve-CollectionDisplayName -CollectionManifest $Collection -Channel $Channel -DefaultDisplayName "HVE Core - $collectionId" }
    }
    $description = Resolve-CollectionDescription -CollectionManifest $Collection -Channel $Channel -DefaultDescription ''

    $collectionMaturity = if ($Collection.ContainsKey('maturity') -and -not [string]::IsNullOrWhiteSpace([string]$Collection.maturity)) {
        [string]$Collection.maturity
    } else { 'stable' }

    $bodyContent = if (-not [string]::IsNullOrWhiteSpace($CollectionContent)) {
        $CollectionContent
    }
    elseif (-not [string]::IsNullOrWhiteSpace($CollectionMdPath) -and (Test-Path -Path $CollectionMdPath -PathType Leaf)) {
        Get-Content -Path $CollectionMdPath -Raw
    }
    else {
        ''
    }
    $parsed = Split-CollectionMdByMarkers -Content $bodyContent

    if ($parsed.HasMarkers -and -not [string]::IsNullOrWhiteSpace($CollectionMdPath) -and (Test-Path -Path $CollectionMdPath -PathType Leaf)) {
        $bodyForTemplate = $parsed.Intro
        if (-not [string]::IsNullOrWhiteSpace($parsed.Footer)) {
            $bodyForTemplate = $bodyForTemplate + "`n`n" + $parsed.Footer.TrimEnd()
        }
    } else {
        $bodyForTemplate = $bodyContent.Trim()
    }

    # Collect artifacts with descriptions grouped by kind
    $agents = @()
    $prompts = @()
    $instructions = @()
    $skills = @()
    $includedMaturities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($Collection.ContainsKey('items')) {
        foreach ($item in $Collection.items) {
            if (-not $item.ContainsKey('kind') -or -not $item.ContainsKey('path')) {
                continue
            }
            $maturity = Resolve-CollectionItemMaturity -Maturity $item.maturity
            if ($AllowedMaturities -and $AllowedMaturities -notcontains $maturity) {
                continue
            }
            $null = $includedMaturities.Add($maturity)
            $kind = [string]$item.kind
            $path = [string]$item.path
            $artifactName = Get-CollectionArtifactKey -Kind $kind -Path $path

            # Resolve full file path for frontmatter reading
            $resolvedPath = Join-Path $RepoRoot ($path -replace '^\./', '')
            if ($kind -eq 'skill') {
                $resolvedPath = Join-Path $resolvedPath 'SKILL.md'
            }
            $artifactDesc = Get-ArtifactDescription -FilePath $resolvedPath

            $entry = @{ Name = $artifactName; Description = $artifactDesc }
            switch ($kind) {
                'agent' { $agents += $entry }
                'prompt' { $prompts += $entry }
                'instruction' { $instructions += $entry }
                'skill' { $skills += $entry }
            }
        }
    }

    $maturityNotice = if ($collectionMaturity -eq 'experimental') {
        '> ⚠ **Experimental**: This collection is experimental and available only in the Pre-Release channel. Contents may change or be removed without notice.'
    }
    elseif ($Channel -eq 'PreRelease' -and $includedMaturities.Contains('experimental')) {
        '> **Pre-Release with experimental content**: This build includes experimental assets that are subject to change and are provided as-is, without warranty of any kind. Share feedback or issues at https://github.com/microsoft/hve-core/issues.'
    }
    elseif ($Channel -eq 'PreRelease' -and $includedMaturities.Contains('preview')) {
        '> **Pre-Release with preview content**: This build includes preview assets for early evaluation and feedback.'
    }
    elseif ($Channel -eq 'PreRelease') {
        '> **Pre-Release build**: This build provides early access and feedback opportunities before stable release.'
    }
    else { '' }

    # Build markdown tables for each artifact kind
    $artifactSections = [System.Text.StringBuilder]::new()

    foreach ($section in @(
        @{ Title = 'Chat Agents'; Items = $agents },
        @{ Title = 'Prompts'; Items = $prompts },
        @{ Title = 'Instructions'; Items = $instructions },
        @{ Title = 'Skills'; Items = $skills }
    )) {
        if ($section.Items.Count -eq 0) { continue }

        $null = $artifactSections.AppendLine("### $($section.Title)")
        $null = $artifactSections.AppendLine()
        $null = $artifactSections.AppendLine('| Name | Description |')
        $null = $artifactSections.AppendLine('|------|-------------|')
        foreach ($entry in ($section.Items | Sort-Object { $_.Name })) {
            $null = $artifactSections.AppendLine("| **$($entry.Name)** | $($entry.Description) |")
        }
        $null = $artifactSections.AppendLine()
    }

    # Write back updated artifact section into collection.md when markers are present.
    # Keep the stable h2 outside the generated marker block so only volatile
    # artifact inventory tables are replaced. Only write back when a source
    # collection.md path is supplied; the core-manifest flow passes content only.
    if ($parsed.HasMarkers -and -not [string]::IsNullOrWhiteSpace($CollectionMdPath) -and (Test-Path -Path $CollectionMdPath -PathType Leaf)) {
        $generatedBlock = $artifactSections.ToString().TrimEnd()
        $intro = $parsed.Intro.TrimEnd()
        if ($intro -notmatch '(?m)^##\s+Included Artifacts\s*$') {
            $intro = "$intro`n`n## Included Artifacts"
        }
        $updatedCollectionMd = "$intro`n`n$($CollectionMdBeginMarker)`n`n$generatedBlock`n`n$($CollectionMdEndMarker)"
        if (-not [string]::IsNullOrWhiteSpace($parsed.Footer)) {
            $updatedCollectionMd += "`n`n$($parsed.Footer.TrimEnd())"
        }
        $updatedCollectionMd += "`n"
        Set-ContentIfChanged -Path $CollectionMdPath -Value $updatedCollectionMd
    }

    $fullEdition = if ($collectionId -notin @('hve-core', 'hve-core-all')) {
        "## Full Edition`n`nLooking for more agents covering additional domains? Check out the full [HVE Core](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) extension."
    }
    else {
        ''
    }

    # Read template and replace tokens
    $template = Get-Content -Path $TemplatePath -Raw
    $readmeContent = $template `
        -replace '\{\{DISPLAY_NAME\}\}', $displayName `
        -replace '\{\{DESCRIPTION\}\}', $description `
        -replace '\{\{MATURITY_NOTICE\}\}', $maturityNotice `
        -replace '\{\{BODY\}\}', $bodyForTemplate `
        -replace '\{\{ARTIFACTS\}\}', $artifactSections.ToString().TrimEnd() `
        -replace '\{\{FULL_EDITION\}\}', $fullEdition

    # Clean up blank lines left by empty token replacements
    $readmeContent = $readmeContent -replace '(\r?\n){3,}', "`n`n"
    $readmeContent = $readmeContent.TrimEnd() + "`n"

    Set-Content -Path $OutputPath -Value $readmeContent -Encoding utf8NoBOM -NoNewline
}

#endregion Package Generation Functions

function Get-AllowedMaturities {
    <#
    .SYNOPSIS
        Returns allowed maturity levels based on release channel and collection.
    .DESCRIPTION
        Pure function that determines which maturity levels (stable, preview, experimental)
        are included in the VS Code extension package based on the specified channel and
        collection. 'Stable' returns only stable. 'PreRelease' returns stable and preview,
        and additionally includes 'experimental' only for the 'hve-core-all' collection.
        Experimental assets are gated to the all-inclusive collection so per-collection
        extension builds do not surface experimental content.
    .PARAMETER Channel
        Release channel. 'Stable' returns only stable; 'PreRelease' returns stable and
        preview (plus experimental for the 'hve-core-all' collection).
    .PARAMETER CollectionId
        Collection identifier. Experimental maturity is included only when this is
        'hve-core-all' and the channel is 'PreRelease'.
    .OUTPUTS
        [string[]] Array of allowed maturity level strings.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CollectionId = ''
    )

    if ($Channel -eq 'PreRelease') {
        if ($CollectionId -eq 'hve-core-all') {
            return @('stable', 'preview', 'experimental')
        }
        return @('stable', 'preview')
    }
    return @('stable')
}

function Test-CollectionMaturityEligible {
    <#
    .SYNOPSIS
        Checks whether a collection is eligible for the specified release channel.
    .DESCRIPTION
        Pure function that evaluates collection-level maturity against channel rules.
        Experimental collections are eligible only for PreRelease. Deprecated collections
        are excluded from all channels.
    .PARAMETER CollectionManifest
        Parsed collection manifest hashtable.
    .PARAMETER Channel
        Release channel ('Stable' or 'PreRelease').
    .OUTPUTS
        [hashtable] With IsEligible bool and Reason string.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $maturity = 'stable'
    if ($CollectionManifest.ContainsKey('maturity') -and $CollectionManifest['maturity']) {
        $maturity = $CollectionManifest['maturity']
    }

    switch ($maturity) {
        'removed' {
            return @{
                IsEligible = $false
                Reason     = "Collection '$($CollectionManifest.id)' is removed and excluded from all channels"
            }
        }
        'deprecated' {
            return @{
                IsEligible = $false
                Reason     = "Collection '$($CollectionManifest.id)' is deprecated and excluded from all channels"
            }
        }
        'experimental' {
            if ($Channel -eq 'Stable') {
                return @{
                    IsEligible = $false
                    Reason     = "Collection '$($CollectionManifest.id)' is experimental and excluded from Stable channel"
                }
            }
            return @{ IsEligible = $true; Reason = '' }
        }
        'preview' {
            return @{ IsEligible = $true; Reason = '' }
        }
        'stable' {
            return @{ IsEligible = $true; Reason = '' }
        }
        default {
            return @{
                IsEligible = $false
                Reason     = "Collection '$($CollectionManifest.id)' has invalid maturity value: $maturity"
            }
        }
    }
}

function Test-GlobMatch {
    <#
    .SYNOPSIS
        Tests whether a name matches any of the provided glob patterns.
    .DESCRIPTION
        Uses PowerShell's -like operator to test glob pattern matching with
        * (any characters) and ? (single character) wildcards.
    .PARAMETER Name
        The artifact name to test against patterns.
    .PARAMETER Patterns
        Array of glob patterns to match against.
    .OUTPUTS
        [bool] True if name matches any pattern, false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Name -like $pattern) {
            return $true
        }
    }
    return $false
}

function Get-CollectionArtifacts {
    <#
    .SYNOPSIS
        Filters collection artifacts by collection item metadata and channel maturity.
    .DESCRIPTION
        Applies collection-level filtering to manifest items, returning artifact
        names that match allowed maturities. Item-level maturity is used when
        present; otherwise artifacts default to stable.
    .PARAMETER Collection
        Collection manifest hashtable with items.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Agents, Prompts, Instructions, Skills arrays of matching artifact names.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Agents       = @()
        Prompts      = @()
        Instructions = @()
        Skills       = @()
    }

    if (-not $Collection.ContainsKey('items') -or @($Collection.items).Count -eq 0) {
        return $result
    }

    foreach ($item in $Collection.items) {
        if (-not $item.ContainsKey('kind') -or -not $item.ContainsKey('path')) {
            continue
        }

        $kind = [string]$item.kind
        $path = [string]$item.path

        $maturity = Resolve-CollectionItemMaturity -Maturity $item.maturity
        if ($AllowedMaturities -notcontains $maturity) {
            continue
        }

        $artifactKey = Get-CollectionArtifactKey -Kind $kind -Path $path
        switch ($kind) {
            'agent' { $result.Agents += $artifactKey }
            'prompt' { $result.Prompts += $artifactKey }
            'instruction' { $result.Instructions += $artifactKey }
            'skill' { $result.Skills += $artifactKey }
        }
    }

    return $result
}

function Resolve-HandoffDependencies {
    <#
    .SYNOPSIS
        Resolves transitive agent handoff dependencies using BFS traversal.
    .DESCRIPTION
        Starting from seed agents, performs breadth-first traversal of agent handoff
        declarations in YAML frontmatter to compute the transitive closure of
        all agents reachable through handoff chains.

        Handoff targets in frontmatter use display names (e.g., "Task Planner")
        while agent files use kebab-case stems (e.g., task-planner.agent.md).
        This function builds a name index to resolve both formats.
    .PARAMETER SeedAgents
        Initial agent names (file stems) to start BFS from.
    .PARAMETER AgentsDir
        Path to the agents directory containing .agent.md files.
    .OUTPUTS
        [string[]] Complete set of agent file stems including seed agents and all transitive handoff targets.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SeedAgents,

        [Parameter(Mandatory = $true)]
        [string]$AgentsDir
    )

    # Build index: map display names and file stems to agent file objects.
    # Handoff targets use display names from frontmatter (e.g., "RPI Agent")
    # while seed agents and collection keys use file stems (e.g., "rpi-agent").
    # Track canonical names per file so case-insensitive hashtable collisions
    # do not silently resolve a base-name reference to a suffixed target.
    $agentIndex = @{}
    $agentCanonicalNames = @{}
    $allAgentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" -Recurse -File
    foreach ($af in $allAgentFiles) {
        $stem = $af.BaseName -replace '\.agent$', ''
        # Ordinal (case-sensitive) so that 'Foo' does not match a canonical 'foo'
        # via case-folding; that mismatch needs to trigger suffix detection.
        $canonical = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        [void]$canonical.Add($stem)
        if (-not $agentIndex.ContainsKey($stem)) {
            $agentIndex[$stem] = $af
        }

        $fc = Get-Content -Path $af.FullName -Raw
        if ($fc -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yml = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
            try {
                $meta = ConvertFrom-Yaml -Yaml $yml
                if ($meta.ContainsKey('name') -and $meta.name -is [string] -and $meta.name -ne '') {
                    [void]$canonical.Add($meta.name)
                    if (-not $agentIndex.ContainsKey($meta.name)) {
                        $agentIndex[$meta.name] = $af
                    }
                }
            }
            catch {
                Write-Verbose "Skipping display name index for $($af.Name): $_"
            }
        }
        $agentCanonicalNames[$af.FullName] = $canonical
    }

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($agent in $SeedAgents) {
        if ($visited.Add($agent)) {
            $queue.Enqueue($agent)
        }
    }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $agentFile = $agentIndex[$current]

        # Hashtable lookup is case-insensitive; verify the matched file actually
        # advertises $current as one of its canonical names so a base-name reference
        # cannot accidentally resolve to a suffixed-name file via casing collisions.
        if ($agentFile) {
            $canonical = $agentCanonicalNames[$agentFile.FullName]
            if (-not ($canonical -and $canonical.Contains($current))) {
                $agentFile = $null
            }
        }

        if (-not $agentFile) {
            # Detect base-name references whose suffixed target is registered (e.g. 'Foo' -> 'Foo (exp)').
            # Suffix shape mirrors Get-AgentMaturityNameSuffix joined with the documented leading space.
            $suffixedCandidate = $null
            foreach ($maturity in @('experimental', 'preview')) {
                $suffix = Get-AgentMaturityNameSuffix -Maturity $maturity
                if ([string]::IsNullOrEmpty($suffix)) { continue }
                $candidate = "$current $suffix"
                if ($agentIndex.ContainsKey($candidate)) {
                    $suffixedCandidate = $candidate
                    break
                }
            }

            if ($suffixedCandidate) {
                throw "Reference uses base name; the target's source 'name:' is '$suffixedCandidate'. Update the reference to match. Handoff target agent file not found: $current"
            }

            throw "Handoff target agent file not found: $current"
        }

        # Normalize visited entry to file stem for consistent collection filtering
        $fileStem = $agentFile.BaseName -replace '\.agent$', ''
        if ($fileStem -ne $current) {
            $visited.Add($fileStem) | Out-Null
        }

        # Parse handoffs from frontmatter
        $content = Get-Content -Path $agentFile.FullName -Raw
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('handoffs') -and $data.handoffs -is [System.Collections.IEnumerable] -and $data.handoffs -isnot [string]) {
                    foreach ($handoff in $data.handoffs) {
                        # Handle both string format and object format (with 'agent' field).
                        # Handoff targets bypass maturity filtering by design.
                        # See docs/contributing/ai-artifacts-common.md
                        # "Handoff vs Requires Maturity Filtering" for rationale.
                        $targetAgent = $null
                        if ($handoff -is [string]) {
                            $targetAgent = $handoff
                        } elseif ($handoff -is [hashtable] -and $handoff.ContainsKey('agent')) {
                            $targetAgent = $handoff.agent
                        }
                        if ($targetAgent -and $visited.Add($targetAgent)) {
                            $queue.Enqueue($targetAgent)
                        }
                    }
                }
            }
            catch {
                Write-Warning "Failed to parse handoffs from $($agentFile.Name): $_"
            }
        }
    }

    return @($visited)
}

function Resolve-RequiresDependencies {
    <#
    .SYNOPSIS
        Resolves transitive artifact dependencies from collection item requires blocks.
    .DESCRIPTION
        Walks requires blocks in collection items to compute the complete set of
        dependent artifacts across all types (agents, prompts, instructions, skills).
    .PARAMETER ArtifactNames
        Hashtable with initial artifact name arrays keyed by type (agents, prompts, instructions, skills).
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER CollectionRequires
        Per-type map of artifact requires blocks keyed by artifact name.
    .PARAMETER CollectionMaturities
        Optional per-type maturity map keyed by artifact name.
    .OUTPUTS
        [hashtable] With Agents, Prompts, Instructions, Skills arrays containing resolved names.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ArtifactNames,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [hashtable]$CollectionRequires = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$CollectionMaturities = @{}
    )

    $resolved = @{
        Agents       = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        Prompts      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        Instructions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        Skills       = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    $typeMap = @{
        agents       = 'Agents'
        prompts      = 'Prompts'
        instructions = 'Instructions'
        skills       = 'Skills'
    }

    # Seed with initial artifact names
    foreach ($type in @('agents', 'prompts', 'instructions', 'skills')) {
        $capitalType = $typeMap[$type]
        if ($ArtifactNames.ContainsKey($type)) {
            foreach ($name in $ArtifactNames[$type]) {
                $null = $resolved[$capitalType].Add($name)
            }
        }
    }

    $changed = $true
    while ($changed) {
        $changed = $false

        foreach ($sourceType in @('agents', 'prompts', 'instructions', 'skills')) {
            if (-not $CollectionRequires.ContainsKey($sourceType)) {
                continue
            }

            $sourceCapitalType = $typeMap[$sourceType]
            foreach ($sourceName in @($resolved[$sourceCapitalType])) {
                if (-not $CollectionRequires[$sourceType].ContainsKey($sourceName)) {
                    continue
                }

                $requires = $CollectionRequires[$sourceType][$sourceName]
                if (-not $requires) {
                    continue
                }

                foreach ($targetType in @('agents', 'prompts', 'instructions', 'skills')) {
                    if (-not $requires.ContainsKey($targetType)) {
                        continue
                    }

                    $targetCapitalType = $typeMap[$targetType]
                    foreach ($dep in @($requires[$targetType])) {
                        $depMaturity = 'stable'
                        if ($CollectionMaturities.ContainsKey($targetType) -and $CollectionMaturities[$targetType].ContainsKey($dep)) {
                            $depMaturity = $CollectionMaturities[$targetType][$dep]
                        }

                        if ($AllowedMaturities -notcontains $depMaturity) {
                            continue
                        }

                        if ($resolved[$targetCapitalType].Add($dep)) {
                            $changed = $true
                        }
                    }
                }
            }
        }
    }

    # Convert HashSets to arrays
    return @{
        Agents       = @($resolved.Agents)
        Prompts      = @($resolved.Prompts)
        Instructions = @($resolved.Instructions)
        Skills       = @($resolved.Skills)
    }
}

function Test-PathsExist {
    <#
    .SYNOPSIS
        Validates that required paths exist for extension preparation.
    .DESCRIPTION
        Validation function that checks whether extension directory, package.json,
        and .github directory exist at the specified locations.
    .PARAMETER ExtensionDir
        Path to the extension directory.
    .PARAMETER PackageJsonPath
        Path to package.json file.
    .PARAMETER GitHubDir
        Path to .github directory.
    .OUTPUTS
        [hashtable] With IsValid bool, MissingPaths array, and ErrorMessages array.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionDir,

        [Parameter(Mandatory = $true)]
        [string]$PackageJsonPath,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir
    )

    $missingPaths = @()
    $errorMessages = @()

    if (-not (Test-Path $ExtensionDir)) {
        $missingPaths += $ExtensionDir
        $errorMessages += "Extension directory not found: $ExtensionDir"
    }
    if (-not (Test-Path $PackageJsonPath)) {
        $missingPaths += $PackageJsonPath
        $errorMessages += "package.json not found: $PackageJsonPath"
    }
    if (-not (Test-Path $GitHubDir)) {
        $missingPaths += $GitHubDir
        $errorMessages += ".github directory not found: $GitHubDir"
    }

    return @{
        IsValid       = ($missingPaths.Count -eq 0)
        MissingPaths  = $missingPaths
        ErrorMessages = $errorMessages
    }
}

function Get-DiscoveredAgents {
    <#
    .SYNOPSIS
        Discovers chat agent files from the agents directory.
    .DESCRIPTION
        Discovery function that scans the agents directory for .agent.md files,
        filters by exclusion list, and returns structured agent objects.
    .PARAMETER AgentsDir
        Path to the agents directory.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER ExcludedAgents
        Array of agent names to exclude from packaging.
    .OUTPUTS
        [hashtable] With Agents array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentsDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludedAgents = @()
    )

    $result = @{
        Agents          = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $AgentsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $agentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" -Recurse | Sort-Object Name
    $agentFiles = $agentFiles | Where-Object { -not (Test-DeprecatedPath -Path $_.FullName) }

    foreach ($agentFile in $agentFiles) {
        $agentRelPath = [System.IO.Path]::GetRelativePath($AgentsDir, $agentFile.FullName) -replace '\\', '/'

        if (Test-HveCoreRepoSpecificPath -RelativePath $agentRelPath) {
            $agentName = $agentFile.BaseName -replace '\.agent$', ''
            $result.Skipped += @{ Name = $agentName; Reason = 'repo-specific (root-level)' }
            continue
        }

        $agentName = $agentFile.BaseName -replace '\.agent$', ''

        if ($ExcludedAgents -contains $agentName) {
            $result.Skipped += @{ Name = $agentName; Reason = 'excluded' }
            continue
        }

        $maturity = "stable"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $agentName; Reason = "maturity: $maturity" }
            continue
        }
        $result.Agents += [PSCustomObject]@{
            name = $agentName
            path = "./.github/agents/$agentRelPath"
        }
    }

    return $result
}

function Get-DiscoveredPrompts {
    <#
    .SYNOPSIS
        Discovers prompt files from the prompts directory.
    .DESCRIPTION
        Discovery function that scans the prompts directory for .prompt.md files,
        and returns structured prompt objects with relative paths.
    .PARAMETER PromptsDir
        Path to the prompts directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Prompts array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PromptsDir,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Prompts         = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $PromptsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $promptFiles = Get-ChildItem -Path $PromptsDir -Filter "*.prompt.md" -Recurse | Sort-Object Name
    $promptFiles = $promptFiles | Where-Object { -not (Test-DeprecatedPath -Path $_.FullName) }

    foreach ($promptFile in $promptFiles) {
        $promptName = $promptFile.BaseName -replace '\.prompt$', ''

        $promptRelPath = [System.IO.Path]::GetRelativePath($PromptsDir, $promptFile.FullName) -replace '\\', '/'
        if (Test-HveCoreRepoSpecificPath -RelativePath $promptRelPath) {
            $result.Skipped += @{ Name = $promptName; Reason = 'repo-specific (root-level)' }
            continue
        }

        $maturity = "stable"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $promptName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePath = [System.IO.Path]::GetRelativePath($GitHubDir, $promptFile.FullName) -replace '\\', '/'

        $result.Prompts += [PSCustomObject]@{
            name = $promptName
            path = "./.github/$relativePath"
        }
    }

    return $result
}

function Get-DiscoveredInstructions {
    <#
    .SYNOPSIS
        Discovers instruction files from the instructions directory.
    .DESCRIPTION
        Discovery function that scans the instructions directory for .instructions.md files,
        and returns structured instruction objects with normalized paths.
    .PARAMETER InstructionsDir
        Path to the instructions directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Instructions array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstructionsDir,

        [Parameter(Mandatory = $true)]
        [string]$GitHubDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Instructions    = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $InstructionsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $instructionFiles = Get-ChildItem -Path $InstructionsDir -Filter "*.instructions.md" -Recurse | Sort-Object Name
    $instructionFiles = $instructionFiles | Where-Object { -not (Test-DeprecatedPath -Path $_.FullName) }

    foreach ($instrFile in $instructionFiles) {
        $instrRelPath = [System.IO.Path]::GetRelativePath($InstructionsDir, $instrFile.FullName) -replace '\\', '/'
        if (Test-HveCoreRepoSpecificPath -RelativePath $instrRelPath) {
            $result.Skipped += @{ Name = $instrFile.BaseName; Reason = 'repo-specific (root-level)' }
            continue
        }
        $baseName = $instrFile.BaseName -replace '\.instructions$', ''
        $instrName = "$baseName-instructions"

        $maturity = "stable"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $instrName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePathFromGitHub = [System.IO.Path]::GetRelativePath($GitHubDir, $instrFile.FullName)
        $normalizedRelativePath = (Join-Path ".github" $relativePathFromGitHub) -replace '\\', '/'

        $result.Instructions += [PSCustomObject]@{
            name = $instrName
            path = "./$normalizedRelativePath"
        }
    }

    return $result
}

function Get-DiscoveredSkills {
    <#
    .SYNOPSIS
        Discovers skill packages from the skills directory.
    .DESCRIPTION
        Discovery function that scans the skills directory for subdirectories
        containing SKILL.md files and returns structured skill objects.
    .PARAMETER SkillsDir
        Path to the skills directory.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Skills array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
    )

    $result = @{
        Skills          = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $SkillsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $skillFiles = Get-ChildItem -Path $SkillsDir -Filter "SKILL.md" -File -Recurse | Sort-Object { $_.Directory.FullName }
    $skillFiles = $skillFiles | Where-Object { -not (Test-DeprecatedPath -Path $_.FullName) }

    foreach ($skillFile in $skillFiles) {
        $skillDir = $skillFile.Directory
        $skillName = $skillDir.Name
        $skillRelPath = [System.IO.Path]::GetRelativePath($SkillsDir, $skillDir.FullName) -replace '\\', '/'

        if (Test-HveCoreRepoSpecificPath -RelativePath $skillRelPath) {
            $result.Skipped += @{ Name = $skillName; Reason = 'repo-specific (root-level)' }
            continue
        }

        $maturity = "stable"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $skillName; Reason = "maturity: $maturity" }
            continue
        }

        $result.Skills += [PSCustomObject]@{
            name = $skillName
            path = "./.github/skills/$skillRelPath/SKILL.md"
        }
    }

    return $result
}

function Update-PackageJsonContributes {
    <#
    .SYNOPSIS
        Updates package.json contributes section with discovered components.
    .DESCRIPTION
        Pure function that takes a package.json object and discovered components,
        returning a new object with the contributes section updated. Handles
        chatAgents, chatPromptFiles, chatInstructions, and chatSkills.
    .PARAMETER PackageJson
        The package.json object to update.
    .PARAMETER ChatAgents
        Array of discovered chat agent objects.
    .PARAMETER ChatPromptFiles
        Array of discovered prompt objects.
    .PARAMETER ChatInstructions
        Array of discovered instruction objects.
    .PARAMETER ChatSkills
        Array of discovered skill objects.
    .OUTPUTS
        [PSCustomObject] Updated package.json object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$PackageJson,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatAgents,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatPromptFiles,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatInstructions,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$ChatSkills
    )

    # Clone the object to avoid modifying the original
    $updated = $PackageJson | ConvertTo-Json -Depth 10 | ConvertFrom-Json

    # Strip name and description; VS Code reads these from the files directly
    $ChatAgents = @($ChatAgents | Select-Object -Property path)
    $ChatPromptFiles = @($ChatPromptFiles | Select-Object -Property path)
    $ChatInstructions = @($ChatInstructions | Select-Object -Property path)
    $ChatSkills = @($ChatSkills | Select-Object -Property path)

    # Ensure contributes section exists
    if (-not $updated.contributes) {
        $updated | Add-Member -NotePropertyName "contributes" -NotePropertyValue ([PSCustomObject]@{})
    }

    # Add or update contributes properties
    if ($null -eq $updated.contributes.chatAgents) {
        $updated.contributes | Add-Member -NotePropertyName "chatAgents" -NotePropertyValue $ChatAgents -Force
    } else {
        $updated.contributes.chatAgents = $ChatAgents
    }

    if ($null -eq $updated.contributes.chatPromptFiles) {
        $updated.contributes | Add-Member -NotePropertyName "chatPromptFiles" -NotePropertyValue $ChatPromptFiles -Force
    } else {
        $updated.contributes.chatPromptFiles = $ChatPromptFiles
    }

    if ($null -eq $updated.contributes.chatInstructions) {
        $updated.contributes | Add-Member -NotePropertyName "chatInstructions" -NotePropertyValue $ChatInstructions -Force
    } else {
        $updated.contributes.chatInstructions = $ChatInstructions
    }

    if ($null -eq $updated.contributes.chatSkills) {
        $updated.contributes | Add-Member -NotePropertyName "chatSkills" -NotePropertyValue $ChatSkills -Force
    } else {
        $updated.contributes.chatSkills = $ChatSkills
    }

    return $updated
}

function New-PrepareResult {
    <#
    .SYNOPSIS
        Creates a standardized result object for extension preparation operations.
    .DESCRIPTION
        Factory function that creates a hashtable with consistent properties
        for reporting preparation operation outcomes.
    .PARAMETER Success
        Indicates whether the operation completed successfully.
    .PARAMETER Version
        The version string from package.json.
    .PARAMETER AgentCount
        Number of agents discovered and included.
    .PARAMETER PromptCount
        Number of prompts discovered and included.
    .PARAMETER InstructionCount
        Number of instructions discovered and included.
    .PARAMETER SkillCount
        Number of skills discovered and included.
    .PARAMETER ErrorMessage
        Error description when Success is false.
    .OUTPUTS
        Hashtable with Success, Version, AgentCount, PromptCount,
        InstructionCount, SkillCount, and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $false)]
        [string]$Version = "",

        [Parameter(Mandatory = $false)]
        [int]$AgentCount = 0,

        [Parameter(Mandatory = $false)]
        [int]$PromptCount = 0,

        [Parameter(Mandatory = $false)]
        [int]$InstructionCount = 0,

        [Parameter(Mandatory = $false)]
        [int]$SkillCount = 0,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ""
    )

    return @{
        Success          = $Success
        Version          = $Version
        AgentCount       = $AgentCount
        PromptCount      = $PromptCount
        InstructionCount = $InstructionCount
        SkillCount       = $SkillCount
        ErrorMessage     = $ErrorMessage
    }
}

function Test-TemplateConsistency {
    <#
    .SYNOPSIS
        Validates collection template metadata against its collection manifest.
    .DESCRIPTION
        Compares name, displayName, and description fields between a collection
        package template (e.g. package.developer.json) and the corresponding
        collection manifest. Emits warnings for divergences and returns a list
        of mismatches.
    .PARAMETER TemplatePath
        Path to the collection package template JSON file.
    .PARAMETER CollectionManifest
        Parsed collection manifest hashtable with name, displayName, description.
    .OUTPUTS
        [hashtable] With Mismatches array and IsConsistent bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest
    )

    $result = @{
        Mismatches   = @()
        IsConsistent = $true
    }

    if (-not (Test-Path $TemplatePath)) {
        $result.Mismatches += @{
            Field    = 'file'
            Template = $TemplatePath
            Manifest = 'N/A'
            Message  = "Template file not found: $TemplatePath"
        }
        $result.IsConsistent = $false
        return $result
    }

    try {
        $template = Get-Content -Path $TemplatePath -Raw | ConvertFrom-Json
    }
    catch {
        $result.Mismatches += @{
            Field    = 'file'
            Template = $TemplatePath
            Manifest = 'N/A'
            Message  = "Failed to parse template: $($_.Exception.Message)"
        }
        $result.IsConsistent = $false
        return $result
    }

    $fieldsToCheck = @('name', 'displayName', 'description')
    foreach ($field in $fieldsToCheck) {
        $templateValue = $null
        $manifestValue = $null

        if ($template.PSObject.Properties[$field]) {
            $templateValue = $template.$field
        }
        if ($CollectionManifest.ContainsKey($field)) {
            $manifestValue = $CollectionManifest[$field]
        }

        if ($null -ne $templateValue -and $null -ne $manifestValue -and $templateValue -ne $manifestValue) {
            $result.Mismatches += @{
                Field    = $field
                Template = $templateValue
                Manifest = $manifestValue
                Message  = "$field diverges: template='$templateValue' manifest='$manifestValue'"
            }
            $result.IsConsistent = $false
        }
    }

    return $result
}

function Write-ManifestReviewArtifact {
    <#
    .SYNOPSIS
        Emits the projected collection manifest(s) to a review folder.
    .DESCRIPTION
        Renders the projected `.collection.yml` and `.collection.md` for a
        collection from collections/core-manifest.yml and writes them to
        `<OutputRoot>/<collection-id>/`. The serialization mirrors the committed
        collection render (ordered projection, deterministic YAML, UTF-8 without
        a trailing newline), so the emitted content matches what is packaged and
        can be reviewed before marketplace gating.
    .PARAMETER RepoRoot
        Absolute path to the repository root containing
        collections/core-manifest.yml.
    .PARAMETER CollectionId
        Collection identifier to render (e.g., 'ado', 'hve-core').
    .PARAMETER OutputRoot
        Root directory for the review output. A per-collection subfolder named
        after CollectionId is created beneath it.
    .OUTPUTS
        [string[]] Paths of the written review files (yaml, markdown).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputRoot
    )

    $coreManifestPath = Join-Path $RepoRoot 'collections/core-manifest.yml'
    $coreManifest = Read-CoreManifest -ManifestPath $coreManifestPath

    $manifest = ConvertTo-CollectionManifestFromCore -CoreManifest $coreManifest -CollectionId $CollectionId -RepoRoot $RepoRoot
    $projectedYaml = ConvertTo-Yaml -Data $manifest
    $projectedMd = New-CollectionReadmeBodyFromCore -CoreManifest $coreManifest -CollectionId $CollectionId -RepoRoot $RepoRoot

    $collectionDir = Join-Path $OutputRoot $CollectionId
    if (-not (Test-Path -LiteralPath $collectionDir)) {
        New-Item -ItemType Directory -Path $collectionDir -Force | Out-Null
    }

    $yamlPath = Join-Path $collectionDir "$CollectionId.collection.yml"
    $mdPath = Join-Path $collectionDir "$CollectionId.collection.md"

    Set-Content -LiteralPath $yamlPath -Value $projectedYaml -Encoding utf8 -NoNewline
    Set-Content -LiteralPath $mdPath -Value $projectedMd -Encoding utf8 -NoNewline

    return @($yamlPath, $mdPath)
}

function Invoke-PrepareExtension {
    <#
    .SYNOPSIS
        Orchestrates VS Code extension preparation with full error handling.
    .DESCRIPTION
        Executes the complete preparation workflow: validates paths, discovers
        agents/prompts/instructions, updates package.json, and handles changelog.
        Returns a result object instead of using exit codes.
    .PARAMETER ExtensionDirectory
        Absolute path to the extension directory containing package.json.
    .PARAMETER RepoRoot
        Absolute path to the repository root directory.
    .PARAMETER Channel
        Release channel controlling maturity filter ('Stable' or 'PreRelease').
    .PARAMETER ChangelogPath
        Optional path to changelog file to include.
    .PARAMETER DryRun
        When specified, shows what would be done without making changes.
    .PARAMETER Collection
        Optional collection identifier (e.g., 'ado', 'hve-core') used to pin
        per-channel package.json metadata for the targeted collection.
    .PARAMETER ManifestReviewPath
        Optional. Output root for the pre-package manifest review artifacts.
        Rendered manifest(s) are written to `<ManifestReviewPath>/<collection-id>/`.
        Defaults to `<ExtensionDirectory>/manifest-review` when not specified.
    .OUTPUTS
        Hashtable with Success, Version, AgentCount, PromptCount,
        InstructionCount, SkillCount, and ErrorMessage properties.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExtensionDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'Stable',

        [Parameter(Mandatory = $false)]
        [string]$ChangelogPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [string]$Collection = "",

        [Parameter(Mandatory = $false)]
        [string]$ManifestReviewPath = ""
    )

    # Derive paths
    $GitHubDir = Join-Path $RepoRoot ".github"
    $PackageJsonPath = Join-Path $ExtensionDirectory "package.json"

    if ([string]::IsNullOrWhiteSpace($ManifestReviewPath)) {
        $ManifestReviewPath = Join-Path $ExtensionDirectory 'manifest-review'
    }

    # Generate collection package files from root collection manifests.
    # This ensures extension/package.json and extension/package.*.json exist
    # with the correct version from the template before any reads occur.
    try {
        $generated = Invoke-ExtensionCollectionsGeneration -RepoRoot $RepoRoot -Channel $Channel -Prune:$Prune
        Write-Host "Generated $($generated.Count) collection package file(s)" -ForegroundColor Green
    }
    catch {
        return New-PrepareResult -Success $false -ErrorMessage "Package generation failed: $($_.Exception.Message)"
    }

    # Validate required paths exist (package.json now guaranteed by generation)
    $pathValidation = Test-PathsExist -ExtensionDir $ExtensionDirectory `
        -PackageJsonPath $PackageJsonPath `
        -GitHubDir $GitHubDir
    if (-not $pathValidation.IsValid) {
        $missingPaths = $pathValidation.MissingPaths -join ', '
        return New-PrepareResult -Success $false -ErrorMessage "Required paths not found: $missingPaths"
    }

    # Read and parse package.json
    try {
        $packageJsonContent = Get-Content -Path $PackageJsonPath -Raw
        $packageJson = $packageJsonContent | ConvertFrom-Json
    }
    catch {
        return New-PrepareResult -Success $false -ErrorMessage "Failed to parse package.json at '$PackageJsonPath'. Check the file for JSON syntax errors. Underlying error: $($_.Exception.Message)"
    }

    # Validate version field
    if (-not $packageJson.PSObject.Properties['version']) {
        return New-PrepareResult -Success $false -ErrorMessage "package.json does not contain a 'version' field"
    }
    $version = $packageJson.version
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        return New-PrepareResult -Success $false -ErrorMessage "Invalid version format in package.json: $version"
    }

    # Get allowed maturities for channel
    $allowedMaturities = Get-AllowedMaturities -Channel $Channel

    Write-Host "`n=== Prepare Extension ===" -ForegroundColor Cyan
    Write-Host "Extension Directory: $ExtensionDirectory"
    Write-Host "Repository Root: $RepoRoot"
    Write-Host "Channel: $Channel"
    Write-Host "Allowed Maturities: $($allowedMaturities -join ', ')"
    Write-Host "Version: $version"
    if ($DryRun) {
        Write-Host "[DRY RUN] No changes will be made" -ForegroundColor Yellow
    }

    # Load collection manifest if specified
    $collectionManifest = $null
    $collectionArtifactNames = $null
    $collectionMaturities = @{}
    $collectionRequires = @{}

    if ($Collection -and $Collection -ne "") {
        $collectionManifest = Get-CollectionManifest -CollectionPath $Collection
        Write-Host "Collection: $($collectionManifest.displayName) ($($collectionManifest.id))"

        # Recompute allowed maturities now that the collection id is known so that
        # experimental assets are gated to the 'hve-core-all' collection.
        $allowedMaturities = Get-AllowedMaturities -Channel $Channel -CollectionId ([string]$collectionManifest.id)
        Write-Host "Allowed Maturities (collection-scoped): $($allowedMaturities -join ', ')"

        $artifactCollectionManifest = $collectionManifest
        if (-not $artifactCollectionManifest.ContainsKey('items') -or @($artifactCollectionManifest.items).Count -eq 0) {
            # When the manifest lacks items (e.g., a generated JSON template),
            # resolve from the root YAML collection by ID.
            $rootCollectionPath = Join-Path $RepoRoot "collections/$($collectionManifest.id).collection.yml"
            if (Test-Path $rootCollectionPath) {
                $artifactCollectionManifest = Get-CollectionManifest -CollectionPath $rootCollectionPath
                Write-Host "Using root collection for items: $rootCollectionPath"
            }
            else {
                Write-Warning "No root collection found for '$($collectionManifest.id)' at $rootCollectionPath"
            }
        }

        # Check collection-level maturity eligibility
        $collectionEligibility = Test-CollectionMaturityEligible -CollectionManifest $collectionManifest -Channel $Channel
        if (-not $collectionEligibility.IsEligible) {
            Write-Host "`n⏭️  $($collectionEligibility.Reason)" -ForegroundColor Yellow
            return New-PrepareResult -Success $true -Version $version
        }

        $collectionMaturity = if ($collectionManifest.ContainsKey('maturity')) { $collectionManifest['maturity'] } else { 'stable' }
        Write-Host "Collection maturity: $collectionMaturity"

        # Emit the projected manifest(s) to the review folder so the exact content
        # that ships in the vsix can be reviewed before marketplace gating.
        if ($DryRun) {
            Write-Host "[DRY RUN] Would write manifest review artifact to $ManifestReviewPath" -ForegroundColor Yellow
        }
        else {
            try {
                $reviewFiles = Write-ManifestReviewArtifact -RepoRoot $RepoRoot -CollectionId ([string]$collectionManifest.id) -OutputRoot $ManifestReviewPath
                Write-Host "Wrote manifest review artifact(s):" -ForegroundColor Green
                foreach ($reviewFile in $reviewFiles) { Write-Host "  $reviewFile" }
            }
            catch {
                Write-Warning "Failed to write manifest review artifact for '$($collectionManifest.id)': $($_.Exception.Message)"
            }
        }

        # Build collection maturity map and channel-filtered artifact names
        $collectionMaturities = @{}
        $collectionRequires = @{}

        if ($artifactCollectionManifest.ContainsKey('items')) {
            foreach ($item in $artifactCollectionManifest.items) {
                if (-not $item.ContainsKey('kind') -or -not $item.ContainsKey('path')) {
                    continue
                }

                $itemKind = [string]$item.kind
                $itemPath = [string]$item.path
                $artifactKey = Get-CollectionArtifactKey -Kind $itemKind -Path $itemPath
                $effectiveMaturity = Resolve-CollectionItemMaturity -Maturity $item.maturity
                if (-not $collectionMaturities.ContainsKey("${itemKind}s") -or $null -eq $collectionMaturities["${itemKind}s"]) {
                    $collectionMaturities["${itemKind}s"] = @{}
                }
                $collectionMaturities["${itemKind}s"][$artifactKey] = $effectiveMaturity

                if ($item.ContainsKey('requires') -and $item.requires) {
                    if (-not $collectionRequires.ContainsKey("${itemKind}s") -or $null -eq $collectionRequires["${itemKind}s"]) {
                        $collectionRequires["${itemKind}s"] = @{}
                    }
                    $collectionRequires["${itemKind}s"][$artifactKey] = $item.requires
                }
            }
        }

        $collectionArtifactNames = Get-CollectionArtifacts -Collection $artifactCollectionManifest -AllowedMaturities $allowedMaturities

        # Resolve handoff dependencies (agents only)
        if (@($collectionArtifactNames.Agents).Count -gt 0) {
            $agentsDir = Join-Path $GitHubDir "agents"
            $expandedAgents = Resolve-HandoffDependencies -SeedAgents $collectionArtifactNames.Agents -AgentsDir $agentsDir
            $collectionArtifactNames.Agents = $expandedAgents
        }

        # Resolve requires dependencies
        $resolvedNames = Resolve-RequiresDependencies -ArtifactNames @{
            agents       = $collectionArtifactNames.Agents
            prompts      = $collectionArtifactNames.Prompts
            instructions = $collectionArtifactNames.Instructions
            skills       = $collectionArtifactNames.Skills
        } -AllowedMaturities $allowedMaturities -CollectionRequires $collectionRequires -CollectionMaturities $collectionMaturities

        $collectionArtifactNames = @{
            Agents       = $resolvedNames.Agents
            Prompts      = $resolvedNames.Prompts
            Instructions = $resolvedNames.Instructions
            Skills       = $resolvedNames.Skills
        }
    }

    # Discover artifacts
    $discoveryAllowedMaturities = if ($null -ne $collectionArtifactNames) {
        @('stable', 'preview', 'experimental', 'deprecated')
    }
    else {
        $allowedMaturities
    }

    $agentsDir = Join-Path $GitHubDir "agents"
    $agentResult = Get-DiscoveredAgents -AgentsDir $agentsDir -AllowedMaturities $discoveryAllowedMaturities -ExcludedAgents @()
    $chatAgents = $agentResult.Agents
    $excludedAgents = $agentResult.Skipped

    Write-Host "`n--- Chat Agents ---" -ForegroundColor Green
    Write-Host "Found $($chatAgents.Count) agent(s) matching criteria"
    if ($excludedAgents.Count -gt 0) {
        Write-Host "Excluded $($excludedAgents.Count) agent(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover prompts
    $promptsDir = Join-Path $GitHubDir "prompts"
    $promptResult = Get-DiscoveredPrompts -PromptsDir $promptsDir -GitHubDir $GitHubDir -AllowedMaturities $discoveryAllowedMaturities
    $chatPrompts = $promptResult.Prompts
    $excludedPrompts = $promptResult.Skipped

    Write-Host "`n--- Chat Prompts ---" -ForegroundColor Green
    Write-Host "Found $($chatPrompts.Count) prompt(s) matching criteria"
    if ($excludedPrompts.Count -gt 0) {
        Write-Host "Excluded $($excludedPrompts.Count) prompt(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover instructions
    $instructionsDir = Join-Path $GitHubDir "instructions"
    $instructionResult = Get-DiscoveredInstructions -InstructionsDir $instructionsDir -GitHubDir $GitHubDir -AllowedMaturities $discoveryAllowedMaturities
    $chatInstructions = $instructionResult.Instructions
    $excludedInstructions = $instructionResult.Skipped

    Write-Host "`n--- Chat Instructions ---" -ForegroundColor Green
    Write-Host "Found $($chatInstructions.Count) instruction(s) matching criteria"
    if ($excludedInstructions.Count -gt 0) {
        Write-Host "Excluded $($excludedInstructions.Count) instruction(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover skills
    $skillsDir = Join-Path $GitHubDir "skills"
    $skillResult = Get-DiscoveredSkills -SkillsDir $skillsDir -AllowedMaturities $discoveryAllowedMaturities
    $chatSkills = $skillResult.Skills
    $excludedSkills = $skillResult.Skipped

    Write-Host "`n--- Chat Skills ---" -ForegroundColor Green
    Write-Host "Found $($chatSkills.Count) skill(s) matching criteria"
    if ($excludedSkills.Count -gt 0) {
        Write-Host "Excluded $($excludedSkills.Count) skill(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Apply collection filtering to discovered artifacts
    if ($null -ne $collectionArtifactNames) {
        $chatAgents = @($chatAgents | Where-Object { $collectionArtifactNames.Agents -contains $_.name })
        $chatPrompts = @($chatPrompts | Where-Object { $collectionArtifactNames.Prompts -contains $_.name })
        $instrBaseNames = @($collectionArtifactNames.Instructions | ForEach-Object { ($_ -split '/')[-1] })
        $chatInstructions = @($chatInstructions | Where-Object {
            $instrBaseName = $_.name -replace '-instructions$', ''
            $instrBaseNames -contains $instrBaseName
        })
        $chatSkills = @($chatSkills | Where-Object { $collectionArtifactNames.Skills -contains $_.name })

        Write-Host "`n--- Collection Filtering ---" -ForegroundColor Magenta
        Write-Host "Agents after filter: $($chatAgents.Count)"
        Write-Host "Prompts after filter: $($chatPrompts.Count)"
        Write-Host "Instructions after filter: $($chatInstructions.Count)"
        Write-Host "Skills after filter: $($chatSkills.Count)"
    }

    # Apply collection template when building a non-default collection
    if ($null -ne $collectionManifest -and $collectionManifest.id -ne 'hve-core') {
        $collectionId = $collectionManifest.id
        $templatePath = Join-Path $ExtensionDirectory "package.$collectionId.json"
        if (-not (Test-Path $templatePath)) {
            return New-PrepareResult -Success $false -ErrorMessage "Collection template not found: $templatePath"
        }

        # Validate template consistency against collection manifest
        $consistency = Test-TemplateConsistency -TemplatePath $templatePath -CollectionManifest $collectionManifest
        if (-not $consistency.IsConsistent) {
            Write-Host "`n--- Template Consistency Warnings ---" -ForegroundColor Yellow
            foreach ($mismatch in $consistency.Mismatches) {
                Write-Warning "Template/manifest mismatch: $($mismatch.Message)"
                Write-CIAnnotation -Message "Template/manifest mismatch ($collectionId): $($mismatch.Message)" -Level Warning
            }
        }

        # Back up canonical package.json for later restore
        $backupPath = Join-Path $ExtensionDirectory "package.json.bak"
        Copy-Item -Path $PackageJsonPath -Destination $backupPath -Force

        # Copy collection template over package.json
        Copy-Item -Path $templatePath -Destination $PackageJsonPath -Force

        # Re-read template as the working package.json
        $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
        Write-Host "Applied collection template: package.$collectionId.json" -ForegroundColor Green
    }

    # Update package.json with generated contributes
    $packageJson = Update-PackageJsonContributes -PackageJson $packageJson `
        -ChatAgents $chatAgents `
        -ChatPromptFiles $chatPrompts `
        -ChatInstructions $chatInstructions `
        -ChatSkills $chatSkills

    # Write updated package.json
    if (-not $DryRun) {
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
        Write-Host "`nUpdated package.json with discovered artifacts" -ForegroundColor Green
    }
    else {
        Write-Host "`n[DRY RUN] Would update package.json with discovered artifacts" -ForegroundColor Yellow
    }

    # Handle changelog
    if ($ChangelogPath -and (Test-Path $ChangelogPath)) {
        $destChangelog = Join-Path $ExtensionDirectory "CHANGELOG.md"
        if (-not $DryRun) {
            Copy-Item -Path $ChangelogPath -Destination $destChangelog -Force
            Write-Host "Copied changelog to extension directory" -ForegroundColor Green
        }
        else {
            Write-Host "[DRY RUN] Would copy changelog to extension directory" -ForegroundColor Yellow
        }
    }
    elseif ($ChangelogPath) {
        Write-Warning "Changelog path specified but file not found: $ChangelogPath"
    }

    Write-Host "`n=== Preparation Complete ===" -ForegroundColor Cyan

    return New-PrepareResult -Success $true `
        -Version $version `
        -AgentCount $chatAgents.Count `
        -PromptCount $chatPrompts.Count `
        -InstructionCount $chatInstructions.Count `
        -SkillCount $chatSkills.Count
}

#endregion Pure Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module is available
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths using $MyInvocation (must stay in entry point)
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName
        $ExtensionDir = Join-Path $RepoRoot "extension"

        # Resolve changelog path if provided
        $resolvedChangelogPath = ""
        if ($ChangelogPath) {
            $resolvedChangelogPath = if ([System.IO.Path]::IsPathRooted($ChangelogPath)) {
                $ChangelogPath
            }
            else {
                Join-Path $RepoRoot $ChangelogPath
            }
        }

        # Default to hve-core collection when no collection is specified.
        # package.json is identity-mapped to the hve-core collection, so the
        # default build must apply hve-core filtering rather than including all
        # artifacts (hve-core-all behavior). Use -Collection with
        # hve-core-all.collection.yml explicitly to include everything.
        if (-not $Collection) {
            $Collection = Join-Path $RepoRoot 'collections/hve-core.collection.yml'
        }

        Write-Host "📦 HVE Core Extension Preparer" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host "   Channel: $Channel" -ForegroundColor Cyan
        Write-Host "   Collection: $Collection" -ForegroundColor Cyan
        Write-Host ""

        # Resolve manifest review output path. Default to <extension>/manifest-review
        # and resolve relative overrides against the repository root.
        $resolvedManifestReviewPath = $ManifestReviewPath
        if ([string]::IsNullOrWhiteSpace($resolvedManifestReviewPath)) {
            $resolvedManifestReviewPath = Join-Path $ExtensionDir 'manifest-review'
        }
        elseif (-not [System.IO.Path]::IsPathRooted($resolvedManifestReviewPath)) {
            $resolvedManifestReviewPath = Join-Path $RepoRoot $resolvedManifestReviewPath
        }

        # Call orchestration function
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $ExtensionDir `
            -RepoRoot $RepoRoot `
            -Channel $Channel `
            -ChangelogPath $resolvedChangelogPath `
            -DryRun:$DryRun `
            -Collection $Collection `
            -ManifestReviewPath $resolvedManifestReviewPath

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        Write-Host ""
        Write-Host "🎉 Done!" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 Summary:" -ForegroundColor Cyan
        Write-Host "  Agents: $($result.AgentCount)"
        Write-Host "  Prompts: $($result.PromptCount)"
        Write-Host "  Instructions: $($result.InstructionCount)"
        Write-Host "  Skills: $($result.SkillCount)"
        Write-Host "  Version: $($result.Version)"

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Prepare-Extension failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
