#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Prepares the HVE Core VS Code extension from the plugin manifest.
.DESCRIPTION
    Reads root plugin.json as the sole component authority and writes the
    single hve-core extension manifest and README. Component membership is
    identical on every release channel.
.PARAMETER DryRun
    Reports the resolved contributions without writing extension output.
.EXAMPLE
    ./Prepare-Extension.ps1
.NOTES
    Runs through extension preparation package scripts.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/ArtifactHelpers.psm1') -Force

#region Manifest generation

function Get-PluginManifest {
    <#
    .SYNOPSIS
    Reads the plugin manifest that declares extension membership.
    .PARAMETER Path
    Plugin manifest path.
    .OUTPUTS
    [pscustomobject] Parsed plugin manifest.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Plugin manifest not found: $Path" }
    return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json)
}

function Test-PluginComponentPath {
    <#
    .SYNOPSIS
    Tests whether a plugin component path is contained and well shaped.
    .PARAMETER Path
    Manifest-declared path relative to the repository root.
    .PARAMETER Shape
    Anchored expression describing the expected artifact shape.
    .OUTPUTS
    [bool] True when the path is contained and matches the expected shape.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Shape
    )

    if ($Path -match '[\\:]' -or $Path -match '[\x00-\x1f]' -or $Path.IndexOfAny([char[]]'*?[]') -ge 0) { return $false }
    foreach ($segment in ($Path -split '/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') { return $false }
    }
    return [bool]($Path -match $Shape)
}

function Get-PluginComponent {
    <#
    .SYNOPSIS
    Projects plugin manifest membership into repository-relative components.
    .DESCRIPTION
    Manifest field names and their declared path roots differ, so the artifact
    kind comes from the field and the path is carried through unchanged. Hooks
    are omitted because VS Code has no hook contribution point.
    .PARAMETER Manifest
    Parsed plugin manifest.
    .OUTPUTS
    [hashtable[]] Component descriptors with Kind and SourcePath.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Manifest
    )

    $fieldKinds = [ordered]@{
        agents   = @{ Kind = 'agent'; Shape = '^\.github/agents/[^/]+/.+\.agent\.md$' }
        commands = @{ Kind = 'prompt'; Shape = '^\.github/prompts/[^/]+/.+\.prompt\.md$' }
        rules    = @{ Kind = 'instruction'; Shape = '^\.github/instructions/[^/]+/.+\.instructions\.md$' }
        skills   = @{ Kind = 'skill'; Shape = '^\.github/skills/[^/]+/[^/]+$' }
    }
    $items = @()
    foreach ($field in $fieldKinds.Keys) {
        foreach ($path in @($Manifest.$field)) {
            $declared = [string]$path
            if ([string]::IsNullOrWhiteSpace($declared)) { continue }
            if (-not (Test-PluginComponentPath -Path $declared -Shape $fieldKinds[$field].Shape)) {
                throw "Plugin manifest $field entry '$declared' is not a contained artifact path."
            }
            $items += @{ Kind = $fieldKinds[$field].Kind; SourcePath = $declared }
        }
    }
    return [hashtable[]]$items
}

function Set-JsonFile {
    <#
    .SYNOPSIS
    Writes an object as UTF-8 JSON.
    .PARAMETER Path
    Destination path.
    .PARAMETER Content
    Object to serialize.
    .OUTPUTS
    [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
    $Content | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Get-PluginDocumentBody {
    <#
    .SYNOPSIS
    Reads the hand-authored introduction from a durable package document.
    .PARAMETER Path
    Package document path.
    .OUTPUTS
    [string] Hand-authored introduction.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    $content = $content -replace '(?s)^---\s*\r?\n.*?\r?\n---\s*\r?\n', ''
    $includedIndex = $content.IndexOf('## Included Artifacts', [System.StringComparison]::Ordinal)
    if ($includedIndex -ge 0) {
        $content = $content.Substring(0, $includedIndex)
    }
    return $content.Trim()
}

function New-ExtensionArtifactSection {
    <#
    .SYNOPSIS
    Renders artifact tables from resolved plugin components.
    .PARAMETER Items
    Resolved plugin components.
    .PARAMETER RepoRoot
    Repository root.
    .OUTPUTS
    [string] Markdown artifact tables.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $groups = [ordered]@{
        agent       = @{ Title = 'Chat Agents'; Items = @() }
        prompt      = @{ Title = 'Prompts'; Items = @() }
        instruction = @{ Title = 'Instructions'; Items = @() }
        skill       = @{ Title = 'Skills'; Items = @() }
    }
    foreach ($item in $Items) {
        if (-not $groups.Contains($item.Kind)) { continue }
        $source = Join-Path -Path $RepoRoot -ChildPath $item.SourcePath
        $descriptionPath = if ($item.Kind -eq 'skill') { Join-Path $source 'SKILL.md' } else { $source }
        $groups[$item.Kind].Items += @{
            Name        = Get-ArtifactKey -Kind $item.Kind -Path $item.SourcePath
            Description = Get-ArtifactDescription -FilePath $descriptionPath
        }
    }

    $output = [System.Text.StringBuilder]::new()
    foreach ($group in $groups.Values) {
        if ($group.Items.Count -eq 0) { continue }
        [void]$output.AppendLine("### $($group.Title)")
        [void]$output.AppendLine()
        [void]$output.AppendLine('| Name | Description |')
        [void]$output.AppendLine('|------|-------------|')
        foreach ($item in $group.Items | Sort-Object Name) {
            [void]$output.AppendLine("| **$($item.Name)** | $($item.Description) |")
        }
        [void]$output.AppendLine()
    }
    return $output.ToString().TrimEnd()
}

function New-ExtensionReadme {
    <#
    .SYNOPSIS
    Generates the extension README from the plugin manifest and durable docs.
    .PARAMETER DisplayName
    Extension display name.
    .PARAMETER Description
    Plugin manifest description.
    .PARAMETER Items
    Resolved plugin components.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER TemplatePath
    README template path.
    .PARAMETER OutputPath
    README output path.
    .OUTPUTS
    [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$TemplatePath,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $body = Get-PluginDocumentBody -Path (Join-Path $RepoRoot 'docs/plugins/hve-core.md')
    $content = (Get-Content -LiteralPath $TemplatePath -Raw -Encoding utf8) `
        -replace '\{\{DISPLAY_NAME\}\}', $DisplayName `
        -replace '\{\{DESCRIPTION\}\}', $Description `
        -replace '\{\{BODY\}\}', $body `
        -replace '\{\{ARTIFACTS\}\}', (New-ExtensionArtifactSection -Items $Items -RepoRoot $RepoRoot)
    $content = ($content -replace '(\r?\n){3,}', "`n`n").TrimEnd() + "`n"
    Set-ContentIfChanged -Path $OutputPath -Value $content | Out-Null
}

#endregion Manifest generation

#region Contributions

function Get-ExtensionContributions {
    <#
    .SYNOPSIS
    Maps resolved plugin components to VS Code contribution objects.
    .PARAMETER Items
    Resolved plugin components.
    .OUTPUTS
    [hashtable] Contribution arrays by kind.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items
    )

    $result = @{ Agents = @(); Prompts = @(); Instructions = @(); Skills = @() }
    foreach ($item in $Items) {
        $path = "./$($item.SourcePath)"
        switch ($item.Kind) {
            'agent' {
                $result.Agents += [pscustomobject]@{ name = ((Split-Path -Leaf $item.SourcePath) -replace '\.agent\.md$', ''); path = $path }
            }
            'prompt' {
                $result.Prompts += [pscustomobject]@{ name = ((Split-Path -Leaf $item.SourcePath) -replace '\.prompt\.md$', ''); path = $path }
            }
            'instruction' {
                $name = ((Split-Path -Leaf $item.SourcePath) -replace '\.instructions\.md$', '')
                $result.Instructions += [pscustomobject]@{ name = "$name-instructions"; path = $path }
            }
            'skill' {
                $result.Skills += [pscustomobject]@{ name = (Split-Path -Leaf $item.SourcePath); path = "$path/SKILL.md" }
            }
        }
    }
    foreach ($key in @($result.Keys)) { $result[$key] = @($result[$key] | Sort-Object name) }
    return $result
}

function Update-PackageJsonContributes {
    <#
    .SYNOPSIS
    Updates extension contribution properties.
    .PARAMETER PackageJson
    Package object.
    .PARAMETER ChatAgents
    Agent contributions.
    .PARAMETER ChatPromptFiles
    Prompt contributions.
    .PARAMETER ChatInstructions
    Instruction contributions.
    .PARAMETER ChatSkills
    Skill contributions.
    .OUTPUTS
    [pscustomobject] Updated package object.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)] [pscustomobject]$PackageJson,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$ChatAgents,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$ChatPromptFiles,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$ChatInstructions,
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [array]$ChatSkills
    )

    $updated = $PackageJson | ConvertTo-Json -Depth 20 | ConvertFrom-Json
    if (-not $updated.contributes) { $updated | Add-Member -NotePropertyName contributes -NotePropertyValue ([pscustomobject]@{}) }
    # Ordered so regenerating a manifest is byte-stable across runs and hosts.
    $properties = [ordered]@{
        chatAgents       = $ChatAgents
        chatPromptFiles  = $ChatPromptFiles
        chatInstructions = $ChatInstructions
        chatSkills       = $ChatSkills
    }
    foreach ($property in $properties.GetEnumerator()) {
        $updated.contributes | Add-Member -NotePropertyName $property.Key -NotePropertyValue $property.Value -Force
    }
    return $updated
}

function New-PrepareResult {
    <#
    .SYNOPSIS
    Creates a preparation result.
    .PARAMETER Success
    Success state.
    .PARAMETER Version
    Package version.
    .PARAMETER AgentCount
    Agent count.
    .PARAMETER PromptCount
    Prompt count.
    .PARAMETER InstructionCount
    Instruction count.
    .PARAMETER SkillCount
    Skill count.
    .PARAMETER ErrorMessage
    Error message.
    .OUTPUTS
    [hashtable] Preparation result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [bool]$Success,
        [Parameter(Mandatory = $false)] [string]$Version = '',
        [Parameter(Mandatory = $false)] [int]$AgentCount = 0,
        [Parameter(Mandatory = $false)] [int]$PromptCount = 0,
        [Parameter(Mandatory = $false)] [int]$InstructionCount = 0,
        [Parameter(Mandatory = $false)] [int]$SkillCount = 0,
        [Parameter(Mandatory = $false)] [string]$ErrorMessage = ''
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

function Invoke-PrepareExtension {
    <#
    .SYNOPSIS
    Prepares the hve-core extension from the plugin manifest.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER DryRun
    Prevents extension output writes.
    .OUTPUTS
    [hashtable] Preparation result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$ExtensionDirectory,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$RepoRoot,
        [Parameter(Mandatory = $false)] [switch]$DryRun
    )

    try {
        $manifest = Get-PluginManifest -Path (Join-Path $RepoRoot 'plugin.json')
        $items = @(Get-PluginComponent -Manifest $manifest)
        if ($items.Count -eq 0) {
            return New-PrepareResult -Success $false -ErrorMessage 'Plugin manifest declares no extension components.'
        }

        $templatePath = Join-Path $RepoRoot 'extension/templates/package.template.json'
        $readmeTemplatePath = Join-Path $RepoRoot 'extension/templates/README.template.md'
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
            return New-PrepareResult -Success $false -ErrorMessage "Package template not found: $templatePath"
        }
        if (-not (Test-Path -LiteralPath $readmeTemplatePath -PathType Leaf)) {
            return New-PrepareResult -Success $false -ErrorMessage "README template not found: $readmeTemplatePath"
        }

        $packageJson = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8 | ConvertFrom-Json
        if ([string]$packageJson.version -notmatch '^\d+\.\d+\.\d+$') {
            return New-PrepareResult -Success $false -ErrorMessage "Invalid version format in package template: $($packageJson.version)"
        }
        $packageJson.description = [string]$manifest.description

        $contributions = Get-ExtensionContributions -Items $items
        $packageJson = Update-PackageJsonContributes -PackageJson $packageJson `
            -ChatAgents $contributions.Agents -ChatPromptFiles $contributions.Prompts `
            -ChatInstructions $contributions.Instructions -ChatSkills $contributions.Skills

        if (-not $DryRun) {
            Set-JsonFile -Path (Join-Path $ExtensionDirectory 'package.json') -Content $packageJson
            New-ExtensionReadme -DisplayName ([string]$packageJson.displayName) -Description ([string]$manifest.description) `
                -Items $items -RepoRoot $RepoRoot -TemplatePath $readmeTemplatePath `
                -OutputPath (Join-Path $ExtensionDirectory 'README.md')
        }

        return New-PrepareResult -Success $true -Version ([string]$packageJson.version) `
            -AgentCount $contributions.Agents.Count -PromptCount $contributions.Prompts.Count `
            -InstructionCount $contributions.Instructions.Count -SkillCount $contributions.Skills.Count
    }
    catch {
        return New-PrepareResult -Success $false -ErrorMessage $_.Exception.Message
    }
}

#endregion Contributions

#region Main execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $repoRoot = (Get-Item (Join-Path $PSScriptRoot '../..')).FullName
        $extensionDirectory = Join-Path $repoRoot 'extension'

        $result = Invoke-PrepareExtension -ExtensionDirectory $extensionDirectory -RepoRoot $repoRoot -DryRun:$DryRun
        if (-not $result.Success) { throw $result.ErrorMessage }

        Write-Host 'HVE Core extension prepared' -ForegroundColor Green
        Write-Host "  Agents: $($result.AgentCount)"
        Write-Host "  Prompts: $($result.PromptCount)"
        Write-Host "  Instructions: $($result.InstructionCount)"
        Write-Host "  Skills: $($result.SkillCount)"
        exit 0
    }
    catch {
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        Write-Error -ErrorAction Continue "Prepare-Extension failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main execution
