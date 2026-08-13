# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# PluginTestFixtures.psm1
#
# Purpose: Synthetic repository fixtures for the plugin pipeline test suite.
# Author: HVE Core Team

#Requires -Version 7.4

function Invoke-PluginFixtureGit {
    <#
    .SYNOPSIS
    Runs a git command against a fixture repository and fails loudly.

    .PARAMETER RepoRoot
    Fixture repository working tree.

    .PARAMETER Arguments
    Git arguments following the -C switch.

    .OUTPUTS
    [string[]] Command output lines.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = @(& git -C $RepoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture git command failed ($($Arguments -join ' ')): $($output -join ' ')"
    }
    return [string[]]$output
}

function New-PluginFixtureRepository {
    <#
    .SYNOPSIS
    Creates an isolated git working tree that mimics the repository layout.

    .DESCRIPTION
    Initializes a standalone git repository containing package.json, the shared
    .github/plugin.json manifest, and the canonical roots the plugin pipeline
    reads. Nothing is committed, because every production reader consults the
    index rather than history.

    .PARAMETER Path
    Directory to initialize.

    .PARAMETER Version
    Version recorded in the fixture package.json.

    .PARAMETER SkipAgentRoot
    Omits the .github/agents root so a missing canonical root can be tested.

    .PARAMETER SkipDocumentationRoot
    Omits the docs/plugins root so a missing documentation root can be tested.

    .PARAMETER SkipSharedResources
    Omits docs/templates and scripts/lib shared resource trees.

    .OUTPUTS
    [string] Absolute path to the initialized working tree.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Version = '9.9.9',

        [Parameter(Mandatory = $false)]
        [switch]$SkipAgentRoot,

        [Parameter(Mandatory = $false)]
        [switch]$SkipDocumentationRoot,

        [Parameter(Mandatory = $false)]
        [switch]$SkipSharedResources
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    $initOutput = @(& git -c init.defaultBranch=main init --quiet $Path 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Fixture git init failed: $($initOutput -join ' ')"
    }
    Invoke-PluginFixtureGit -RepoRoot $Path -Arguments @('config', 'user.email', 'fixture@example.invalid') | Out-Null
    Invoke-PluginFixtureGit -RepoRoot $Path -Arguments @('config', 'user.name', 'Plugin Fixture') | Out-Null
    Invoke-PluginFixtureGit -RepoRoot $Path -Arguments @('config', 'core.autocrlf', 'false') | Out-Null

    $packageJson = [ordered]@{
        name        = 'contoso-hve'
        description = 'Contoso HVE fixture repository'
        version     = $Version
        author      = 'Contoso'
    } | ConvertTo-Json -Depth 5
    Add-PluginFixtureFile -RepoRoot $Path -RelativePath 'package.json' -Content $packageJson | Out-Null

    $sharedManifest = [ordered]@{
        name     = 'contoso-hve'
        agents   = @()
        commands = @()
        skills   = @()
    } | ConvertTo-Json -Depth 5
    Add-PluginFixtureFile -RepoRoot $Path -RelativePath '.github/plugin.json' -Content $sharedManifest | Out-Null

    if (-not $SkipAgentRoot) {
        New-Item -ItemType Directory -Path (Join-Path $Path '.github/agents') -Force | Out-Null
    }
    if (-not $SkipDocumentationRoot) {
        New-Item -ItemType Directory -Path (Join-Path $Path 'docs/plugins') -Force | Out-Null
    }
    if (-not $SkipSharedResources) {
        Add-PluginFixtureFile -RepoRoot $Path -RelativePath 'docs/templates/adr-template.md' -Content "# ADR Template`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $Path -RelativePath 'scripts/lib/Modules/Shared.psm1' -Content "function Get-Shared { 'shared' }`n" | Out-Null
    }

    return $Path
}

function Add-PluginFixtureFile {
    <#
    .SYNOPSIS
    Writes a fixture file and stages it unless it is meant to stay untracked.

    .PARAMETER RepoRoot
    Fixture repository working tree.

    .PARAMETER RelativePath
    Repository-relative forward-slash path.

    .PARAMETER Content
    File content.

    .PARAMETER Untracked
    Leaves the file out of the git index.

    .OUTPUTS
    [string] Absolute path to the written file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Content = '',

        [Parameter(Mandatory = $false)]
        [switch]$Untracked
    )

    $fullPath = Join-Path -Path $RepoRoot -ChildPath $RelativePath
    $parentDirectory = Split-Path -Parent $fullPath
    if ($parentDirectory -and -not (Test-Path -LiteralPath $parentDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
    }

    Set-Content -LiteralPath $fullPath -Value $Content -Encoding utf8NoBOM -NoNewline

    if (-not $Untracked) {
        Invoke-PluginFixtureGit -RepoRoot $RepoRoot -Arguments @('add', '--force', '--', $RelativePath) | Out-Null
    }

    return $fullPath
}

function Add-PluginFixtureArtifactSet {
    <#
    .SYNOPSIS
    Writes one agent, prompt, instruction, skill, and hook artifact set.

    .DESCRIPTION
    Every artifact carries a distinct description so generated manifests,
    READMEs, and package documents can be checked against literal expectations.

    .PARAMETER RepoRoot
    Fixture repository working tree.

    .OUTPUTS
    [hashtable] Package paths keyed by artifact kind.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/agents/rpi/rpi-planner.agent.md' `
        -Content "---`ndescription: Plans RPI work`n---`n`n# RPI Planner`n" | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/prompts/rpi/rpi-plan.prompt.md' `
        -Content "---`ndescription: Creates an RPI plan`n---`n`n# RPI Plan`n" | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/instructions/shared/hve-core-location.instructions.md' `
        -Content "---`ndescription: Locates hve-core artifacts`n---`n`n# Location`n" | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/skills/rpi/rpi-plan/SKILL.md' `
        -Content "---`nname: rpi-plan`ndescription: Builds evidence-based plans`n---`n`n# RPI Plan Skill`n" | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/skills/rpi/rpi-plan/references/checklist.md' `
        -Content "# Checklist`n" | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/hooks/rpi/telemetry.json' `
        -Content ('{"description":"Records RPI telemetry","hooks":{"SessionStart":[{"command":"${CLAUDE_PLUGIN_ROOT:-.github}/hooks/rpi/telemetry/collect.sh"}]}}') | Out-Null
    Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath '.github/hooks/rpi/telemetry/collect.sh' `
        -Content "#!/usr/bin/env bash`necho collect`n" | Out-Null

    return @{
        Agent       = 'agents/rpi/rpi-planner.agent.md'
        Command     = 'prompts/rpi/rpi-plan.prompt.md'
        Rule        = 'instructions/shared/hve-core-location.instructions.md'
        Skill       = 'skills/rpi/rpi-plan'
        Hook        = 'hooks/rpi/telemetry.json'
    }
}

function New-PluginFixtureEntry {
    <#
    .SYNOPSIS
    Builds one marketplace catalog entry.

    .PARAMETER Name
    Package name.

    .PARAMETER Description
    Package description.

    .PARAMETER Version
    Package version.

    .PARAMETER SourcePath
    Repository-relative root containing canonical package components.

    .PARAMETER SourceRef
    Optional exact release tag. Omitted by default for a tip-oriented catalog.

    .PARAMETER Agents
    Package-relative agent paths.

    .PARAMETER Commands
    Package-relative command paths.

    .PARAMETER Rules
    Package-relative rule paths.

    .PARAMETER Skills
    Package-relative skill paths.

    .PARAMETER Hook
    Package-relative hook manifest path.

    .PARAMETER Overlay
    x-hve overlay members.

    .PARAMETER Provenance
    Additional standard entry members such as author or license.

    .OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] Catalog entry.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description = 'Fixture package',

        [Parameter(Mandatory = $false)]
        [string]$Version = '9.9.9',

        [Parameter(Mandatory = $false)]
        [string]$SourcePath = '.github',

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SourceRef = '',

        [Parameter(Mandatory = $false)]
        [string[]]$Agents,

        [Parameter(Mandatory = $false)]
        [string[]]$Commands,

        [Parameter(Mandatory = $false)]
        [string[]]$Rules,

        [Parameter(Mandatory = $false)]
        [string[]]$Skills,

        [Parameter(Mandatory = $false)]
        [string]$Hook,

        [Parameter(Mandatory = $false)]
        [hashtable]$Overlay,

        [Parameter(Mandatory = $false)]
        [hashtable]$Provenance
    )

    $entry = [ordered]@{
        name        = $Name
        source      = [ordered]@{
            source = 'github'
            repo   = 'contoso/contoso-hve'
            path   = $SourcePath
        }
        description = $Description
        version     = $Version
    }

    if (-not [string]::IsNullOrWhiteSpace($SourceRef)) {
        $entry['source']['ref'] = $SourceRef
    }

    if ($Provenance) {
        foreach ($key in @($Provenance.Keys | Sort-Object)) {
            $entry[$key] = $Provenance[$key]
        }
    }
    if ($Agents) { $entry['agents'] = @($Agents) }
    if ($Commands) { $entry['commands'] = @($Commands) }
    if ($Rules) { $entry['rules'] = @($Rules) }
    if ($Skills) { $entry['skills'] = @($Skills) }
    if ($Hook) { $entry['hooks'] = $Hook }

    $overlayValues = [ordered]@{ displayName = "Contoso - $Name"; documentation = "docs/plugins/$Name.md" }
    if ($Overlay) {
        foreach ($key in @($Overlay.Keys)) {
            $overlayValues[$key] = $Overlay[$key]
        }
    }
    $entry['x-hve'] = $overlayValues

    return $entry
}

function Add-PluginFixtureCatalog {
    <#
    .SYNOPSIS
    Writes a marketplace catalog into a fixture repository.

    .PARAMETER RepoRoot
    Fixture repository working tree.

    .PARAMETER Entries
    Catalog entries.

    .PARAMETER Version
    Catalog metadata version.

    .PARAMETER RelativePath
    Catalog destination relative to the repository root.

    .PARAMETER SkipDocuments
    Skips writing the docs/plugins package document for each entry.

    .OUTPUTS
    [string] Absolute path to the written catalog.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Entries,

        [Parameter(Mandatory = $false)]
        [string]$Version = '9.9.9',

        [Parameter(Mandatory = $false)]
        [string]$RelativePath = '.github/plugin/marketplace.json',

        [Parameter(Mandatory = $false)]
        [switch]$SkipDocuments
    )

    $catalog = [ordered]@{
        name     = 'contoso-hve'
        metadata = [ordered]@{
            description = 'Contoso HVE fixture repository'
            version     = $Version
        }
        owner    = [ordered]@{ name = 'Contoso' }
        plugins  = @($Entries)
    }

    if (-not $SkipDocuments) {
        foreach ($entry in $Entries) {
            $documentation = $entry['x-hve']['documentation']
            if ([string]::IsNullOrWhiteSpace([string]$documentation)) {
                continue
            }
            $document = @(
                '---',
                "title: Contoso $($entry['name'])",
                "description: $($entry['description'])",
                '---',
                '',
                "Durable prose for $($entry['name'])."
            ) -join "`n"
            Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath ([string]$documentation) -Content "$document`n" | Out-Null
        }
    }

    return (Add-PluginFixtureFile -RepoRoot $RepoRoot -RelativePath $RelativePath -Content (($catalog | ConvertTo-Json -Depth 12) + "`n"))
}

function Get-PluginFixtureInventory {
    <#
    .SYNOPSIS
    Lists every file beneath a directory as sorted relative forward-slash paths.

    .PARAMETER Path
    Directory to enumerate.

    .OUTPUTS
    [string[]] Sorted relative paths, empty when the directory is absent.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [string[]]@()
    }

    $rootLength = (Get-Item -LiteralPath $Path).FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Length + 1
    return [string[]]@(
        Get-ChildItem -LiteralPath $Path -File -Recurse -Force |
            ForEach-Object { $_.FullName.Substring($rootLength).Replace([System.IO.Path]::DirectorySeparatorChar, '/') } |
            Sort-Object
    )
}

function Get-PluginFixtureReparsePoint {
    <#
    .SYNOPSIS
    Lists reparse points beneath a directory.

    .PARAMETER Path
    Directory to enumerate.

    .OUTPUTS
    [string[]] Absolute paths of symbolic links and other reparse points.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [string[]]@()
    }

    return [string[]]@(
        Get-ChildItem -LiteralPath $Path -Recurse -Force |
            Where-Object { $_.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) } |
            ForEach-Object { $_.FullName }
    )
}

function Get-PluginFixtureTreeDigest {
    <#
    .SYNOPSIS
    Computes an independent digest over a directory tree.

    .DESCRIPTION
    Hashes an ordinal-sorted 'relative-path sha256' manifest, terminated by a
    newline. The algorithm is restated here so evidence digests are compared
    against a value the tests derive rather than one the production helper
    returns.

    .PARAMETER Path
    Directory to digest.

    .OUTPUTS
    [string] Lowercase hexadecimal SHA-256 digest.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in (Get-PluginFixtureInventory -Path $Path)) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path -Path $Path -ChildPath $relative))
        $contentHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $entries.Add("$relative $contentHash")
    }
    $entries.Sort([System.StringComparer]::Ordinal)

    $manifest = if ($entries.Count -eq 0) { '' } else { ($entries -join "`n") + "`n" }
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($manifest))
    ).ToLowerInvariant()
}

Export-ModuleMember -Function @(
    'Add-PluginFixtureArtifactSet',
    'Add-PluginFixtureCatalog',
    'Add-PluginFixtureFile',
    'Get-PluginFixtureInventory',
    'Get-PluginFixtureReparsePoint',
    'Get-PluginFixtureTreeDigest',
    'Invoke-PluginFixtureGit',
    'New-PluginFixtureEntry',
    'New-PluginFixtureRepository'
)
