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

        if ($AllowedMaturities -notcontains $maturity) {
            $result.Skipped += @{ Name = $agentName; Reason = "maturity: $maturity" }
            continue
        }

        $result.Agents += [PSCustomObject]@{
            name = $agentName
            path = "./.github/agents/$($agentFile.Name)"
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
        # Determine maturity from registry if available, else default to stable
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('prompts') -and $Registry.prompts.ContainsKey($promptName)) {
            $maturity = $Registry.prompts[$promptName].maturity
        }

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
        # Skip repo-specific instructions not intended for distribution
        $instrRelPath = [System.IO.Path]::GetRelativePath($InstructionsDir, $instrFile.FullName) -replace '\\', '/'
        if ($instrRelPath -like 'hve-core/*') {
            $result.Skipped += @{ Name = $instrFile.BaseName; Reason = 'repo-specific (hve-core/)' }
            continue
        }
        $baseName = $instrFile.BaseName -replace '\.instructions$', ''
        $instrName = "$baseName-instructions"

        # Determine maturity from registry using relative path key
        $relPath = [System.IO.Path]::GetRelativePath($InstructionsDir, $instrFile.FullName) -replace '\\', '/'
        $registryKey = $relPath -replace '\.instructions\.md$', ''
        $maturity = "stable"
        if ($Registry.Count -gt 0 -and $Registry.ContainsKey('instructions') -and $Registry.instructions.ContainsKey($registryKey)) {
            $maturity = $Registry.instructions[$registryKey].maturity
        }

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

        $result.Skills += [PSCustomObject]@{
            name = $skillName
            path = "./.github/skills/$skillName"
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
        Validates persona template metadata against its collection manifest.
    .DESCRIPTION
        Compares name, displayName, and description fields between a persona
        package template (e.g. package.developer.json) and the corresponding
        collection manifest. Emits warnings for divergences and returns a list
        of mismatches.
    .PARAMETER TemplatePath
        Path to the persona package template JSON file.
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
        $collectionId = $collectionManifest.id
        $templatePath = Join-Path $ExtensionDirectory "package.$collectionId.json"
        if (-not (Test-Path $templatePath)) {
            return New-PrepareResult -Success $false -ErrorMessage "Persona template not found: $templatePath"
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

        # Copy persona template over package.json
        Copy-Item -Path $templatePath -Destination $PackageJsonPath -Force

        # Re-read template as the working package.json
        $packageJson = Get-Content -Path $PackageJsonPath -Raw | ConvertFrom-Json
        Write-Host "Applied persona template: package.$collectionId.json" -ForegroundColor Green
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
