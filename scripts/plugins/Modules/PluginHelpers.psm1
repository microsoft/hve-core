# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# PluginHelpers.psm1
#
# Purpose: Shared functions for the Copilot CLI plugin generation pipeline.
# Author: HVE Core Team

#Requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force

# ---------------------------------------------------------------------------
# Pure Functions (no file system side effects)
# ---------------------------------------------------------------------------

function Get-PluginItemName {
    <#
    .SYNOPSIS
    Returns an artifact filename, stripping kind suffixes for CLI display.

    .DESCRIPTION
    Validated entry point for filename handling in the plugin pipeline.
    Agent and prompt files have their kind suffix (.agent.md, .prompt.md)
    replaced with .md so the CLI title is clean. Instruction files keep
    their suffix because VS Code discovery filters on *.instructions.md.

    .PARAMETER FileName
    The original filename (e.g. task-researcher.agent.md).

    .PARAMETER Kind
    The artifact kind: agent, prompt, instruction, or skill.

    .OUTPUTS
    [string] The processed filename.
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
        'agent'       { return $FileName -replace '\.agent\.md$', '.md' }
        'prompt'      { return $FileName -replace '\.prompt\.md$', '.md' }
        'instruction' { return $FileName }
        'skill'       { return $FileName }
    }
}

function Get-PluginItemSubpath {
    <#
    .SYNOPSIS
    Extracts the subdirectory path between the kind root prefix and the leaf.

    .DESCRIPTION
    Given a repo-relative item path and its kind, strips the known prefix
    (e.g. .github/agents/) and returns the intermediate directory segments.
    Returns empty string when the item is directly under the kind root.

    .PARAMETER Path
    Repo-relative item path (e.g. .github/agents/hve-core/rpi-agent.agent.md).

    .PARAMETER Kind
    The artifact kind: agent, prompt, instruction, or skill.

    .OUTPUTS
    [string] Intermediate subdirectory path, or empty string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind
    )

    $prefixMap = @{
        'agent'       = '.github/agents/'
        'prompt'      = '.github/prompts/'
        'instruction' = '.github/instructions/'
        'skill'       = '.github/skills/'
    }

    $prefix = $prefixMap[$Kind]
    $normalized = $Path -replace '\\', '/'

    if (-not $normalized.StartsWith($prefix)) {
        return ''
    }

    $relative = $normalized.Substring($prefix.Length)
    $parts = $relative -split '/'

    if ($parts.Count -gt 1) {
        return ($parts[0..($parts.Count - 2)] -join '/')
    }

    return ''
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
    description, version, and component path declarations. When explicit
    path arrays are provided, uses them so the CLI discovers artifacts
    in nested subdirectories. When omitted, falls back to convention
    defaults for lightweight marketplace entries.

    .PARAMETER CollectionId
    The collection identifier used as the plugin name.

    .PARAMETER Description
    A short description of the plugin.

    .PARAMETER Version
    Semantic version string from the repository package.json.

    .PARAMETER AgentPaths
    Optional. Array of relative directory paths containing .agent.md files.

    .PARAMETER CommandPaths
    Optional. Array of relative directory paths containing .prompt.md files.

    .PARAMETER SkillPaths
    Optional. Array of relative directory paths containing skill subdirs.

    .OUTPUTS
    [hashtable] Plugin manifest with name, description, version, and
    component path keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$AgentPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$CommandPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$SkillPaths
    )

    $manifest = [ordered]@{
        name        = $CollectionId
        description = $Description
        version     = $Version
    }

    # Emit explicit path arrays when provided; the CLI does not recurse
    # into subdirectories, so each leaf directory must be declared.
    if ($AgentPaths -and $AgentPaths.Count -gt 0) {
        $manifest['agents'] = @($AgentPaths | Sort-Object)
    }

    if ($CommandPaths -and $CommandPaths.Count -gt 0) {
        $manifest['commands'] = @($CommandPaths | Sort-Object)
    }

    if ($SkillPaths -and $SkillPaths.Count -gt 0) {
        $manifest['skills'] = @($SkillPaths | Sort-Object)
    }

    return $manifest
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
    An optional 'notice' key injects a custom blockquote after the description.

    .PARAMETER Items
    Array of processed item objects. Each object must have Name, Description,
    and Kind properties.

    .PARAMETER Maturity
        Optional collection-level maturity string. When 'experimental', an
        experimental notice is injected after the description. When 'preview',
        a preview notice is injected.

    .PARAMETER CollectionContent
        Optional markdown content from the collection .md file. Injected as
        an Overview section between the description and the Install section.

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
        [string]$Maturity,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CollectionContent
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- markdownlint-disable-file -->')
    [void]$sb.AppendLine("# $($Collection.name)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($Collection.description)

    # Inject maturity notice when collection is not stable
    $effectiveMaturity = if ([string]::IsNullOrWhiteSpace($Maturity)) { 'stable' } else { $Maturity }
    if ($effectiveMaturity -eq 'experimental') {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> **`u{26A0}`u{FE0F} Experimental** `u{2014} This collection is experimental. Contents and behavior may change or be removed without notice.")
    }
    elseif ($effectiveMaturity -eq 'preview') {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> **`u{1F50D} Preview** `u{2014} This collection is in preview. Core features are complete and functional but refinements may follow.")
    }

    # Inject collection-level notice when present
    if ($Collection.ContainsKey('notice') -and -not [string]::IsNullOrWhiteSpace($Collection.notice)) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine($Collection.notice.TrimEnd())
    }

    # Inject collection description content as an Overview section
    if (-not [string]::IsNullOrWhiteSpace($CollectionContent)) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Overview')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine($CollectionContent.TrimEnd())
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

        # Calculate column widths for aligned table output
        $col1Width = $meta.Header.Length
        $col2Width = 'Description'.Length
        foreach ($item in $kindItems) {
            if ($item.Name.Length -gt $col1Width) { $col1Width = $item.Name.Length }
            if ($item.Description.Length -gt $col2Width) { $col2Width = $item.Description.Length }
        }

        [void]$sb.AppendLine("| $($meta.Header.PadRight($col1Width)) | $('Description'.PadRight($col2Width)) |")
        [void]$sb.AppendLine('|' + ('-' * ($col1Width + 2)) + '|' + ('-' * ($col2Width + 2)) + '|')
        foreach ($item in $kindItems) {
            [void]$sb.AppendLine("| $($item.Name.PadRight($col1Width)) | $($item.Description.PadRight($col2Width)) |")
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

    $manifestJson = $manifest | ConvertTo-Json -Depth 10
    Set-ContentIfChanged -Path $outputPath -Value $manifestJson | Out-Null
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
        Set-ContentIfChanged -Path $DestinationPath -Value $relativePath | Out-Null
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
        New-PluginReadmeContent for maturity notice injection.

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

    # Track unique directories per kind for plugin.json path arrays
    $agentDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $commandDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $skillDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $readmeItems = @()
    $generatedFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($item in $Collection.items) {
        $kind = $item.kind
        $sourcePath = Join-Path -Path $RepoRoot -ChildPath $item.path
        $subdir = Get-PluginSubdirectory -Kind $kind

        if ($kind -eq 'skill') {
            # Skills are directory symlinks; use the directory name as FileName
            $fileName = Split-Path -Leaf $item.path
            $itemName = Get-PluginItemName -FileName $fileName -Kind $kind
            $itemSubpath = Get-PluginItemSubpath -Path $item.path -Kind $kind
            if ($itemSubpath) {
                $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemSubpath, $itemName
            } else {
                $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemName
            }

            # Read frontmatter from SKILL.md for description; fall back to directory name
            $skillMdPath = Join-Path -Path $sourcePath -ChildPath 'SKILL.md'
            if (Test-Path -Path $skillMdPath) {
                $frontmatter = Get-ArtifactFrontmatter -FilePath $skillMdPath -FallbackDescription $fileName
                $description = $frontmatter.description
            }
            else {
                $description = $fileName
            }
        }
        else {
            $fileName = Split-Path -Leaf $item.path
            $itemName = Get-PluginItemName -FileName $fileName -Kind $kind
            $itemSubpath = Get-PluginItemSubpath -Path $item.path -Kind $kind
            if ($itemSubpath) {
                $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemSubpath, $itemName
            } else {
                $destPath = Join-Path -Path $pluginRoot -ChildPath $subdir -AdditionalChildPath $itemName
            }

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

        # Update counts and collect parent directories for manifest paths
        switch ($kind) {
            'agent' {
                $counts.AgentCount++
                $parentDir = Split-Path -Parent $destPath
                $relDir = [System.IO.Path]::GetRelativePath($pluginRoot, $parentDir) -replace '\\', '/'
                [void]$agentDirs.Add("$relDir/")
            }
            'prompt' {
                $counts.CommandCount++
                $parentDir = Split-Path -Parent $destPath
                $relDir = [System.IO.Path]::GetRelativePath($pluginRoot, $parentDir) -replace '\\', '/'
                [void]$commandDirs.Add("$relDir/")
            }
            'instruction' { $counts.InstructionCount++ }
            'skill' {
                $counts.SkillCount++
                # Skills: the CLI scans for <name>/SKILL.md; point at the grandparent
                $parentDir = Split-Path -Parent $destPath
                $relDir = [System.IO.Path]::GetRelativePath($pluginRoot, $parentDir) -replace '\\', '/'
                [void]$skillDirs.Add("$relDir/")
            }
        }

        [void]$generatedFiles.Add($destPath)

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

        [void]$generatedFiles.Add($destPath)

        if ($DryRun) {
            Write-Verbose "DryRun: Would create shared directory link $destPath -> $sourcePath"
            continue
        }

        New-PluginLink -SourcePath $sourcePath -DestinationPath $destPath -SymlinkCapable:$SymlinkCapable
    }

    # Generate plugin.json with explicit path arrays for CLI discovery
    $manifestDir = Join-Path -Path $pluginRoot -ChildPath '.github' -AdditionalChildPath 'plugin'
    $manifestPath = Join-Path -Path $manifestDir -ChildPath 'plugin.json'
    $manifest = New-PluginManifestContent `
        -CollectionId $collectionId `
        -Description $Collection.description `
        -Version $Version `
        -AgentPaths @($agentDirs) `
        -CommandPaths @($commandDirs) `
        -SkillPaths @($skillDirs)
    [void]$generatedFiles.Add($manifestPath)

    if ($DryRun) {
        Write-Verbose "DryRun: Would write plugin.json at $manifestPath"
    }
    else {
        if (-not (Test-Path -Path $manifestDir)) {
            New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        }
        $jsonContent = $manifest | ConvertTo-Json -Depth 10
        Set-ContentIfChanged -Path $manifestPath -Value $jsonContent | Out-Null
    }

    # Generate README.md
    $readmePath = Join-Path -Path $pluginRoot -ChildPath 'README.md'
    $collectionMdPath = Join-Path -Path $RepoRoot -ChildPath "collections/$collectionId.collection.md"
    $collectionContent = if (Test-Path -Path $collectionMdPath) {
        Get-Content -Path $collectionMdPath -Raw
    } else { $null }
    $readmeContent = New-PluginReadmeContent -Collection $Collection -Items $readmeItems -Maturity $Maturity -CollectionContent $collectionContent
    [void]$generatedFiles.Add($readmePath)

    if ($DryRun) {
        Write-Verbose "DryRun: Would write README.md at $readmePath"
    }
    else {
        Set-ContentIfChanged -Path $readmePath -Value $readmeContent | Out-Null
    }

    return @{
        Success          = $true
        AgentCount       = $counts.AgentCount
        CommandCount     = $counts.CommandCount
        InstructionCount = $counts.InstructionCount
        SkillCount       = $counts.SkillCount
        GeneratedFiles   = $generatedFiles
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
    $alreadySymlink = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $pluginsRel = [System.IO.Path]::GetRelativePath($RepoRoot, $PluginsDir) -replace '\\', '/'
    $lsOutput = git ls-files --stage -- $pluginsRel 2>$null
    if ($lsOutput) {
        foreach ($line in @($lsOutput)) {
            if ($line -match '^(\d+)\s+[0-9a-f]+\s+\d+\t(.+)$') {
                [void]$trackedPaths.Add($Matches[2])
                if ($Matches[1] -eq '120000') {
                    [void]$alreadySymlink.Add($Matches[2])
                }
            }
        }
    }

    $fixedCount = 0
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

        if ($alreadySymlink.Contains($repoRelPath)) {
            continue
        }

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

        # Use --add for untracked files; harmless for already-tracked entries.
        # Avoids --index-info piping which breaks on Windows due to CRLF stdin.
        $addFlag = if (-not $trackedPaths.Contains($repoRelPath)) { '--add' } else { $null }
        $cacheArgs = @('update-index') + @($addFlag | Where-Object { $_ }) + @('--cacheinfo', "120000,$sha,$repoRelPath")
        $cacheResult = & git @cacheArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = @($cacheResult | ForEach-Object { $_.ToString() }) -join '; '
            Write-Warning "Failed to update index entry for ${repoRelPath}: $errorMsg"
            continue
        }
        $fixedCount++
        Write-Verbose "Fixed index mode: $repoRelPath -> 120000"
    }

    return $fixedCount
}

Export-ModuleMember -Function @(
    'Get-PluginItemName',
    'Get-PluginItemSubpath',
    'Get-PluginSubdirectory',
    'New-GenerateResult',
    'New-MarketplaceManifestContent',
    'New-PluginLink',
    'New-PluginManifestContent',
    'New-PluginReadmeContent',
    'Repair-PluginSymlinkIndex',
    'Test-SymlinkCapability',
    'Write-MarketplaceManifest',
    'Write-PluginDirectory'
)