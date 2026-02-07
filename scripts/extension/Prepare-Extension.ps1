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
    'PreRelease': Includes 'stable', 'preview', and 'experimental' maturity levels.

.PARAMETER DryRun
    Optional. If specified, shows what would be done without making changes.

.EXAMPLE
    ./Prepare-Extension.ps1
    # Prepares stable channel using existing version from package.json

.EXAMPLE
    ./Prepare-Extension.ps1 -Channel PreRelease
    # Prepares pre-release channel including experimental agents

.EXAMPLE
    ./Prepare-Extension.ps1 -ChangelogPath "./CHANGELOG.md"
    # Prepares with changelog

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
    [string]$Collection = ""
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Pure Functions

function Get-AllowedMaturities {
    <#
    .SYNOPSIS
        Returns allowed maturity levels based on release channel.
    .DESCRIPTION
        Pure function that determines which maturity levels (stable, preview, experimental)
        are included in the extension package based on the specified channel.
    .PARAMETER Channel
        Release channel. 'Stable' returns only stable; 'PreRelease' includes all levels.
    .OUTPUTS
        [string[]] Array of allowed maturity level strings.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    if ($Channel -eq 'PreRelease') {
        return @('stable', 'preview', 'experimental')
    }
    return @('stable')
}

function Get-RegistryData {
    <#
    .SYNOPSIS
        Loads the AI artifacts registry JSON file.
    .DESCRIPTION
        Reads and parses the AI artifacts registry JSON file into a hashtable
        containing artifact metadata keyed by type (agents, prompts, instructions, skills).
    .PARAMETER RegistryPath
        Path to the ai-artifacts-registry.json file.
    .OUTPUTS
        [hashtable] Parsed registry data with keys: agents, prompts, instructions, skills, personas, version.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistryPath
    )

    if (-not (Test-Path $RegistryPath)) {
        throw "AI artifacts registry not found: $RegistryPath"
    }

    $content = Get-Content -Path $RegistryPath -Raw
    return $content | ConvertFrom-Json -AsHashtable
}

function Get-CollectionManifest {
    <#
    .SYNOPSIS
        Loads a collection manifest JSON file.
    .DESCRIPTION
        Reads and parses a collection manifest JSON file that defines persona-based
        artifact filtering rules for extension packaging.
    .PARAMETER CollectionPath
        Path to the collection manifest JSON file.
    .OUTPUTS
        [hashtable] Parsed collection manifest with id, name, displayName, description, personas, and optional include/exclude.
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

    $content = Get-Content -Path $CollectionPath -Raw
    return $content | ConvertFrom-Json -AsHashtable
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
        Filters registry artifacts by collection persona, maturity, and glob patterns.
    .DESCRIPTION
        Applies collection-level filtering to the artifact registry, returning artifact
        names that match the collection's persona requirements, allowed maturities,
        and optional include/exclude glob patterns.
    .PARAMETER Registry
        AI artifacts registry hashtable.
    .PARAMETER Collection
        Collection manifest hashtable with personas and optional include/exclude.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Agents, Prompts, Instructions, Skills arrays of matching artifact names.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

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

    $collectionPersonas = $Collection.personas

    foreach ($type in @('agents', 'prompts', 'instructions', 'skills')) {
        if (-not $Registry.ContainsKey($type)) { continue }

        $includePatterns = @()
        $excludePatterns = @()
        if ($Collection.ContainsKey('include') -and $Collection.include.ContainsKey($type)) {
            $includePatterns = $Collection.include[$type]
        }
        if ($Collection.ContainsKey('exclude') -and $Collection.exclude.ContainsKey($type)) {
            $excludePatterns = $Collection.exclude[$type]
        }

        foreach ($name in $Registry[$type].Keys) {
            $entry = $Registry[$type][$name]

            # Persona filter: artifact must belong to at least one collection persona
            # Empty personas array means universal (all personas)
            $personaMatch = $false
            if (@($entry.personas).Count -eq 0) {
                $personaMatch = $true
            } else {
                foreach ($persona in $entry.personas) {
                    if ($collectionPersonas -contains $persona) {
                        $personaMatch = $true
                        break
                    }
                }
            }
            if (-not $personaMatch) { continue }

            # Maturity filter
            if ($AllowedMaturities -notcontains $entry.maturity) { continue }

            # Include glob filter (if specified)
            if ($includePatterns.Count -gt 0 -and -not (Test-GlobMatch -Name $name -Patterns $includePatterns)) {
                continue
            }

            # Exclude glob filter
            if ($excludePatterns.Count -gt 0 -and (Test-GlobMatch -Name $name -Patterns $excludePatterns)) {
                continue
            }

            $capitalType = @{ agents = 'Agents'; prompts = 'Prompts'; instructions = 'Instructions'; skills = 'Skills' }[$type]
            $result[$capitalType] += $name
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
    .PARAMETER SeedAgents
        Initial agent names to start BFS from.
    .PARAMETER AgentsDir
        Path to the agents directory containing .agent.md files.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER Registry
        AI artifacts registry hashtable for maturity lookup.
    .OUTPUTS
        [string[]] Complete set of agent names including seed agents and all transitive handoff targets.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SeedAgents,

        [Parameter(Mandatory = $true)]
        [string]$AgentsDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [hashtable]$Registry = @{}
    )

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($agent in $SeedAgents) {
        if ($visited.Add($agent)) {
            $queue.Enqueue($agent)
        }
    }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $agentFile = Join-Path $AgentsDir "$current.agent.md"

        if (-not (Test-Path $agentFile)) {
            Write-Warning "Handoff target agent file not found: $agentFile"
            continue
        }

        # Check maturity from registry
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('agents') -and $Registry.agents.ContainsKey($current)) {
            $maturity = $Registry.agents[$current].maturity
        }
        if ($AllowedMaturities -notcontains $maturity) { continue }

        # Parse handoffs from frontmatter
        $content = Get-Content -Path $agentFile -Raw
        if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
            try {
                $data = ConvertFrom-Yaml -Yaml $yamlContent
                if ($data.ContainsKey('handoffs') -and $data.handoffs -is [System.Collections.IEnumerable] -and $data.handoffs -isnot [string]) {
                    foreach ($handoff in $data.handoffs) {
                        # Handle both string format and object format (with 'agent' field)
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
                Write-Warning "Failed to parse handoffs from $current.agent.md: $_"
            }
        }
    }

    return @($visited)
}

function Resolve-RequiresDependencies {
    <#
    .SYNOPSIS
        Resolves transitive artifact dependencies from registry requires blocks.
    .DESCRIPTION
        Walks the requires blocks in agent registry entries to compute the
        complete set of dependent artifacts across all types (agents, prompts,
        instructions, skills) using BFS for transitive agent dependencies.
    .PARAMETER ArtifactNames
        Hashtable with initial artifact name arrays keyed by type (agents, prompts, instructions, skills).
    .PARAMETER Registry
        AI artifacts registry hashtable.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .OUTPUTS
        [hashtable] With Agents, Prompts, Instructions, Skills arrays containing resolved names.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ArtifactNames,

        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities
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

    # Walk requires for agents (only agents have requires blocks)
    $processedAgents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $agentQueue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($agent in $resolved.Agents) {
        $agentQueue.Enqueue($agent)
    }

    while ($agentQueue.Count -gt 0) {
        $current = $agentQueue.Dequeue()
        if (-not $processedAgents.Add($current)) { continue }

        if (-not $Registry.ContainsKey('agents') -or -not $Registry.agents.ContainsKey($current)) { continue }

        $entry = $Registry.agents[$current]
        if (-not $entry.ContainsKey('requires')) { continue }

        $requires = $entry.requires

        foreach ($type in @('agents', 'prompts', 'instructions', 'skills')) {
            if (-not $requires.ContainsKey($type)) { continue }
            $capitalType = $typeMap[$type]

            foreach ($dep in $requires[$type]) {
                # Check maturity of dependency
                if ($Registry.ContainsKey($type) -and $Registry[$type].ContainsKey($dep)) {
                    $depMaturity = $Registry[$type][$dep].maturity
                    if ($AllowedMaturities -notcontains $depMaturity) { continue }
                }

                if ($resolved[$capitalType].Add($dep)) {
                    if ($type -eq 'agents') {
                        $agentQueue.Enqueue($dep)
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

function Get-FrontmatterData {
    <#
    .SYNOPSIS
        Extracts description from YAML frontmatter.
    .DESCRIPTION
        Function that parses YAML frontmatter from a markdown file
        and returns a hashtable with the description value.
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
        [string]$FallbackDescription = ""
    )

    $content = Get-Content -Path $FilePath -Raw
    $description = ""

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
        extracts frontmatter description, filters by registry maturity and exclusion list,
        and returns structured agent objects.
    .PARAMETER AgentsDir
        Path to the agents directory.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER ExcludedAgents
        Array of agent names to exclude from packaging.
    .PARAMETER Registry
        AI artifacts registry hashtable for maturity lookup.
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
        [string[]]$ExcludedAgents = @(),

        [Parameter(Mandatory = $false)]
        [hashtable]$Registry = @{}
    )

    $result = @{
        Agents          = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $AgentsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $agentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" | Sort-Object Name

    foreach ($agentFile in $agentFiles) {
        $agentName = $agentFile.BaseName -replace '\.agent$', ''

        if ($ExcludedAgents -contains $agentName) {
            $result.Skipped += @{ Name = $agentName; Reason = 'excluded' }
            continue
        }

        # Determine maturity from registry if available, else default to stable
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('agents') -and $Registry.agents.ContainsKey($agentName)) {
            $maturity = $Registry.agents[$agentName].maturity
        }

        $frontmatter = Get-FrontmatterData -FilePath $agentFile.FullName -FallbackDescription "AI agent for $agentName"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $agentName; Reason = "maturity: $maturity" }
            continue
        }

        $result.Agents += [PSCustomObject]@{
            name        = $agentName
            path        = "./.github/agents/$($agentFile.Name)"
            description = $frontmatter.description
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
        extracts frontmatter description, filters by registry maturity, and returns
        structured prompt objects with relative paths.
    .PARAMETER PromptsDir
        Path to the prompts directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER Registry
        AI artifacts registry hashtable for maturity lookup.
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
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [hashtable]$Registry = @{}
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

    foreach ($promptFile in $promptFiles) {
        $promptName = $promptFile.BaseName -replace '\.prompt$', ''
        $displayName = ($promptName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }

        # Determine maturity from registry if available, else default to stable
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('prompts') -and $Registry.prompts.ContainsKey($promptName)) {
            $maturity = $Registry.prompts[$promptName].maturity
        }

        $frontmatter = Get-FrontmatterData -FilePath $promptFile.FullName -FallbackDescription "Prompt for $displayName"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $promptName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePath = [System.IO.Path]::GetRelativePath($GitHubDir, $promptFile.FullName) -replace '\\', '/'

        $result.Prompts += [PSCustomObject]@{
            name        = $promptName
            path        = "./.github/$relativePath"
            description = $frontmatter.description
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
        extracts frontmatter description, filters by registry maturity, and returns
        structured instruction objects with normalized paths.
    .PARAMETER InstructionsDir
        Path to the instructions directory.
    .PARAMETER GitHubDir
        Path to the .github directory for relative path calculation.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER Registry
        AI artifacts registry hashtable for maturity lookup.
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
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [hashtable]$Registry = @{}
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

    foreach ($instrFile in $instructionFiles) {
        $baseName = $instrFile.BaseName -replace '\.instructions$', ''
        $instrName = "$baseName-instructions"
        $displayName = ($baseName -replace '-', ' ') -replace '(\b\w)', { $_.Groups[1].Value.ToUpper() }

        # Determine maturity from registry using relative path key
        $relPath = [System.IO.Path]::GetRelativePath($InstructionsDir, $instrFile.FullName) -replace '\\', '/'
        $registryKey = $relPath -replace '\.instructions\.md$', ''
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('instructions') -and $Registry.instructions.ContainsKey($registryKey)) {
            $maturity = $Registry.instructions[$registryKey].maturity
        }

        $frontmatter = Get-FrontmatterData -FilePath $instrFile.FullName -FallbackDescription "Instructions for $displayName"

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $instrName; Reason = "maturity: $maturity" }
            continue
        }

        $relativePathFromGitHub = [System.IO.Path]::GetRelativePath($GitHubDir, $instrFile.FullName)
        $normalizedRelativePath = (Join-Path ".github" $relativePathFromGitHub) -replace '\\', '/'

        $result.Instructions += [PSCustomObject]@{
            name        = $instrName
            path        = "./$normalizedRelativePath"
            description = $frontmatter.description
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
        containing SKILL.md files, filters by registry maturity, and returns
        structured skill objects.
    .PARAMETER SkillsDir
        Path to the skills directory.
    .PARAMETER AllowedMaturities
        Array of maturity levels to include.
    .PARAMETER Registry
        AI artifacts registry hashtable for maturity lookup.
    .OUTPUTS
        [hashtable] With Skills array, Skipped array, and DirectoryExists bool.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsDir,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedMaturities,

        [Parameter(Mandatory = $false)]
        [hashtable]$Registry = @{}
    )

    $result = @{
        Skills          = @()
        Skipped         = @()
        DirectoryExists = (Test-Path $SkillsDir)
    }

    if (-not $result.DirectoryExists) {
        return $result
    }

    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory | Sort-Object Name

    foreach ($skillDir in $skillDirs) {
        $skillName = $skillDir.Name
        $skillFile = Join-Path $skillDir.FullName "SKILL.md"

        if (-not (Test-Path $skillFile)) {
            $result.Skipped += @{ Name = $skillName; Reason = 'missing SKILL.md' }
            continue
        }

        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('skills') -and $Registry.skills.ContainsKey($skillName)) {
            $maturity = $Registry.skills[$skillName].maturity
        }

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $skillName; Reason = "maturity: $maturity" }
            continue
        }

        $frontmatter = Get-FrontmatterData -FilePath $skillFile -FallbackDescription "Skill for $skillName"

        $result.Skills += [PSCustomObject]@{
            name        = $skillName
            path        = "./.github/skills/$skillName"
            description = $frontmatter.description
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

function Test-CollectionManifestCompleteness {
    <#
    .SYNOPSIS
        Validates collection manifest contains all required fields for packaging.
    .DESCRIPTION
        Ensures collection manifest has all required fields needed for Option A
        dynamic package.json generation: id, name, displayName, description,
        publisher, and personas.
    .PARAMETER Manifest
        Parsed collection manifest hashtable.
    .OUTPUTS
        None. Throws on validation failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Manifest
    )

    $requiredFields = @('id', 'name', 'displayName', 'description', 'publisher', 'personas')
    $missing = @()

    foreach ($field in $requiredFields) {
        if (-not $Manifest.ContainsKey($field) -or [string]::IsNullOrWhiteSpace($Manifest[$field])) {
            $missing += $field
        }
    }

    if ($missing.Count -gt 0) {
        throw "Collection manifest missing required fields: $($missing -join ', ')"
    }

    Write-Host "✓ Collection manifest validation passed" -ForegroundColor Green
}

function New-ReadmeFromRegistry {
    <#
    .SYNOPSIS
        Generates README content from registry and collection manifest.
    .DESCRIPTION
        Creates a complete README.md file for the extension by pulling artifact
        descriptions from the AI artifacts registry. Used for Option A packaging
        to eliminate hand-authored per-persona README files.
    .PARAMETER CollectionManifest
        Collection manifest hashtable containing displayName and description.
    .PARAMETER Registry
        AI artifacts registry hashtable with agents, prompts, instructions, skills.
    .PARAMETER ArtifactNames
        Hashtable with Agents, Prompts, Instructions, Skills string arrays.
    .PARAMETER Channel
        Release channel (Stable or PreRelease) for documentation.
    .OUTPUTS
        [string] Complete README.md markdown content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest,

        [Parameter(Mandatory = $true)]
        [hashtable]$Registry,

        [Parameter(Mandatory = $true)]
        [hashtable]$ArtifactNames,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'Stable'
    )

    $readme = @"
# $($CollectionManifest.displayName)

> $($CollectionManifest.description)

This extension provides AI chat agents, prompts, and instructions for use with GitHub Copilot in VS Code.

## Features

"@

    # Add agents section
    if ($ArtifactNames.Agents.Count -gt 0) {
        $readme += @"

### 🤖 Chat Agents

| Agent | Description |
| ----- | ----------- |

"@
        foreach ($agentName in ($ArtifactNames.Agents | Sort-Object)) {
            $agentDesc = "Agent for $agentName"
            if ($Registry.agents -and $Registry.agents[$agentName] -and $Registry.agents[$agentName].description) {
                $agentDesc = $Registry.agents[$agentName].description
            }
            $readme += "| **$agentName** | $agentDesc |`n"
        }
    }

    # Add prompts section
    if ($ArtifactNames.Prompts.Count -gt 0) {
        $readme += @"

### 📝 Prompts

| Prompt | Description |
| ------ | ----------- |

"@
        foreach ($promptName in ($ArtifactNames.Prompts | Sort-Object)) {
            $promptDesc = "Prompt for $promptName"
            if ($Registry.prompts -and $Registry.prompts[$promptName] -and $Registry.prompts[$promptName].description) {
                $promptDesc = $Registry.prompts[$promptName].description
            }
            $readme += "| **$promptName** | $promptDesc |`n"
        }
    }

    # Add instructions section
    if ($ArtifactNames.Instructions.Count -gt 0) {
        $readme += @"

### 📚 Instructions

| Instruction | Description |
| ----------- | ----------- |

"@
        foreach ($instructionName in ($ArtifactNames.Instructions | Sort-Object)) {
            $instructionDesc = "Instructions for $instructionName"
            if ($Registry.instructions -and $Registry.instructions[$instructionName] -and $Registry.instructions[$instructionName].description) {
                $instructionDesc = $Registry.instructions[$instructionName].description
            }
            $readme += "| **$instructionName** | $instructionDesc |`n"
        }
    }

    # Add skills section
    if ($ArtifactNames.Skills.Count -gt 0) {
        $readme += @"

### ⚡ Skills

| Skill | Description |
| ----- | ----------- |

"@
        foreach ($skillName in ($ArtifactNames.Skills | Sort-Object)) {
            $skillDesc = "Skill for $skillName"
            if ($Registry.skills -and $Registry.skills[$skillName] -and $Registry.skills[$skillName].description) {
                $skillDesc = $Registry.skills[$skillName].description
            }
            $readme += "| **$skillName** | $skillDesc |`n"
        }
    }

    # Add getting started section
    $readme += @"

## Getting Started

After installing this extension, the chat agents will be available in GitHub Copilot Chat. You can:

1. **Use custom agents** by selecting them from the agent picker in Copilot Chat
2. **Apply prompts** through the Copilot Chat interface
3. **Reference instructions** — They're automatically applied based on file patterns

## Requirements

- VS Code version 1.106.1 or higher
- GitHub Copilot extension

## License

MIT License - see [LICENSE](LICENSE) for details

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/microsoft/hve-core).

---

Brought to you by Microsoft ISE HVE Essentials
"@

    return $readme
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
        [string]$Collection = ""
    )

    # Derive paths
    $GitHubDir = Join-Path $RepoRoot ".github"
    $PackageJsonPath = Join-Path $ExtensionDirectory "package.json"

    # Track whether package.json was modified for restoration
    $needsRestore = $false
    $modifiedCollectionId = ""

    try {
        # Validate required paths exist
        $pathValidation = Test-PathsExist -ExtensionDir $ExtensionDirectory `
            -PackageJsonPath $PackageJsonPath `
            -GitHubDir $GitHubDir
        if (-not $pathValidation.IsValid) {
            $missingPaths = $pathValidation.MissingPaths -join ', '
            return New-PrepareResult -Success $false -ErrorMessage "Required paths not found: $missingPaths"
        }

    # Load AI artifacts registry if available
    $registryPath = Join-Path $GitHubDir "ai-artifacts-registry.json"
    $registry = @{}
    if (Test-Path $registryPath) {
        $registry = Get-RegistryData -RegistryPath $registryPath
        Write-Host "Registry loaded: $registryPath"
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

    if ($Collection -and $Collection -ne "") {
        $collectionManifest = Get-CollectionManifest -CollectionPath $Collection
        Write-Host "Collection: $($collectionManifest.displayName) ($($collectionManifest.id))"

        # Validate collection manifest completeness before processing
        if ($collectionManifest.id -ne 'hve-core-all') {
            try {
                Test-CollectionManifestCompleteness -Manifest $collectionManifest
            }
            catch {
                return New-PrepareResult -Success $false -ErrorMessage $_.Exception.Message
            }
        }

        # Get persona-filtered artifact names
        $collectionArtifactNames = Get-CollectionArtifacts -Registry $registry -Collection $collectionManifest -AllowedMaturities $allowedMaturities

        # Resolve handoff dependencies (agents only)
        $agentsDir = Join-Path $GitHubDir "agents"
        $expandedAgents = Resolve-HandoffDependencies -SeedAgents $collectionArtifactNames.Agents -AgentsDir $agentsDir -AllowedMaturities $allowedMaturities -Registry $registry
        $collectionArtifactNames.Agents = $expandedAgents

        # Resolve requires dependencies
        $resolvedNames = Resolve-RequiresDependencies -ArtifactNames @{
            agents       = $collectionArtifactNames.Agents
            prompts      = $collectionArtifactNames.Prompts
            instructions = $collectionArtifactNames.Instructions
            skills       = $collectionArtifactNames.Skills
        } -Registry $registry -AllowedMaturities $allowedMaturities

        $collectionArtifactNames = @{
            Agents       = $resolvedNames.Agents
            Prompts      = $resolvedNames.Prompts
            Instructions = $resolvedNames.Instructions
            Skills       = $resolvedNames.Skills
        }
    }

    # Discover agents
    $agentsDir = Join-Path $GitHubDir "agents"
    $agentResult = Get-DiscoveredAgents -AgentsDir $agentsDir -AllowedMaturities $allowedMaturities -ExcludedAgents @() -Registry $registry
    $chatAgents = $agentResult.Agents
    $excludedAgents = $agentResult.Skipped

    Write-Host "`n--- Chat Agents ---" -ForegroundColor Green
    Write-Host "Found $($chatAgents.Count) agent(s) matching criteria"
    if ($excludedAgents.Count -gt 0) {
        Write-Host "Excluded $($excludedAgents.Count) agent(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover prompts
    $promptsDir = Join-Path $GitHubDir "prompts"
    $promptResult = Get-DiscoveredPrompts -PromptsDir $promptsDir -GitHubDir $GitHubDir -AllowedMaturities $allowedMaturities -Registry $registry
    $chatPrompts = $promptResult.Prompts
    $excludedPrompts = $promptResult.Skipped

    Write-Host "`n--- Chat Prompts ---" -ForegroundColor Green
    Write-Host "Found $($chatPrompts.Count) prompt(s) matching criteria"
    if ($excludedPrompts.Count -gt 0) {
        Write-Host "Excluded $($excludedPrompts.Count) prompt(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover instructions
    $instructionsDir = Join-Path $GitHubDir "instructions"
    $instructionResult = Get-DiscoveredInstructions -InstructionsDir $instructionsDir -GitHubDir $GitHubDir -AllowedMaturities $allowedMaturities -Registry $registry
    $chatInstructions = $instructionResult.Instructions
    $excludedInstructions = $instructionResult.Skipped

    Write-Host "`n--- Chat Instructions ---" -ForegroundColor Green
    Write-Host "Found $($chatInstructions.Count) instruction(s) matching criteria"
    if ($excludedInstructions.Count -gt 0) {
        Write-Host "Excluded $($excludedInstructions.Count) instruction(s) due to maturity filter" -ForegroundColor Yellow
    }

    # Discover skills
    $skillsDir = Join-Path $GitHubDir "skills"
    $skillResult = Get-DiscoveredSkills -SkillsDir $skillsDir -AllowedMaturities $allowedMaturities -Registry $registry
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

    # Apply persona template when building a non-default collection
    if ($null -ne $collectionManifest -and $collectionManifest.id -ne 'hve-core-all') {
        # Read canonical package.json
        $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json

        # Override metadata from collection manifest (in-place)
        # Use Add-Member to ensure properties exist before setting
        if (-not $packageJson.PSObject.Properties['name']) {
            $packageJson | Add-Member -NotePropertyName 'name' -NotePropertyValue $collectionManifest.name
        } else {
            $packageJson.name = $collectionManifest.name
        }

        if (-not $packageJson.PSObject.Properties['displayName']) {
            $packageJson | Add-Member -NotePropertyName 'displayName' -NotePropertyValue $collectionManifest.displayName
        } else {
            $packageJson.displayName = $collectionManifest.displayName
        }

        if (-not $packageJson.PSObject.Properties['description']) {
            $packageJson | Add-Member -NotePropertyName 'description' -NotePropertyValue $collectionManifest.description
        } else {
            $packageJson.description = $collectionManifest.description
        }

        if ($collectionManifest.ContainsKey('publisher')) {
            if (-not $packageJson.PSObject.Properties['publisher']) {
                $packageJson | Add-Member -NotePropertyName 'publisher' -NotePropertyValue $collectionManifest.publisher
            } else {
                $packageJson.publisher = $collectionManifest.publisher
            }
        }

        # Mark for restoration after build
        $needsRestore = $true
        $modifiedCollectionId = $collectionManifest.id

        Write-Host "Applied metadata from collection: $($collectionManifest.id)" -ForegroundColor Green

        # Write metadata changes immediately so they're visible even in DryRun
        # (tests expect to read modified package.json from disk)
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path $PackageJsonPath -Encoding UTF8NoBOM
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

    # Generate README from registry when building a collection
    if ($null -ne $collectionManifest) {
        Write-Host "`nGenerating README from registry..." -ForegroundColor Cyan
        
        # Build artifact names list from discovered artifacts
        $artifactNamesForReadme = @{
            Agents       = @($chatAgents | ForEach-Object { $_.name })
            Prompts      = @($chatPrompts | ForEach-Object { $_.name })
            Instructions = @($chatInstructions | ForEach-Object { $_.name -replace '-instructions$', '' })
            Skills       = @($chatSkills | ForEach-Object { $_.name })
        }
        
        $readmeContent = New-ReadmeFromRegistry `
            -CollectionManifest $collectionManifest `
            -Registry $registry `
            -ArtifactNames $artifactNamesForReadme `
            -Channel $Channel
        
        $readmePath = Join-Path $ExtensionDirectory "README.md"
        if (-not $DryRun) {
            Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8NoBOM
            Write-Host "✓ README generated: $readmePath" -ForegroundColor Green
        }
        else {
            Write-Host "[DRY RUN] Would generate README: $readmePath" -ForegroundColor Yellow
        }
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
    finally {
        # Restore canonical package.json from git if it was modified
        if ($needsRestore -and -not $DryRun) {
            Write-Host "`nRestoring canonical package.json from git..." -ForegroundColor Cyan
            $gitRestore = & git checkout HEAD -- extension/package.json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Package.json restored successfully" -ForegroundColor Green
            }
            else {
                Write-Warning "Failed to restore package.json from git. Manual restore may be required."
                Write-Warning "Error: $gitRestore"
            }
        }
    }
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

        Write-Host "📦 HVE Core Extension Preparer" -ForegroundColor Cyan
        Write-Host "==============================" -ForegroundColor Cyan
        Write-Host "   Channel: $Channel" -ForegroundColor Cyan
        if ($Collection) {
            Write-Host "   Collection: $Collection" -ForegroundColor Cyan
        }
        Write-Host ""

        # Call orchestration function
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $ExtensionDir `
            -RepoRoot $RepoRoot `
            -Channel $Channel `
            -ChangelogPath $resolvedChangelogPath `
            -DryRun:$DryRun `
            -Collection $Collection

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
        Write-Error "Prepare Extension failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
