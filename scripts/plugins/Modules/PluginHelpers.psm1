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

function Get-CollectionManifest {
    <#
    .SYNOPSIS
    Reads and parses a .collection.yml file.

    .DESCRIPTION
    Loads a collection manifest YAML file and returns its parsed content
    as a hashtable using ConvertFrom-Yaml.

    .PARAMETER CollectionPath
    Absolute or relative path to the .collection.yml file.

    .OUTPUTS
    [hashtable] Parsed collection data with id, name, description, items, etc.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionPath
    )

    $content = Get-Content -Path $CollectionPath -Raw
    $manifest = ConvertFrom-Yaml -Yaml $content

    return $manifest
}

function Get-ArtifactFrontmatter {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a markdown file.

    .DESCRIPTION
    Parses the YAML frontmatter block delimited by --- markers at the start
    of a markdown file. Returns a hashtable with description and maturity keys.

    .PARAMETER FilePath
    Path to the markdown file to parse.

    .PARAMETER FallbackDescription
    Default description if none found in frontmatter.

    .OUTPUTS
    [hashtable] With description and maturity keys.
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
    $maturity = 'stable'

    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
            if ($data.ContainsKey('description')) {
                $description = $data.description
            }
            if ($data.ContainsKey('maturity')) {
                $maturity = $data.maturity
            }
        }
        catch {
            Write-Warning "Failed to parse YAML frontmatter in $(Split-Path -Leaf $FilePath): $_"
        }
    }

    return @{
        description = if ($description) { $description } else { $FallbackDescription }
        maturity    = $maturity
    }
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

    # Agents
    $agentsDir = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
    if (Test-Path -Path $agentsDir) {
        $agentFiles = Get-ChildItem -Path $agentsDir -Filter '*.agent.md' -File
        foreach ($file in $agentFiles) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            $items += @{ path = $relativePath; kind = 'agent' }
        }
    }

    # Prompts
    $promptsDir = Join-Path -Path $RepoRoot -ChildPath '.github/prompts'
    if (Test-Path -Path $promptsDir) {
        $promptFiles = Get-ChildItem -Path $promptsDir -Filter '*.prompt.md' -File
        foreach ($file in $promptFiles) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            $items += @{ path = $relativePath; kind = 'prompt' }
        }
    }

    # Instructions (recursive for subfolders)
    $instructionsDir = Join-Path -Path $RepoRoot -ChildPath '.github/instructions'
    if (Test-Path -Path $instructionsDir) {
        $instructionFiles = Get-ChildItem -Path $instructionsDir -Filter '*.instructions.md' -File -Recurse
        foreach ($file in $instructionFiles) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            $items += @{ path = $relativePath; kind = 'instruction' }
        }
    }

    # Skills (directories containing SKILL.md)
    $skillsDir = Join-Path -Path $RepoRoot -ChildPath '.github/skills'
    if (Test-Path -Path $skillsDir) {
        $skillDirs = Get-ChildItem -Path $skillsDir -Directory
        foreach ($dir in $skillDirs) {
            $skillFile = Join-Path -Path $dir.FullName -ChildPath 'SKILL.md'
            if (Test-Path -Path $skillFile) {
                $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $dir.FullName) -replace '\\', '/'
                $items += @{ path = $relativePath; kind = 'skill' }
            }
        }
    }

    return $items
}

function Test-ArtifactDeprecated {
    <#
    .SYNOPSIS
    Checks whether an artifact has maturity: deprecated in its frontmatter.

    .DESCRIPTION
    Reads the frontmatter of the artifact file (or SKILL.md for skills) and
    returns $true when the maturity field equals deprecated.

    .PARAMETER ItemPath
    Repo-relative path to the artifact.

    .PARAMETER Kind
    The artifact kind: agent, prompt, instruction, or skill.

    .PARAMETER RepoRoot
    Absolute path to the repository root.

    .OUTPUTS
    [bool] True when the artifact is deprecated.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ItemPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    if ($Kind -eq 'skill') {
        $filePath = Join-Path -Path $RepoRoot -ChildPath $ItemPath -AdditionalChildPath 'SKILL.md'
    }
    else {
        $filePath = Join-Path -Path $RepoRoot -ChildPath $ItemPath
    }

    if (-not (Test-Path -Path $filePath)) {
        return $false
    }

    $frontmatter = Get-ArtifactFrontmatter -FilePath $filePath
    return ($frontmatter.maturity -eq 'deprecated')
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

    # Filter deprecated
    $deprecatedCount = 0
    $filteredItems = @()
    foreach ($item in $allItems) {
        if (Test-ArtifactDeprecated -ItemPath $item.path -Kind $item.kind -RepoRoot $RepoRoot) {
            $deprecatedCount++
            Write-Verbose "Excluding deprecated: $($item.path)"
            continue
        }
        $filteredItems += $item
    }

    # Sort: by kind order (agent, prompt, instruction, skill), then by path
    $kindOrder = @{ 'agent' = 0; 'prompt' = 1; 'instruction' = 2; 'skill' = 3 }
    $sortedItems = $filteredItems | Sort-Object { $kindOrder[$_.kind] }, { $_.path }

    # Build new items array as ordered hashtables for clean YAML output
    $newItems = @()
    foreach ($item in $sortedItems) {
        $newItems += [ordered]@{
            path = $item.path
            kind = $item.kind
        }
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
        $manifest = [ordered]@{
            id          = $existing.id
            name        = $existing.name
            description = $existing.description
            tags        = $existing.tags
            items       = $newItems
            display     = $existing.display
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
    description, and a default version of 1.0.0.

    .PARAMETER CollectionId
    The collection identifier used as the plugin name.

    .PARAMETER Description
    A short description of the plugin.

    .OUTPUTS
    [hashtable] Plugin manifest with name, description, and version keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionId,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    return [ordered]@{
        name        = $CollectionId
        description = $Description
        version     = '1.0.0'
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
        [array]$Items
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- markdownlint-disable-file -->')
    [void]$sb.AppendLine("# $($Collection.name)")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($Collection.description)
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

function New-RelativeSymlink {
    <#
    .SYNOPSIS
    Creates a relative symlink from destination to source.

    .DESCRIPTION
    Calculates the relative path from the directory containing the destination
    to the source path, then creates a symbolic link at the destination
    pointing to that relative path.

    .PARAMETER SourcePath
    Absolute path to the symlink target (the real file or directory).

    .PARAMETER DestinationPath
    Absolute path where the symlink will be created.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $destinationDir = Split-Path -Parent $DestinationPath
    $relativePath = [System.IO.Path]::GetRelativePath($destinationDir, $SourcePath)

    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $DestinationPath -Value $relativePath -Force | Out-Null
}

function Write-PluginDirectory {
    <#
    .SYNOPSIS
    Creates a complete plugin directory structure from a collection.

    .DESCRIPTION
    Builds the full plugin layout under the specified plugins directory,
    including subdirectories for agents, commands, instructions, and skills.
    Each item is symlinked from the plugin directory back to its source in
    the repository. Generates plugin.json and README.md.

    .PARAMETER Collection
    Parsed collection manifest hashtable with id, name, description, and items.

    .PARAMETER PluginsDir
    Absolute path to the root plugins output directory.

    .PARAMETER RepoRoot
    Absolute path to the repository root.

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
            Write-Verbose "DryRun: Would create symlink $destPath -> $sourcePath"
            continue
        }

        New-RelativeSymlink -SourcePath $sourcePath -DestinationPath $destPath
    }

    # Generate plugin.json
    $manifestDir = Join-Path -Path $pluginRoot -ChildPath '.github' -AdditionalChildPath 'plugin'
    $manifestPath = Join-Path -Path $manifestDir -ChildPath 'plugin.json'
    $manifest = New-PluginManifestContent -CollectionId $collectionId -Description $Collection.description

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
    $readmeContent = New-PluginReadmeContent -Collection $Collection -Items $readmeItems

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

Export-ModuleMember -Function @(
    'Get-ArtifactFiles',
    'Get-ArtifactFrontmatter',
    'Get-AllCollections',
    'Get-CollectionManifest',
    'Get-PluginItemName',
    'Get-PluginSubdirectory',
    'New-GenerateResult',
    'New-PluginManifestContent',
    'New-PluginReadmeContent',
    'New-RelativeSymlink',
    'Test-ArtifactDeprecated',
    'Update-HveCoreAllCollection',
    'Write-PluginDirectory'
)
