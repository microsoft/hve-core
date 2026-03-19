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
Import-Module (Join-Path $PSScriptRoot "../collections/Modules/CollectionHelpers.psm1") -Force

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
        Removes generated collection package files that are no longer expected.
    .DESCRIPTION
        Scans extension/ for package.*.json files and removes any not in the
        expected set, keeping the directory clean of orphaned collection templates.
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
    Get-ChildItem -Path $extensionDir -Filter 'package.*.json' -File | ForEach-Object {
        $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
        if (-not $expected.Contains($fullPath)) {
            Remove-Item -Path $_.FullName -Force
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
        extension/package.{id}.json for every other collection. Stale collection
        files are removed.
    .PARAMETER RepoRoot
        Repository root path containing collections/ and extension/templates/.
    .OUTPUTS
        [string[]] Array of generated file paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
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

    $collectionFiles = Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File | Sort-Object Name
    if ($collectionFiles.Count -eq 0) {
        throw "No root collection files found in $collectionsDir"
    }

    $expectedFiles = @()

    foreach ($collectionFile in $collectionFiles) {
        $collection = Get-CollectionManifest -CollectionPath $collectionFile.FullName
        if ($collection -isnot [hashtable]) {
            throw "Collection manifest must be a hashtable: $($collectionFile.FullName)"
        }

        $collectionId = [string]$collection.id
        if ([string]::IsNullOrWhiteSpace($collectionId)) {
            throw "Collection id is required: $($collectionFile.FullName)"
        }

        $collectionDescription = if ($collection.ContainsKey('description')) { [string]$collection.description } else { [string]$packageTemplate.description }

        $extensionName = switch ($collectionId) {
            'hve-core'     { [string]$packageTemplate.name }
            'hve-core-all' { 'hve-core-all' }
            default        { "hve-$collectionId" }
        }
        $extensionDisplayName = switch ($collectionId) {
            'hve-core'     { [string]$packageTemplate.displayName }
            'hve-core-all' { 'HVE Core - All' }
            default        { Get-CollectionDisplayName -CollectionManifest $collection -DefaultValue ([string]$packageTemplate.displayName) }
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
    }

    Remove-StaleGeneratedFiles -RepoRoot $RepoRoot -ExpectedFiles $expectedFiles

    # Generate README files for each collection
    $readmeTemplatePath = Join-Path $templatesDir 'README.template.md'
    foreach ($collectionFile in $collectionFiles) {
        $collection = Get-CollectionManifest -CollectionPath $collectionFile.FullName
        $collectionId = [string]$collection.id

        $collectionMdPath = Join-Path $collectionsDir "$collectionId.collection.md"
        if (-not (Test-Path $collectionMdPath)) {
            continue
        }

        $readmePath = switch ($collectionId) {
            'hve-core'     { Join-Path $RepoRoot 'extension/README.md' }
            'hve-core-all' { Join-Path $RepoRoot 'extension/README.hve-core-all.md' }
            default        { Join-Path $RepoRoot "extension/README.$collectionId.md" }
        }

        New-CollectionReadme -Collection $collection -CollectionMdPath $collectionMdPath -TemplatePath $readmeTemplatePath -RepoRoot $RepoRoot -OutputPath $readmePath
    }

    return $expectedFiles
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
    .PARAMETER Collection
        Parsed collection manifest hashtable.
    .PARAMETER CollectionMdPath
        Path to the collection markdown body file.
    .PARAMETER TemplatePath
        Path to the README template file containing placeholder tokens.
    .PARAMETER RepoRoot
        Repository root path for resolving artifact file paths.
    .PARAMETER OutputPath
        Destination path for the generated README.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $true)]
        [string]$CollectionMdPath,

        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $collectionId = [string]$Collection.id
    $displayName = switch ($collectionId) {
        'hve-core'     { 'HVE Core' }
        'hve-core-all' { 'HVE Core - All' }
        default        { Get-CollectionDisplayName -CollectionManifest $Collection -DefaultValue "HVE Core - $collectionId" }
    }
    $description = if ($Collection.ContainsKey('description')) { [string]$Collection.description } else { '' }

    $collectionMaturity = if ($Collection.ContainsKey('maturity') -and -not [string]::IsNullOrWhiteSpace([string]$Collection.maturity)) {
        [string]$Collection.maturity
    } else { 'stable' }

    $maturityNotice = if ($collectionMaturity -eq 'experimental') {
        '> **⚠️ Experimental** — This collection is experimental and available only in the Pre-Release channel. Contents may change or be removed without notice.'
    } else { '' }

    $bodyContent = (Get-Content -Path $CollectionMdPath -Raw).Trim()

    # Collect artifacts with descriptions grouped by kind
    $agents = @()
    $prompts = @()
    $instructions = @()
    $skills = @()

    if ($Collection.ContainsKey('items')) {
        foreach ($item in $Collection.items) {
            if (-not $item.ContainsKey('kind') -or -not $item.ContainsKey('path')) {
                continue
            }
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
        -replace '\{\{BODY\}\}', $bodyContent `
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
    $agentIndex = @{}
    $allAgentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" -Recurse -File
    foreach ($af in $allAgentFiles) {
        $stem = $af.BaseName -replace '\.agent$', ''
        $agentIndex[$stem] = $af

        $fc = Get-Content -Path $af.FullName -Raw
        if ($fc -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            $yml = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
            try {
                $meta = ConvertFrom-Yaml -Yaml $yml
                if ($meta.ContainsKey('name') -and $meta.name -is [string] -and $meta.name -ne '') {
                    if (-not $agentIndex.ContainsKey($meta.name)) {
                        $agentIndex[$meta.name] = $af
                    }
                }
            }
            catch {
                Write-Verbose "Skipping display name index for $($af.Name): $_"
            }
        }
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

        if (-not $agentFile) {
            Write-Warning "Handoff target agent file not found: $current"
            continue
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

    # Generate collection package files from root collection manifests.
    # This ensures extension/package.json and extension/package.*.json exist
    # with the correct version from the template before any reads occur.
    try {
        $generated = Invoke-ExtensionCollectionsGeneration -RepoRoot $RepoRoot
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
        Write-Error -ErrorAction Continue "Prepare-Extension failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
