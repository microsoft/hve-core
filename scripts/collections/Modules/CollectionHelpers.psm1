# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# CollectionHelpers.psm1
#
# Purpose: Collection helpers - YAML parsing, validation, and shared collection utilities.
# Author: HVE Core Team

#Requires -Version 7.0
#Requires -Modules PowerShell-Yaml

# ---------------------------------------------------------------------------
# Marker Constants (shared across collection scripts)
# ---------------------------------------------------------------------------
$script:CollectionMdBeginMarker = '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
$script:CollectionMdEndMarker = '<!-- END AUTO-GENERATED ARTIFACTS -->'

# ---------------------------------------------------------------------------
# Internal Utilities
# ---------------------------------------------------------------------------

function Set-ContentIfChanged {
    <#
    .SYNOPSIS
        Writes content to a file only when the content has changed.
    .DESCRIPTION
        Compares the provided value against the existing file content using
        case-sensitive ordinal comparison. Writes only when the file does not
        exist or content differs, preserving the git stat cache for unchanged files.
    .PARAMETER Path
        The file path to write.
    .PARAMETER Value
        The content to write.
    .OUTPUTS
        [bool] True if the file was written, false if skipped.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ([string]::Equals($existing, $Value, [System.StringComparison]::Ordinal)) {
            return $false
        }
    }
    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Value -Encoding utf8NoBOM -NoNewline
    return $true
}

# ---------------------------------------------------------------------------
# Pure Functions (no file system side effects)
# ---------------------------------------------------------------------------

function Test-DeprecatedPath {
    <#
    .SYNOPSIS
    Checks whether a file path contains a deprecated directory segment.

    .DESCRIPTION
    Returns true when the path contains a /deprecated/ or \deprecated\ segment,
    indicating the artifact resides in a deprecated directory tree.

    .PARAMETER Path
    File path to check (absolute or relative, any slash style).

    .OUTPUTS
    [bool] True when the path contains a deprecated segment.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return ($Path -match '[/\\]deprecated[/\\]')
}

function Test-HveCoreRepoSpecificPath {
    <#
    .SYNOPSIS
    Checks whether a type-relative path is a root-level repo-specific artifact.

    .DESCRIPTION
    Returns true when the type-relative path has no subdirectory component,
    indicating it is a root-level repo-specific artifact not intended for
    distribution. Collection-scoped artifacts reside in subdirectories.

    .PARAMETER RelativePath
    Type-relative path (relative to the agents/, prompts/, instructions/, or skills/ directory).

    .OUTPUTS
    [bool] True when the path is repo-specific.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    return ($RelativePath -notlike '*/*')
}

function Test-HveCoreRepoRelativePath {
    <#
    .SYNOPSIS
    Checks whether a repo-relative path is a root-level repo-specific artifact.

    .DESCRIPTION
    Returns true when the repo-relative path is directly under a .github type
    directory (agents, instructions, prompts, skills) with no subdirectory,
    indicating it is a root-level repo-specific artifact not intended for distribution.

    .PARAMETER Path
    Repo-relative path (e.g., .github/instructions/workflows.instructions.md).

    .OUTPUTS
    [bool] True when the path is a root-level repo-specific artifact.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return ($Path -match '^\.github/(agents|instructions|prompts|skills)/[^/]+$')
}

function Get-CollectionManifest {
    <#
    .SYNOPSIS
    Loads a collection manifest from a YAML or JSON file.

    .DESCRIPTION
    Reads and parses a collection manifest file that defines collection-based
    artifact filtering rules. Supports both YAML (.yml/.yaml) and JSON (.json)
    formats.

    .PARAMETER CollectionPath
    Path to the collection manifest file (YAML or JSON).

    .OUTPUTS
    [hashtable] Parsed collection manifest with id, name, displayName, description, items, and optional include/exclude.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CollectionPath
    )

    if (-not (Test-Path $CollectionPath)) {
        throw "Collection manifest not found: $CollectionPath"
    }

    $extension = [System.IO.Path]::GetExtension($CollectionPath).ToLowerInvariant()
    if ($extension -in @('.yml', '.yaml')) {
        $content = Get-Content -Path $CollectionPath -Raw
        return ConvertFrom-Yaml -Yaml $content
    }

    $content = Get-Content -Path $CollectionPath -Raw
    return $content | ConvertFrom-Json -AsHashtable
}

function Get-CollectionArtifactKey {
    <#
    .SYNOPSIS
        Extracts a unique key from an artifact path based on its kind.

    .DESCRIPTION
        Produces the same key that extension packaging uses for deduplication.
        Agents and prompts use the filename only; instructions use the
        type-relative path; skills use the directory name.

    .PARAMETER Kind
        The artifact kind (agent, prompt, instruction, skill).

    .PARAMETER Path
        The repo-relative artifact path.

    .OUTPUTS
        [string] The artifact key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    switch ($Kind) {
        'agent' {
            return ([System.IO.Path]::GetFileName($Path) -replace '\.agent\.md$', '')
        }
        'prompt' {
            return ([System.IO.Path]::GetFileName($Path) -replace '\.prompt\.md$', '')
        }
        'instruction' {
            return ($Path -replace '^\.github/instructions/', '' -replace '\.instructions\.md$', '')
        }
        'skill' {
            return [System.IO.Path]::GetFileName($Path.TrimEnd('/'))
        }
        default {
            if ($Path -match "\.$([regex]::Escape($Kind))\.md$") {
                return ([System.IO.Path]::GetFileName($Path) -replace "\.$([regex]::Escape($Kind))\.md$", '')
            }

            if ($Path -like '*.md') {
                return [System.IO.Path]::GetFileNameWithoutExtension($Path)
            }

            return [System.IO.Path]::GetFileName($Path)
        }
    }
}

function Get-ArtifactFrontmatter {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a markdown file.

    .DESCRIPTION
    Parses the YAML frontmatter block delimited by --- markers at the start
    of a markdown file. Returns a hashtable with description.

    .PARAMETER FilePath
    Path to the markdown file to parse.

    .PARAMETER FallbackDescription
    Default description if none found in frontmatter.

    .OUTPUTS
    [hashtable] With description key.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$FallbackDescription = ''
    )

    $content = Get-Content -Path $FilePath -Raw
    $description = ''

    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
            if ($data.ContainsKey('description')) {
                $description = $data.description
            }
        }
        catch {
            Write-Warning "Failed to parse YAML frontmatter in $(Split-Path -Leaf $FilePath): $_"
        }
    }

    return @{
        description = if ($description) { $description } else { $FallbackDescription }
    }
}

function Resolve-CollectionItemMaturity {
    <#
    .SYNOPSIS
    Resolves effective maturity from collection item metadata.

    .DESCRIPTION
    Returns stable when maturity is omitted; otherwise returns the provided
    maturity string.

    .PARAMETER Maturity
    Optional maturity value from a collection item.

    .OUTPUTS
    [string] Effective maturity value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity
    )

    if ([string]::IsNullOrWhiteSpace($Maturity)) {
        return 'stable'
    }

    return $Maturity
}

function Get-AllCollections {
    <#
    .SYNOPSIS
    Discovers and parses all .collection.yml files in a directory.

    .DESCRIPTION
    Scans the specified directory for files matching *.collection.yml and
    parses each one into a hashtable via Get-CollectionManifest.

    .PARAMETER CollectionsDir
    Path to the directory containing .collection.yml files.

    .OUTPUTS
    [hashtable[]] Array of parsed collection manifests.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionsDir
    )

    $files = Get-ChildItem -Path $CollectionsDir -Filter '*.collection.yml' -File
    $collections = @()

    foreach ($file in $files) {
        $manifest = Get-CollectionManifest -CollectionPath $file.FullName
        $collections += $manifest
    }

    return $collections
}

# ---------------------------------------------------------------------------
# I/O Functions (file system operations)
# ---------------------------------------------------------------------------

function Get-ArtifactFiles {
    <#
    .SYNOPSIS
    Discovers all artifact files from .github/ directories.

    .DESCRIPTION
    Scans .github/agents/, .github/prompts/, .github/instructions/ (recursively),
    and .github/skills/ to build a complete list of collection items. Returns
    repo-relative paths with forward slashes.

    .PARAMETER RepoRoot
    Absolute path to the repository root directory.

    .OUTPUTS
    [hashtable[]] Array of hashtables with path and kind keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $items = @()

    # AI artifacts discovered by .<kind>.md suffix under .github/
    # Keep explicit suffix mapping only where naming differs from manifest kind values.
    $gitHubDir = Join-Path -Path $RepoRoot -ChildPath '.github'
    if (Test-Path -Path $gitHubDir) {
        $suffixToKind = @{
            instructions = 'instruction'
        }

        $artifactFiles = Get-ChildItem -Path $gitHubDir -Filter '*.*.md' -File -Recurse
        foreach ($file in $artifactFiles) {
            if ($file.Name -notmatch '\.(?<suffix>[^.]+)\.md$') {
                continue
            }

            $suffix = $Matches['suffix'].ToLowerInvariant()
            $kind = if ($suffixToKind.ContainsKey($suffix)) { $suffixToKind[$suffix] } else { $suffix }
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'

            if (Test-HveCoreRepoRelativePath -Path $relativePath) {
                continue
            }
            if (Test-DeprecatedPath -Path $relativePath) {
                continue
            }
            $items += @{ path = $relativePath; kind = $kind }
        }
    }

    # Skills (directories containing SKILL.md)
    $skillsDir = Join-Path -Path $RepoRoot -ChildPath '.github/skills'
    if (Test-Path -Path $skillsDir) {
        $skillMdFiles = Get-ChildItem -Path $skillsDir -Filter 'SKILL.md' -File -Recurse
        foreach ($skillFile in $skillMdFiles) {
            $dir = $skillFile.Directory
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $dir.FullName) -replace '\\', '/'

            if (Test-DeprecatedPath -Path $relativePath) {
                continue
            }
            if (Test-HveCoreRepoRelativePath -Path $relativePath) {
                continue
            }

            $items += @{ path = $relativePath; kind = 'skill' }
        }
    }

    return $items
}

function Test-ArtifactDeprecated {
    <#
    .SYNOPSIS
    Checks whether an artifact has maturity deprecated in collection metadata.

    .DESCRIPTION
    Reads maturity from the provided collection item metadata value and
    returns $true when the effective value equals deprecated.

    .PARAMETER Maturity
    Optional maturity value from collection item metadata.

    .OUTPUTS
    [bool] True when the artifact is deprecated.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity
    )

    return ((Resolve-CollectionItemMaturity -Maturity $Maturity) -eq 'deprecated')
}

function Update-HveCoreAllCollection {
    <#
    .SYNOPSIS
    Auto-updates hve-core-all.collection.yml with all non-deprecated artifacts.

    .DESCRIPTION
    Discovers all artifacts from .github/ directories, excludes deprecated items,
    and rewrites the hve-core-all collection manifest. Preserves existing
    metadata fields (id, name, description, tags, display).

    .PARAMETER RepoRoot
    Absolute path to the repository root directory.

    .PARAMETER DryRun
    When specified, logs changes without writing to disk.

    .OUTPUTS
    [hashtable] With ItemCount, AddedCount, RemovedCount, and DeprecatedCount keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $collectionPath = Join-Path -Path $RepoRoot -ChildPath 'collections/hve-core-all.collection.yml'

    # Read existing manifest to preserve metadata
    $existing = Get-CollectionManifest -CollectionPath $collectionPath
    $existingPaths = @($existing.items | ForEach-Object { $_.path })

    # Discover all artifacts
    $allItems = Get-ArtifactFiles -RepoRoot $RepoRoot

    # Exclude deprecated items by path (independent of maturity metadata)
    $allItems = @($allItems | Where-Object { -not (Test-DeprecatedPath -Path $_.path) })

    # Filter deprecated based on existing collection item maturity metadata
    $existingItemMaturities = @{}
    foreach ($existingItem in $existing.items) {
        $existingKey = "$($existingItem.kind)|$($existingItem.path)"
        $existingItemMaturities[$existingKey] = Resolve-CollectionItemMaturity -Maturity $existingItem.maturity
    }

    $deprecatedCount = 0
    $filteredItems = @()
    foreach ($item in $allItems) {
        $itemKey = "$($item.kind)|$($item.path)"
        $itemMaturity = 'stable'
        if ($existingItemMaturities.ContainsKey($itemKey)) {
            $itemMaturity = $existingItemMaturities[$itemKey]
        }

        if (Test-ArtifactDeprecated -Maturity $itemMaturity) {
            $deprecatedCount++
            Write-Verbose "Excluding deprecated: $($item.path)"
            continue
        }

        $filteredItems += @{
            path     = $item.path
            kind     = $item.kind
            maturity = $itemMaturity
        }
    }

    # Sort: known kinds first, then any additional kinds, then by path
    $kindOrder = @{ 'agent' = 0; 'prompt' = 1; 'instruction' = 2; 'skill' = 3 }
    $sortedItems = $filteredItems | Sort-Object `
        { if ($kindOrder.ContainsKey($_.kind)) { $kindOrder[$_.kind] } else { 100 } }, `
        { $_.kind }, `
        { $_.path }

    # Build new items array as ordered hashtables for clean YAML output
    $newItems = @()
    foreach ($item in $sortedItems) {
        $newItem = [ordered]@{
            path = $item.path
            kind = $item.kind
        }

        if ((Resolve-CollectionItemMaturity -Maturity $item.maturity) -ne 'stable') {
            $newItem['maturity'] = $item.maturity
        }

        $newItems += $newItem
    }

    # Compute diff
    $newPaths = @($sortedItems | ForEach-Object { $_.path })
    $added = @($newPaths | Where-Object { $_ -notin $existingPaths })
    $removed = @($existingPaths | Where-Object { $_ -notin $newPaths })

    Write-Host "`n--- hve-core-all Auto-Update ---" -ForegroundColor Cyan
    Write-Host "  Discovered: $($allItems.Count) artifacts"
    Write-Host "  Deprecated: $deprecatedCount (excluded)"
    Write-Host "  Final: $($newItems.Count) items"
    if ($added.Count -gt 0) {
        Write-Host "  Added: $($added -join ', ')" -ForegroundColor Green
    }
    if ($removed.Count -gt 0) {
        Write-Host "  Removed: $($removed -join ', ')" -ForegroundColor Yellow
    }

    if ($DryRun) {
        Write-Host '  [DRY RUN] No changes written' -ForegroundColor Yellow
    }
    else {
        # Rebuild manifest preserving metadata
        $displayOrdered = [ordered]@{}
        if ($existing.display.Contains('featured')) {
            $displayOrdered['featured'] = $existing.display['featured']
        }
        if ($existing.display.Contains('ordering')) {
            $displayOrdered['ordering'] = $existing.display['ordering']
        }
        $manifest = [ordered]@{
            id          = $existing.id
            name        = $existing.name
            description = $existing.description
            tags        = $existing.tags
            items       = $newItems
            display     = $displayOrdered
        }

        $yaml = ConvertTo-Yaml -Data $manifest
        Set-ContentIfChanged -Path $collectionPath -Value $yaml | Out-Null
        Write-Verbose "Updated $collectionPath"
    }

    return @{
        ItemCount       = $newItems.Count
        AddedCount      = $added.Count
        RemovedCount    = $removed.Count
        DeprecatedCount = $deprecatedCount
    }
}

function Split-CollectionMdByMarkers {
    <#
    .SYNOPSIS
        Splits collection markdown content at auto-generation markers.
    .DESCRIPTION
        Locates the BEGIN and END auto-generated-artifact markers in the
        supplied markdown string and returns the intro (before), footer (after),
        and a flag indicating whether markers were found.
    .PARAMETER Content
        The full text content of a collection.md file.
    .OUTPUTS
        [hashtable] with keys HasMarkers ([bool]), Intro ([string]),
        and Footer ([string]).
    .NOTES
        Returns the entire content as Intro with HasMarkers = $false when
        markers are missing or mis-ordered.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Content
    )

    $beginIdx = $Content.IndexOf($script:CollectionMdBeginMarker)
    $endIdx = $Content.IndexOf($script:CollectionMdEndMarker)

    if ($beginIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $beginIdx) {
        return @{
            HasMarkers = $false
            Intro      = $Content
            Footer     = ''
        }
    }

    $intro = $Content.Substring(0, $beginIdx).TrimEnd()
    $endMarkerEnd = $endIdx + $script:CollectionMdEndMarker.Length
    $footer = if ($endMarkerEnd -lt $Content.Length) {
        $Content.Substring($endMarkerEnd).TrimStart("`r", "`n")
    } else { '' }

    return @{
        HasMarkers = $true
        Intro      = $intro
        Footer     = $footer
    }
}

function Get-ArtifactDescription {
    <#
    .SYNOPSIS
        Reads the description from an artifact file's YAML frontmatter.
    .DESCRIPTION
        Parses the YAML frontmatter block at the top of a markdown file and
        returns the description field value. Returns an empty string when the
        file is missing, has no frontmatter, or lacks a description field.
        Strips the common " - Brought to you by microsoft/hve-core" suffix.
    .PARAMETER FilePath
        Absolute path to the artifact markdown file.
    .OUTPUTS
        [string] Description text, or empty string if unavailable.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return ''
    }

    $content = Get-Content -Path $FilePath -Raw
    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlBlock = $Matches[1]
        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $yamlBlock
            if ($frontmatter -is [hashtable] -and $frontmatter.ContainsKey('description')) {
                $desc = [string]$frontmatter.description
                # Strip the common branding suffix
                $desc = $desc -replace '\s*-\s*Brought to you by microsoft/hve-core$', ''
                return $desc.Trim()
            }
        }
        catch {
            Write-Verbose "Failed to parse frontmatter from $FilePath`: $_"
        }
    }

    return ''
}

Export-ModuleMember -Function @(
    'Get-AllCollections',
    'Get-ArtifactDescription',
    'Get-ArtifactFiles',
    'Get-ArtifactFrontmatter',
    'Get-CollectionArtifactKey',
    'Get-CollectionManifest',
    'Resolve-CollectionItemMaturity',
    'Set-ContentIfChanged',
    'Split-CollectionMdByMarkers',
    'Test-ArtifactDeprecated',
    'Test-DeprecatedPath',
    'Test-HveCoreRepoRelativePath',
    'Test-HveCoreRepoSpecificPath',
    'Update-HveCoreAllCollection'
)

Export-ModuleMember -Variable @(
    'CollectionMdBeginMarker',
    'CollectionMdEndMarker'
)
