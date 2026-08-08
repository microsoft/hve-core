#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Prepares one marketplace package as a VS Code extension.
.DESCRIPTION
    Generates extension metadata from marketplace.json, resolves the selected
    package through the shared handoff-closed projection, and writes VS Code
    contributions without scanning legacy package manifests.
.PARAMETER ChangelogPath
    Optional changelog copied into the extension package.
.PARAMETER Channel
    Stable or PreRelease package channel.
.PARAMETER DryRun
    Reports the selected projection without writing selected package output.
.PARAMETER PackageId
    Marketplace package ID. Defaults to hve-core.
.EXAMPLE
    ./Prepare-Extension.ps1 -PackageId hve-core -Channel Stable
.NOTES
    Runs through extension preparation package scripts.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ChangelogPath = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'Stable',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageId = 'hve-core'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/MarketplaceHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/ArtifactHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/ExtensionIdentity.psm1') -Force

#region Package generation

function Copy-TemplateWithOverrides {
    <#
    .SYNOPSIS
    Copies a template and applies property overrides.
    .PARAMETER Template
    Source template.
    .PARAMETER Overrides
    Property overrides.
    .OUTPUTS
    [pscustomobject] Copied template.
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

function Get-ExtensionPackageFileName {
    <#
    .SYNOPSIS
    Returns the generated extension package filename.
    .PARAMETER PackageName
    Marketplace package name.
    .OUTPUTS
    [string] Package filename.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    if ($PackageName -eq 'hve-core') { return 'package.json' }
    return "package.$PackageName.json"
}

function Get-ExtensionReadmeFileName {
    <#
    .SYNOPSIS
    Returns the generated extension README filename.
    .PARAMETER PackageName
    Marketplace package name.
    .OUTPUTS
    [string] README filename.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    if ($PackageName -eq 'hve-core') { return 'README.md' }
    return "README.$PackageName.md"
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
    $headingMatch = [regex]::Match($content, (Get-PackageDocArtifactHeadingPattern))
    if ($headingMatch.Success) {
        $content = $content.Substring(0, $headingMatch.Index)
    }
    return $content.Trim()
}

function New-ExtensionArtifactSection {
    <#
    .SYNOPSIS
    Renders artifact tables from a resolved package recipe.
    .PARAMETER Items
    Resolved package recipe.
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
        $maturity = if ([string]::IsNullOrWhiteSpace([string]$item.Maturity)) { 'stable' } else { [string]$item.Maturity }
        $groups[$item.Kind].Items += @{
            Name        = Get-ArtifactKey -Kind $item.Kind -Path $item.SourcePath
            Maturity    = $maturity
            Description = Get-ArtifactDescription -FilePath $descriptionPath
        }
    }

    $output = [System.Text.StringBuilder]::new()
    foreach ($group in $groups.Values) {
        if ($group.Items.Count -eq 0) { continue }
        [void]$output.AppendLine("### $($group.Title)")
        [void]$output.AppendLine()
        [void]$output.AppendLine('| Name | Maturity | Description |')
        [void]$output.AppendLine('|------|----------|-------------|')
        foreach ($item in $group.Items | Sort-Object Name) {
            [void]$output.AppendLine("| **$($item.Name)** | $($item.Maturity) | $($item.Description) |")
        }
        [void]$output.AppendLine()
    }
    return $output.ToString().TrimEnd()
}

function New-ExtensionReadme {
    <#
    .SYNOPSIS
    Generates one extension README from marketplace metadata and durable docs.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER Items
    Resolved package recipe.
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
        [System.Collections.IDictionary]$Entry,

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

    $displayName = [string](Get-MarketplaceEntryOverlayValue -Entry $Entry -Key 'displayName')
    $documentation = [string](Get-MarketplaceEntryOverlayValue -Entry $Entry -Key 'documentation')
    $body = if ($documentation) { Get-PluginDocumentBody -Path (Join-Path $RepoRoot $documentation) } else { '' }
    $maturity = Get-MarketplaceEntryMaturity -Entry $Entry
    $maturityNotice = if ($maturity -eq 'experimental') {
        '> **Experimental**: This package is experimental. Contents and behavior may change or be removed without notice.'
    }
    elseif ($maturity -eq 'preview') {
        '> **Preview**: This package is in preview. Core features are complete and functional but refinements may follow.'
    }
    else { '' }

    $content = (Get-Content -LiteralPath $TemplatePath -Raw -Encoding utf8) `
        -replace '\{\{DISPLAY_NAME\}\}', $displayName `
        -replace '\{\{DESCRIPTION\}\}', [string]$Entry['description'] `
        -replace '\{\{MATURITY_NOTICE\}\}', $maturityNotice `
        -replace '\{\{BODY\}\}', $body `
        -replace '\{\{ARTIFACTS\}\}', (New-ExtensionArtifactSection -Items $Items -RepoRoot $RepoRoot)
    $content = ($content -replace '(\r?\n){3,}', "`n`n").TrimEnd() + "`n"
    Set-ContentIfChanged -Path $OutputPath -Value $content | Out-Null
}

function Remove-StaleGeneratedFiles {
    <#
    .SYNOPSIS
    Removes stale generated extension package and README files.
    .DESCRIPTION
    The generated set includes the unsuffixed package.json and README.md that
    the surviving identity owns, so cleanup sweeps both the suffixed and the
    unsuffixed names. A retired identity therefore cannot leave either form
    behind on repeated preparation.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER ExpectedFiles
    Files that must remain.
    .OUTPUTS
    [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$ExpectedFiles
    )

    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $ExpectedFiles) { [void]$expected.Add([System.IO.Path]::GetFullPath($file)) }
    $extensionDir = Join-Path $RepoRoot 'extension'
    foreach ($file in Get-ChildItem -LiteralPath $extensionDir -File | Where-Object { $_.Name -like 'package*.json' -or $_.Name -like 'README*.md' }) {
        if (-not $expected.Contains([System.IO.Path]::GetFullPath($file.FullName))) {
            Remove-Item -LiteralPath $file.FullName -Force
        }
    }
}

function Invoke-ExtensionPackagesGeneration {
    <#
    .SYNOPSIS
    Generates extension package and README files from marketplace entries.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER Catalog
    Parsed marketplace catalog.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .OUTPUTS
    [string[]] Generated file paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Catalog,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $templatePath = Join-Path $RepoRoot 'extension/templates/package.template.json'
    $readmeTemplatePath = Join-Path $RepoRoot 'extension/templates/README.template.md'
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) { throw "Package template not found: $templatePath" }
    if (-not (Test-Path -LiteralPath $readmeTemplatePath -PathType Leaf)) { throw "README template not found: $readmeTemplatePath" }
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8 | ConvertFrom-Json
    $agentIndex = Get-MarketplaceAgentIndex -Catalog $Catalog -RepoRoot $RepoRoot
    $expected = @()

    foreach ($entry in @($Catalog['plugins']) | Sort-Object { $_['name'] }) {
        if (-not (Test-MarketplaceEntryEligible -Entry $entry -Channel $Channel)) { continue }
        $packageName = [string]$entry['name']
        $packagePath = Join-Path $RepoRoot "extension/$(Get-ExtensionPackageFileName -PackageName $packageName)"
        $readmePath = Join-Path $RepoRoot "extension/$(Get-ExtensionReadmeFileName -PackageName $packageName)"
        $package = Copy-TemplateWithOverrides -Template $template -Overrides @{
            name        = Get-ExtensionIdentity -PackageId $packageName -TemplateName ([string]$template.name)
            displayName = [string](Get-MarketplaceEntryOverlayValue -Entry $entry -Key 'displayName')
            description = [string]$entry['description']
        }
        Set-JsonFile -Path $packagePath -Content $package
        $items = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $agentIndex)
        New-ExtensionReadme -Entry $entry -Items $items -RepoRoot $RepoRoot -TemplatePath $readmeTemplatePath -OutputPath $readmePath
        $expected += $packagePath, $readmePath
    }

    Remove-StaleGeneratedFiles -RepoRoot $RepoRoot -ExpectedFiles $expected
    return [string[]]$expected
}

#endregion Package generation

#region Contributions

function Get-ExtensionContributions {
    <#
    .SYNOPSIS
    Maps a resolved package recipe to VS Code contribution objects.
    .PARAMETER Items
    Resolved package recipe.
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
    Prepares a selected marketplace package for VS Code.
    .PARAMETER ExtensionDirectory
    Extension directory.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .PARAMETER ChangelogPath
    Optional changelog.
    .PARAMETER DryRun
    Prevents selected package and changelog writes.
    .PARAMETER PackageId
    Marketplace package ID.
    .OUTPUTS
    [hashtable] Preparation result.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$ExtensionDirectory,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$RepoRoot,
        [Parameter(Mandatory = $false)] [ValidateSet('Stable', 'PreRelease')] [string]$Channel = 'Stable',
        [Parameter(Mandatory = $false)] [string]$ChangelogPath = '',
        [Parameter(Mandatory = $false)] [switch]$DryRun,
        [Parameter(Mandatory = $false)] [ValidateNotNullOrEmpty()] [string]$PackageId = 'hve-core'
    )

    try {
        $catalog = Get-MarketplaceCatalog -Path (Join-Path $RepoRoot '.github/plugin/marketplace.json')
        $packageMatches = @($catalog['plugins'] | Where-Object { $_['name'] -eq $PackageId })
        if ($packageMatches.Count -ne 1) {
            return New-PrepareResult -Success $false -ErrorMessage "Marketplace package '$PackageId' was not found exactly once."
        }
        $entry = $packageMatches[0]
        if (-not (Test-MarketplaceEntryEligible -Entry $entry -Channel $Channel)) {
            return New-PrepareResult -Success $true -Version ([string]$entry['version'])
        }

        $generated = Invoke-ExtensionPackagesGeneration -RepoRoot $RepoRoot -Catalog $catalog -Channel $Channel
        Write-Host "Generated $($generated.Count) extension package file(s)"
        $selectedPath = Join-Path $ExtensionDirectory (Get-ExtensionPackageFileName -PackageName $PackageId)
        if (-not (Test-Path -LiteralPath $selectedPath -PathType Leaf)) {
            return New-PrepareResult -Success $false -ErrorMessage "Generated package file not found: $selectedPath"
        }
        $packageJson = Get-Content -LiteralPath $selectedPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($packageJson.version -notmatch '^\d+\.\d+\.\d+$') {
            return New-PrepareResult -Success $false -ErrorMessage "Invalid version format in package.json: $($packageJson.version)"
        }

        $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $RepoRoot
        $items = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $agentIndex)
        $contributions = Get-ExtensionContributions -Items $items
        $packageJson = Update-PackageJsonContributes -PackageJson $packageJson `
            -ChatAgents $contributions.Agents -ChatPromptFiles $contributions.Prompts `
            -ChatInstructions $contributions.Instructions -ChatSkills $contributions.Skills

        if (-not $DryRun) {
            Set-JsonFile -Path (Join-Path $ExtensionDirectory 'package.json') -Content $packageJson
            if ($ChangelogPath) {
                if (-not (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)) {
                    Write-Warning "Changelog path specified but file not found: $ChangelogPath"
                }
                else {
                    Copy-Item -LiteralPath $ChangelogPath -Destination (Join-Path $ExtensionDirectory 'CHANGELOG.md') -Force
                }
            }
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
        $resolvedChangelogPath = if ([string]::IsNullOrWhiteSpace($ChangelogPath)) {
            ''
        }
        elseif ([System.IO.Path]::IsPathRooted($ChangelogPath)) {
            $ChangelogPath
        }
        else {
            Join-Path $repoRoot $ChangelogPath
        }

        $result = Invoke-PrepareExtension -ExtensionDirectory $extensionDirectory -RepoRoot $repoRoot `
            -Channel $Channel -ChangelogPath $resolvedChangelogPath -DryRun:$DryRun -PackageId $PackageId
        if (-not $result.Success) { throw $result.ErrorMessage }

        Write-Host 'HVE Core extension prepared' -ForegroundColor Green
        Write-Host "  Package: $PackageId"
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
