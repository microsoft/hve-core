# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# PluginHelpers.psm1
#
# Purpose: Shared functions for the Copilot CLI plugin generation pipeline.
# Author: HVE Core Team

#Requires -Version 7.4

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
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    switch ($Kind) {
        'agent'       { return $FileName -replace '\.agent\.md$', '.md' }
        'prompt'      { return $FileName -replace '\.prompt\.md$', '.md' }
        'instruction' { return $FileName }
        'skill'       { return $FileName }
        'hook'        { return $FileName }
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
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    $prefixMap = @{
        'agent'       = '.github/agents/'
        'prompt'      = '.github/prompts/'
        'instruction' = '.github/instructions/'
        'skill'       = '.github/skills/'
        'hook'        = '.github/hooks/'
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
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    switch ($Kind) {
        'agent' { return 'agents' }
        'prompt' { return 'commands' }
        'instruction' { return 'instructions' }
        'skill' { return 'skills' }
        'hook' { return 'hooks' }
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

    .PARAMETER HookPaths
    Optional. Array of relative file paths to hook JSON files.

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
        [string[]]$SkillPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$HookPaths
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

    if ($HookPaths -and $HookPaths.Count -gt 0) {
        # The CLI `hooks` field is a single hooks-config file path (or inline
        # object), not an array. Emit the lone path as a string; warn when more
        # than one hook manifest is registered since only one can be referenced.
        $sortedHooks = @($HookPaths | Sort-Object)
        if ($sortedHooks.Count -gt 1) {
            Write-Warning "Plugin '$CollectionId' declares $($sortedHooks.Count) hook manifests; the CLI references only one. Using '$($sortedHooks[0])'."
        }
        $manifest['hooks'] = $sortedHooks[0]
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

    # Inject collection description content as an Overview section.
    # Strip the leading H1 since the title is already emitted above.
    if (-not [string]::IsNullOrWhiteSpace($CollectionContent)) {
        $overviewText = $CollectionContent -replace '(?m)\A#\s+[^\r\n]+\r?\n\r?\n', ''
        $overviewText = $overviewText.TrimEnd()

        if (-not [string]::IsNullOrWhiteSpace($overviewText)) {
            [void]$sb.AppendLine()
            [void]$sb.AppendLine('## Overview')
            [void]$sb.AppendLine()
            [void]$sb.AppendLine($overviewText)
        }
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
        hook        = @{ Title = 'Hooks'; Header = 'Hook' }
    }

    $hasCollectionArtifactContent = -not [string]::IsNullOrWhiteSpace($CollectionContent) -and (
        $CollectionContent -match '(?m)^##\s+Included Artifacts\s*$' -or
        (
            $CollectionContent -match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->' -and
            $CollectionContent -match '<!-- END AUTO-GENERATED ARTIFACTS -->'
        )
    )

    if (-not $hasCollectionArtifactContent) {
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

function Add-GeneratedFilesForCopiedTree {
    <#
    .SYNOPSIS
    Registers copied file paths for orphan cleanup tracking.

    .DESCRIPTION
    When a directory tree is materialized into a plugin package, register each
    copied file path with the generated-files set so orphan cleanup preserves
    the full tree.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$GeneratedFiles
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return
    }

    foreach ($child in Get-ChildItem -LiteralPath $SourcePath -File -Recurse -Force) {
        [void]$GeneratedFiles.Add($child.FullName)
    }
}

function New-PluginLink {
    <#
    .SYNOPSIS
    Copies a source path into a plugin destination.

    .DESCRIPTION
    Replaces the destination with a real file or directory copy. Directory
    sources are rejected when they contain links or reparse points so plugin
    packages cannot follow content outside the selected source tree.

    .PARAMETER SourcePath
    Absolute path to the real file or directory.

    .PARAMETER DestinationPath
    Absolute path where the copied content will be created.

    .PARAMETER RepoRoot
    Optional repository root. When supplied, directory sources copy only
    Git-tracked regular files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    $sourceItem = Get-Item -LiteralPath $SourcePath -Force -ErrorAction Stop
    if ($sourceItem.LinkType -or ($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw "Plugin source cannot be a link or reparse point: $($sourceItem.FullName)"
    }

    $trackedFiles = $null
    if ($RepoRoot) {
        $pathComparison = if ($IsWindows) {
            [System.StringComparison]::OrdinalIgnoreCase
        }
        else {
            [System.StringComparison]::Ordinal
        }
        $canonicalRepoRoot = [System.IO.Path]::TrimEndingDirectorySeparator(
            [System.IO.Path]::GetFullPath($RepoRoot)
        )
        $repoPrefix = $canonicalRepoRoot + [System.IO.Path]::DirectorySeparatorChar
        $canonicalSource = [System.IO.Path]::GetFullPath($sourceItem.FullName)
        if (-not $canonicalSource.Equals($canonicalRepoRoot, $pathComparison) -and
            -not $canonicalSource.StartsWith($repoPrefix, $pathComparison)) {
            throw "Plugin source must be inside the repository root: $canonicalSource"
        }

        if ($sourceItem.PSIsContainer) {
            $sourcePrefix = [System.IO.Path]::TrimEndingDirectorySeparator($canonicalSource) +
                [System.IO.Path]::DirectorySeparatorChar
            $repoRelativeSource = [System.IO.Path]::GetRelativePath($canonicalRepoRoot, $canonicalSource) -replace '\\', '/'
            $pathspec = ":(literal)$repoRelativeSource/"
            $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $startInfo.FileName = 'git'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            [void]$startInfo.ArgumentList.Add('-C')
            [void]$startInfo.ArgumentList.Add($canonicalRepoRoot)
            [void]$startInfo.ArgumentList.Add('ls-files')
            [void]$startInfo.ArgumentList.Add('--stage')
            [void]$startInfo.ArgumentList.Add('-z')
            [void]$startInfo.ArgumentList.Add('--')
            [void]$startInfo.ArgumentList.Add($pathspec)

            $process = [System.Diagnostics.Process]::Start($startInfo)
            $stageOutput = $process.StandardOutput.ReadToEnd()
            $stageError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) {
                throw "Failed to enumerate tracked plugin source files: $stageError"
            }

            $trackedFiles = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($record in $stageOutput.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries)) {
                $tabIndex = $record.IndexOf("`t")
                if ($tabIndex -lt 0) {
                    throw "Invalid Git stage record for plugin source: $record"
                }

                $metadata = $record.Substring(0, $tabIndex)
                $repoRelativePath = $record.Substring($tabIndex + 1)
                if ($metadata -notmatch '^(\d{6}) [0-9a-f]+ \d+$') {
                    throw "Invalid Git stage metadata for plugin source: $metadata"
                }
                $mode = $Matches[1]
                if ($mode -notin @('100644', '100755')) {
                    throw "Plugin source contains unsupported tracked mode $mode`: $repoRelativePath"
                }

                $trackedSource = [System.IO.Path]::GetFullPath(
                    (Join-Path -Path $canonicalRepoRoot -ChildPath $repoRelativePath)
                )
                if (-not $trackedSource.StartsWith($sourcePrefix, $pathComparison)) {
                    throw "Tracked plugin source escapes selected directory: $repoRelativePath"
                }

                $trackedItem = Get-Item -LiteralPath $trackedSource -Force -ErrorAction SilentlyContinue
                if (-not $trackedItem -or $trackedItem.PSIsContainer -or $trackedItem.LinkType -or
                    ($trackedItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                    throw "Tracked plugin source must be a real file: $trackedSource"
                }
                try {
                    $readStream = [System.IO.File]::OpenRead($trackedSource)
                    $readStream.Dispose()
                }
                catch {
                    throw "Tracked plugin source must be readable: $trackedSource"
                }

                $trackedFiles.Add(@{
                    Source       = $trackedSource
                    RelativePath = [System.IO.Path]::GetRelativePath($canonicalSource, $trackedSource)
                })
            }
        }
        elseif ($sourceItem.PSIsContainer -or -not $sourceItem.Exists) {
            throw "Plugin source must be a real file: $canonicalSource"
        }
        else {
            try {
                $readStream = [System.IO.File]::OpenRead($canonicalSource)
                $readStream.Dispose()
            }
            catch {
                throw "Plugin source must be readable: $canonicalSource"
            }
        }
    }
    elseif ($sourceItem.PSIsContainer) {
        $nestedLink = Get-ChildItem -LiteralPath $SourcePath -Force -Recurse |
            Where-Object {
                $_.LinkType -or ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            } |
            Select-Object -First 1
        if ($nestedLink) {
            throw "Plugin source cannot contain a link or reparse point: $($nestedLink.FullName)"
        }
    }

    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    $destinationItem = Get-Item -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue
    if ($destinationItem) {
        if ($destinationItem.LinkType -or -not $destinationItem.PSIsContainer) {
            Remove-Item -LiteralPath $DestinationPath -Force
        }
        else {
            Remove-Item -LiteralPath $DestinationPath -Recurse -Force
        }
    }

    if ($null -ne $trackedFiles) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        foreach ($trackedFile in $trackedFiles) {
            $trackedDestination = Join-Path -Path $DestinationPath -ChildPath $trackedFile.RelativePath
            $trackedDestinationParent = Split-Path -Parent $trackedDestination
            if (-not (Test-Path -LiteralPath $trackedDestinationParent -PathType Container)) {
                New-Item -ItemType Directory -Path $trackedDestinationParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $trackedFile.Source -Destination $trackedDestination
        }
    }
    elseif (-not $sourceItem.PSIsContainer) {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath
    }
    else {
        Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Recurse
    }
}

function Write-PluginHookArtifact {
    <#
    .SYNOPSIS
    Materializes a hook manifest and its sibling script directory into a plugin.

    .DESCRIPTION
    Hook command paths in the source manifest are repository-root relative
    (for example .github/hooks/shared/telemetry/telemetry-collector.sh) so they resolve
    when the hook is auto-loaded from a checked-out repository. Inside an
    installed plugin the same scripts live under the plugin root, so this
    function writes a transformed copy of the manifest with those paths
    rewritten to the ${PLUGIN_ROOT} placeholder, then copies the sibling script
    directory (the manifest path without its .json extension) alongside it.

    .PARAMETER SourceManifest
    Absolute path to the source hook .json manifest in the repository.

    .PARAMETER DestinationManifest
    Absolute path where the transformed manifest is written in the plugin.

    .PARAMETER GeneratedFiles
    Set tracking generated paths for orphan cleanup; the copied script
    directory is added to it.

    .PARAMETER GeneratedDirectories
    Set tracking copied directory roots for subtree-aware orphan cleanup.

    .PARAMETER RepoRoot
    Absolute path to the repository root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceManifest,

        [Parameter(Mandatory = $true)]
        [string]$DestinationManifest,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$GeneratedFiles,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$GeneratedDirectories,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    # Degrade gracefully when the manifest is missing, matching how other kinds
    # warn rather than throw and fail the entire generation run.
    if (-not (Test-Path -LiteralPath $SourceManifest)) {
        Write-Warning "Hook manifest not found: $SourceManifest"
        return
    }

    # Rewrite repo-root-relative hook script paths to plugin-relative paths so
    # commands resolve from the installed plugin directory. Literal string
    # replacement avoids regex interpretation of the path and the $ placeholder.
    $manifestText = Get-Content -LiteralPath $SourceManifest -Raw -Encoding utf8
    $manifestText = $manifestText.Replace('.github/hooks/', '${PLUGIN_ROOT}/hooks/')
    Set-ContentIfChanged -Path $DestinationManifest -Value $manifestText | Out-Null

    # Copy the sibling script directory (manifest path without .json extension).
    $scriptSrc = $SourceManifest -replace '\.json$', ''
    if (Test-Path -LiteralPath $scriptSrc) {
        $scriptDest = $DestinationManifest -replace '\.json$', ''
        [void]$GeneratedFiles.Add($scriptDest)
        [void]$GeneratedDirectories.Add([System.IO.Path]::GetFullPath($scriptDest))
        New-PluginLink -SourcePath $scriptSrc -DestinationPath $scriptDest -RepoRoot $RepoRoot
        Add-GeneratedFilesForCopiedTree -SourcePath $scriptDest -GeneratedFiles $GeneratedFiles
    }
}

function Write-PluginDirectory {
    <#
    .SYNOPSIS
    Creates a complete plugin directory structure from a collection.

    .DESCRIPTION
    Builds the full plugin layout under the specified plugins directory,
    including subdirectories for agents, commands, instructions, and skills.
    Each item is copied from the repository into the plugin package.
    Generates plugin.json and README.md.

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
        [switch]$DryRun
    )

    $collectionId = $Collection.id
    $pluginRoot = Join-Path -Path $PluginsDir -ChildPath $collectionId

    $counts = @{
        AgentCount       = 0
        CommandCount      = 0
        InstructionCount = 0
        SkillCount       = 0
        HookCount        = 0
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
    $hookFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $readmeItems = @()
    $generatedFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $generatedDirectories = [System.Collections.Generic.HashSet[string]]::new(
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

            # Read description from the source file. Hook manifests are JSON
            # with no frontmatter, so read their top-level description field.
            $fallback = $itemName -replace '\.(md|json)$', ''
            if (-not (Test-Path -Path $sourcePath)) {
                $description = $fallback
                Write-Warning "Source file not found: $sourcePath"
            }
            elseif ($kind -eq 'hook') {
                $hookDesc = Get-ArtifactDescription -FilePath $sourcePath
                $description = if ($hookDesc) { $hookDesc } else { $fallback }
            }
            else {
                $frontmatter = Get-ArtifactFrontmatter -FilePath $sourcePath -FallbackDescription $fallback
                $description = $frontmatter.description
            }
        }

        $readmeItems += @{
            Name        = ($itemName -replace '\.md$', '') -replace '\.json$', ''
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
            'hook' {
                $counts.HookCount++
                $relPath = [System.IO.Path]::GetRelativePath($pluginRoot, $destPath) -replace '\\', '/'
                [void]$hookFiles.Add($relPath)
            }
        }

        [void]$generatedFiles.Add($destPath)
        if (Test-Path -LiteralPath $sourcePath -PathType Container) {
            [void]$generatedDirectories.Add([System.IO.Path]::GetFullPath($destPath))
        }

        if ($DryRun) {
            Write-Verbose "DryRun: Would copy $destPath <- $sourcePath"
            continue
        }

        # Hooks bundle a sibling script directory and need plugin-relative
        # command paths; other kinds copy their single source file directly.
        if ($kind -eq 'hook') {
            Write-PluginHookArtifact -SourceManifest $sourcePath -DestinationManifest $destPath `
                -GeneratedFiles $generatedFiles -GeneratedDirectories $generatedDirectories -RepoRoot $RepoRoot
        }
        else {
            New-PluginLink -SourcePath $sourcePath -DestinationPath $destPath -RepoRoot $RepoRoot
        }

        if ($kind -eq 'skill') {
            Add-GeneratedFilesForCopiedTree -SourcePath $destPath -GeneratedFiles $generatedFiles
        }
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
        [void]$generatedDirectories.Add([System.IO.Path]::GetFullPath($destPath))

        if ($DryRun) {
            Write-Verbose "DryRun: Would copy shared directory $destPath <- $sourcePath"
            continue
        }

        New-PluginLink -SourcePath $sourcePath -DestinationPath $destPath -RepoRoot $RepoRoot
        Add-GeneratedFilesForCopiedTree -SourcePath $destPath -GeneratedFiles $generatedFiles
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
        -SkillPaths @($skillDirs) `
        -HookPaths @($hookFiles)
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
        HookCount        = $counts.HookCount
        GeneratedFiles   = $generatedFiles
        GeneratedDirectories = $generatedDirectories
    }
}

Export-ModuleMember -Function @(
    'Add-GeneratedFilesForCopiedTree',
    'Get-PluginItemName',
    'Get-PluginItemSubpath',
    'Get-PluginSubdirectory',
    'New-GenerateResult',
    'New-MarketplaceManifestContent',
    'New-PluginLink',
    'New-PluginManifestContent',
    'New-PluginReadmeContent',
    'Write-MarketplaceManifest',
    'Write-PluginDirectory'
)
