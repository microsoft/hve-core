# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# PluginHelpers.psm1
#
# Purpose: Shared functions for the Copilot CLI plugin generation pipeline.
# Author: HVE Core Team

#Requires -Version 7.0

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
        Set-Content -Path $collectionPath -Value $yaml -Encoding utf8 -NoNewline
        Write-Verbose "Updated $collectionPath"
    }

    return @{
        ItemCount       = $newItems.Count
        AddedCount      = $added.Count
        RemovedCount    = $removed.Count
        DeprecatedCount = $deprecatedCount
    }
}

function Get-PluginItemName {
    <#
    .SYNOPSIS
    Strips artifact-type suffix from a filename.

    .DESCRIPTION
    Removes the kind-specific suffix from a filename and returns the
    simplified name with a .md extension (or the directory name for skills).

    .PARAMETER FileName
    The original filename (e.g. task-researcher.agent.md).

    .PARAMETER Kind
    The artifact kind: agent, prompt, instruction, or skill.

    .OUTPUTS
    [string] The simplified item name.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind
    )

    switch ($Kind) {
        'agent' {
            return ($FileName -replace '\.agent\.md$', '') + '.md'
        }
        'prompt' {
            return ($FileName -replace '\.prompt\.md$', '') + '.md'
        }
        'instruction' {
            return ($FileName -replace '\.instructions\.md$', '') + '.md'
        }
        'skill' {
            return $FileName
        }
    }
}

function Get-PluginSubdirectory {
    <#
    .SYNOPSIS
    Returns the plugin subdirectory name for an artifact kind.

    .DESCRIPTION
    Maps a collection item kind to the corresponding subdirectory name
    within the plugin directory structure.

    .PARAMETER Kind
    The artifact kind: agent, prompt, instruction, or skill.

    .OUTPUTS
    [string] The subdirectory name (agents, commands, instructions, or skills).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind
    )

    switch ($Kind) {
        'agent' { return 'agents' }
        'prompt' { return 'commands' }
        'instruction' { return 'instructions' }
        'skill' { return 'skills' }
    }
}

function New-PluginManifestContent {
    <#
    .SYNOPSIS
    Generates plugin.json content as a hashtable.

    .DESCRIPTION
    Creates a hashtable representing the plugin manifest with name,
    description, and version sourced from the repository package.json.

    .PARAMETER CollectionId
    The collection identifier used as the plugin name.

    .PARAMETER Description
    A short description of the plugin.

    .PARAMETER Version
    Semantic version string from the repository package.json.

    .OUTPUTS
    [hashtable] Plugin manifest with name, description, and version keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    return [ordered]@{
        name        = $CollectionId
        description = $Description
        version     = $Version
    }
}

function New-PluginReadmeContent {
    <#
    .SYNOPSIS
    Generates README.md markdown for a plugin.

    .DESCRIPTION
    Builds a complete README.md string with a markdownlint-disable header,
    title, description, install command, and tables for each artifact kind
    that has items. Only sections with items are included.

    .PARAMETER Collection
    Hashtable with id, name, and description keys from the collection manifest.

    .PARAMETER Items
    Array of processed item objects. Each object must have Name, Description,
    and Kind properties.

    .PARAMETER Maturity
        Optional collection-level maturity string. When 'experimental', an
        experimental notice is injected after the description.

    .OUTPUTS
    [string] Complete README markdown content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Items,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- markdownlint-disable-file -->')
    [void]$sb.AppendLine("# $($Collection.name)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($Collection.description)

    # Inject experimental notice when collection is experimental
    $effectiveMaturity = if ([string]::IsNullOrWhiteSpace($Maturity)) { 'stable' } else { $Maturity }
    if ($effectiveMaturity -eq 'experimental') {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> **`u{26A0}`u{FE0F} Experimental** `u{2014} This collection is experimental. Contents and behavior may change or be removed without notice.")
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Install')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('```bash')
    [void]$sb.AppendLine("copilot plugin install $($Collection.id)@hve-core")
    [void]$sb.AppendLine('```')

    $sectionMap = [ordered]@{
        agent       = @{ Title = 'Agents'; Header = 'Agent' }
        prompt      = @{ Title = 'Commands'; Header = 'Command' }
        instruction = @{ Title = 'Instructions'; Header = 'Instruction' }
        skill       = @{ Title = 'Skills'; Header = 'Skill' }
    }

    foreach ($entry in $sectionMap.GetEnumerator()) {
        $kind = $entry.Key
        $meta = $entry.Value
        $kindItems = @($Items | Where-Object { $_.Kind -eq $kind })
        if ($kindItems.Count -eq 0) {
            continue
        }

        [void]$sb.AppendLine()
        [void]$sb.AppendLine("## $($meta.Title)")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("| $($meta.Header) | Description |")
        [void]$sb.AppendLine('| ' + ('-' * $meta.Header.Length) + ' | ----------- |')
        foreach ($item in $kindItems) {
            [void]$sb.AppendLine("| $($item.Name) | $($item.Description) |")
        }
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)')
    [void]$sb.AppendLine()

    return $sb.ToString()
}

function New-MarketplaceManifestContent {
    <#
    .SYNOPSIS
    Generates marketplace.json content as a hashtable.

    .DESCRIPTION
    Creates a hashtable representing the marketplace manifest with repository
    metadata, owner information, and plugin entries. Matches the schema used
    by github/awesome-copilot.

    .PARAMETER RepoName
    Repository name used as the marketplace name.

    .PARAMETER Description
    Short description of the repository.

    .PARAMETER Version
    Semantic version string from package.json.

    .PARAMETER OwnerName
    Organization or individual owning the repository.

    .PARAMETER Plugins
    Array of ordered hashtables with name, description, and version keys
    from New-PluginManifestContent.

    .OUTPUTS
    [hashtable] Marketplace manifest with name, metadata, owner, and plugins keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$OwnerName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Plugins
    )

    $pluginEntries = @()
    foreach ($plugin in $Plugins) {
        $pluginEntries += [ordered]@{
            name        = $plugin.name
            source      = $plugin.name
            description = $plugin.description
            version     = $plugin.version
        }
    }

    return [ordered]@{
        name     = $RepoName
        metadata = [ordered]@{
            description = $Description
            version     = $Version
            pluginRoot  = './plugins'
        }
        owner    = [ordered]@{
            name = $OwnerName
        }
        plugins  = $pluginEntries
    }
}

function Write-MarketplaceManifest {
    <#
    .SYNOPSIS
    Writes the marketplace.json file to .github/plugin/.

    .DESCRIPTION
    Assembles plugin metadata from generated collections and writes the
    marketplace manifest to .github/plugin/marketplace.json. Creates the
    directory when it does not exist.

    .PARAMETER RepoRoot
    Absolute path to the repository root directory.

    .PARAMETER Collections
    Array of collection manifest hashtables with id and description.

    .PARAMETER DryRun
    When specified, logs the action without writing to disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Collections,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
    $packageJson = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json

    $plugins = @()
    foreach ($collection in ($Collections | Sort-Object { $_.id })) {
        $plugins += New-PluginManifestContent `
            -CollectionId $collection.id `
            -Description $collection.description `
            -Version $packageJson.version
    }

    $manifest = New-MarketplaceManifestContent `
        -RepoName $packageJson.name `
        -Description $packageJson.description `
        -Version $packageJson.version `
        -OwnerName $packageJson.author `
        -Plugins $plugins

    $outputDir = Join-Path -Path $RepoRoot -ChildPath '.github' -AdditionalChildPath 'plugin'
    $outputPath = Join-Path -Path $outputDir -ChildPath 'marketplace.json'

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would write marketplace.json at $outputPath" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding utf8 -NoNewline
    Write-Host "  Marketplace manifest: $outputPath" -ForegroundColor Green
}

function New-GenerateResult {
    <#
    .SYNOPSIS
    Creates a standardized result object.

    .DESCRIPTION
    Returns a hashtable representing the outcome of a plugin generation run
    with success status, plugin count, and optional error message.

    .PARAMETER Success
    Whether the operation succeeded.

    .PARAMETER PluginCount
    Number of plugins generated.

    .PARAMETER ErrorMessage
    Optional error message when Success is $false.

    .OUTPUTS
    [hashtable] Result with Success, PluginCount, and ErrorMessage keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $true)]
        [int]$PluginCount,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ''
    )

    return @{
        Success      = $Success
        PluginCount  = $PluginCount
        ErrorMessage = $ErrorMessage
    }
}

# ---------------------------------------------------------------------------
# I/O Functions (file system operations)
# ---------------------------------------------------------------------------

function Test-SymlinkCapability {
    <#
    .SYNOPSIS
    Probes whether the current process can create symbolic links.

    .DESCRIPTION
    Creates a temporary file and attempts to symlink to it. Returns $true
    when the OS and process privileges allow symlink creation, $false
    otherwise. The probe directory is cleaned up unconditionally.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "hve-symlink-probe-$PID"
    $targetFile = Join-Path -Path $tempDir -ChildPath 'target.txt'
    $linkFile = Join-Path -Path $tempDir -ChildPath 'link.txt'
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Set-Content -Path $targetFile -Value 'probe' -NoNewline
        New-Item -ItemType SymbolicLink -Path $linkFile -Target $targetFile -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
    finally {
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-PluginLink {
    <#
    .SYNOPSIS
    Links a source path into a plugin destination via symlink or text stub.

    .DESCRIPTION
    When SymlinkCapable is set, creates a relative symbolic link from
    DestinationPath to SourcePath. Otherwise writes a text stub file
    containing the relative path, matching the format git produces when
    core.symlinks is false. Text stubs keep git status clean on Windows
    without Developer Mode or elevated privileges.

    .PARAMETER SourcePath
    Absolute path to the real file or directory.

    .PARAMETER DestinationPath
    Absolute path where the link or text stub will be created.

    .PARAMETER SymlinkCapable
    When set, create a symbolic link; otherwise write a text stub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [switch]$SymlinkCapable
    )

    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $relativePath = [System.IO.Path]::GetRelativePath($destinationDir, $SourcePath) -replace '\\', '/'

    if ($SymlinkCapable) {
        New-Item -ItemType SymbolicLink -Path $DestinationPath -Value $relativePath -Force | Out-Null
    }
    else {
        [System.IO.File]::WriteAllText($DestinationPath, $relativePath)
    }
}

function Write-PluginDirectory {
    <#
    .SYNOPSIS
    Creates a complete plugin directory structure from a collection.

    .DESCRIPTION
    Builds the full plugin layout under the specified plugins directory,
    including subdirectories for agents, commands, instructions, and skills.
    Each item is linked or copied from the plugin directory back to its
    source in the repository. Generates plugin.json and README.md.

    .PARAMETER Collection
    Parsed collection manifest hashtable with id, name, description, and items.

    .PARAMETER PluginsDir
    Absolute path to the root plugins output directory.

    .PARAMETER RepoRoot
    Absolute path to the repository root.

    .PARAMETER Version
    Semantic version string from the repository package.json.

    .PARAMETER Maturity
        Optional collection-level maturity string. Forwarded to
        New-PluginReadmeContent for experimental notice injection.

    .PARAMETER DryRun
    When specified, logs actions without creating files or directories.

    .PARAMETER SymlinkCapable
    When specified, creates symbolic links; otherwise copies files.

    .OUTPUTS
    [hashtable] Result with Success, AgentCount, CommandCount, InstructionCount,
    and SkillCount keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $true)]
        [string]$PluginsDir,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$SymlinkCapable
    )

    $collectionId = $Collection.id
    $pluginRoot = Join-Path -Path $PluginsDir -ChildPath $collectionId

    $counts = @{
        AgentCount       = 0
        CommandCount      = 0
        InstructionCount = 0
        SkillCount       = 0
    }

    $readmeItems = @()

    foreach ($item in $Collection.items) {
        $kind = $item.kind
        $sourcePath = Join-Path -Path $RepoRoot -ChildPath $item.path
        $subdir = Get-PluginSubdirectory -Kind $kind

        if ($kind -eq 'skill') {
            # Skills are directory symlinks; use the directory name as FileName
            $fileName = Split-Path -Leaf $item.path
            $itemName = Get-PluginItemName -FileName $fileName -Kind $kind
            $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemName
            $description = $fileName
        }
        else {
            $fileName = Split-Path -Leaf $item.path
            $itemName = Get-PluginItemName -FileName $fileName -Kind $kind
            $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemName

            # Read frontmatter from the source file for description
            $fallback = $itemName -replace '\.md$', ''
            if (Test-Path -Path $sourcePath) {
                $frontmatter = Get-ArtifactFrontmatter -FilePath $sourcePath -FallbackDescription $fallback
                $description = $frontmatter.description
            }
            else {
                $description = $fallback
                Write-Warning "Source file not found: $sourcePath"
            }
        }

        $readmeItems += @{
            Name        = $itemName -replace '\.md$', ''
            Description = $description
            Kind        = $kind
        }

        # Update counts
        switch ($kind) {
            'agent'       { $counts.AgentCount++ }
            'prompt'      { $counts.CommandCount++ }
            'instruction' { $counts.InstructionCount++ }
            'skill'       { $counts.SkillCount++ }
        }

        if ($DryRun) {
            Write-Verbose "DryRun: Would create link $destPath -> $sourcePath"
            continue
        }

        New-PluginLink -SourcePath $sourcePath -DestinationPath $destPath -SymlinkCapable:$SymlinkCapable
    }

    # Link shared resource directories (unconditional, all plugins)
    $sharedDirs = @(
        @{ Source = 'docs/templates';    Destination = 'docs/templates' }
        @{ Source = 'scripts/lib';       Destination = 'scripts/lib' }
    )

    foreach ($dir in $sharedDirs) {
        $sourcePath = Join-Path -Path $RepoRoot -ChildPath $dir.Source
        $destPath = Join-Path -Path $pluginRoot -ChildPath $dir.Destination

        if (-not (Test-Path -Path $sourcePath)) {
            Write-Warning "Shared directory not found: $sourcePath"
            continue
        }

        if ($DryRun) {
            Write-Verbose "DryRun: Would create shared directory link $destPath -> $sourcePath"
            continue
        }

        New-PluginLink -SourcePath $sourcePath -DestinationPath $destPath -SymlinkCapable:$SymlinkCapable
    }

    # Generate plugin.json
    $manifestDir = Join-Path -Path $pluginRoot -ChildPath '.github' -AdditionalChildPath 'plugin'
    $manifestPath = Join-Path -Path $manifestDir -ChildPath 'plugin.json'
    $manifest = New-PluginManifestContent -CollectionId $collectionId -Description $Collection.description -Version $Version

    if ($DryRun) {
        Write-Verbose "DryRun: Would write plugin.json at $manifestPath"
    }
    else {
        if (-not (Test-Path -Path $manifestDir)) {
            New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        }
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding utf8 -NoNewline
    }

    # Generate README.md
    $readmePath = Join-Path -Path $pluginRoot -ChildPath 'README.md'
    $readmeContent = New-PluginReadmeContent -Collection $Collection -Items $readmeItems -Maturity $Maturity

    if ($DryRun) {
        Write-Verbose "DryRun: Would write README.md at $readmePath"
    }
    else {
        Set-Content -Path $readmePath -Value $readmeContent -Encoding utf8 -NoNewline
    }

    return @{
        Success          = $true
        AgentCount       = $counts.AgentCount
        CommandCount     = $counts.CommandCount
        InstructionCount = $counts.InstructionCount
        SkillCount       = $counts.SkillCount
    }
}

function Repair-PluginSymlinkIndex {
    <#
    .SYNOPSIS
    Fixes git index modes for text stub files so they register as symlinks.

    .DESCRIPTION
    On systems where symlinks are unavailable (Windows without Developer Mode),
    New-PluginLink writes text stubs containing relative paths. Git stages
    these as mode 100644 (regular file). This function re-indexes each text
    stub as mode 120000 (symlink) so that Linux/macOS checkouts materialize
    real symbolic links.

    .PARAMETER PluginsDir
    Absolute path to the plugins output directory.

    .PARAMETER RepoRoot
    Absolute path to the repository root (git working tree).

    .PARAMETER DryRun
    When specified, logs what would be fixed without modifying the index.

    .OUTPUTS
    [int] Number of index entries corrected.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginsDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    if (-not (Test-Path -Path $PluginsDir)) {
        return 0
    }

    # Build a set of paths already tracked in the git index under plugins/.
    # --index-info silently ignores untracked paths (PowerShell pipe encoding
    # issue), so new files must be added individually via --cacheinfo.
    $trackedPaths = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $pluginsRel = [System.IO.Path]::GetRelativePath($RepoRoot, $PluginsDir) -replace '\\', '/'
    $lsOutput = git ls-files -- $pluginsRel 2>$null
    if ($lsOutput) {
        foreach ($p in @($lsOutput)) { [void]$trackedPaths.Add($p) }
    }

    $fixedCount = 0
    $newEntries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $batchEntries = [System.Collections.Generic.List[string]]::new()
    $files = Get-ChildItem -Path $PluginsDir -File -Recurse

    foreach ($file in $files) {
        # Text stubs are small files whose content is a relative path with
        # forward slashes, no line breaks, starting with ../
        if ($file.Length -gt 500) {
            continue
        }

        $content = [System.IO.File]::ReadAllText($file.FullName)

        if ($content -notmatch '^\.\./') {
            continue
        }
        if ($content.Contains("`n") -or $content.Contains("`r")) {
            continue
        }

        $repoRelPath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'

        if ($DryRun) {
            Write-Verbose "DryRun: Would fix index mode for $repoRelPath"
            $fixedCount++
            continue
        }

        $hashOutput = git hash-object -w -- $file.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to hash-object for $repoRelPath"
            continue
        }

        # Extract clean SHA string, filtering out any ErrorRecord objects
        $sha = @($hashOutput | Where-Object { $_ -is [string] -and $_ -match '^[0-9a-f]{40}' })[0]
        if (-not $sha) {
            Write-Warning "No valid SHA returned for $repoRelPath"
            continue
        }

        if ($trackedPaths.Contains($repoRelPath)) {
            $batchEntries.Add("120000 $sha`t$repoRelPath")
        } else {
            $newEntries.Add([PSCustomObject]@{ Sha = $sha; Path = $repoRelPath })
        }
        $fixedCount++
        Write-Verbose "Queued index fix: $repoRelPath -> 120000"
    }

    # Add new/untracked files individually (typically few per run)
    foreach ($entry in $newEntries) {
        $cacheResult = git update-index --add --cacheinfo "120000,$($entry.Sha),$($entry.Path)" 2>&1
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = @($cacheResult | ForEach-Object { $_.ToString() }) -join '; '
            Write-Warning "Failed to add index entry for $($entry.Path): $errorMsg"
            $fixedCount--
        }
    }

    # Batch update existing entries in a single call to avoid index.lock contention
    if ($batchEntries.Count -gt 0) {
        $indexResult = $batchEntries | git update-index --index-info 2>&1
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = @($indexResult | ForEach-Object { $_.ToString() }) -join '; '
            Write-Warning "Failed to update git index: $errorMsg"
            return 0
        }
    }

    return $fixedCount
}

Export-ModuleMember -Function @(
    'Get-AllCollections',
    'Get-ArtifactFiles',
    'Get-ArtifactFrontmatter',
    'Get-CollectionArtifactKey',
    'Get-CollectionManifest',
    'Get-PluginItemName',
    'Get-PluginSubdirectory',
    'New-GenerateResult',
    'New-MarketplaceManifestContent',
    'New-PluginManifestContent',
    'New-PluginReadmeContent',
    'New-PluginLink',
    'Repair-PluginSymlinkIndex',
    'Test-SymlinkCapability',
    'Resolve-CollectionItemMaturity',
    'Test-ArtifactDeprecated',
    'Test-DeprecatedPath',
    'Test-HveCoreRepoRelativePath',
    'Test-HveCoreRepoSpecificPath',
    'Update-HveCoreAllCollection',
    'Write-MarketplaceManifest',
    'Write-PluginDirectory'
)
