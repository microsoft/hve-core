#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates VS Code install badge catalog for hve-core artifacts.

.DESCRIPTION
    Scans .github/ for agents, prompts, instructions, and skills, reads
    frontmatter, and generates docs/catalog.md with one-click VS Code
    install badges using the vscode:chat-*/install deep-link protocol.

    Deprecated artifacts are excluded from the catalog. Instructions include
    their applyTo glob pattern when present.

.PARAMETER DryRun
    Shows what would be generated without writing files.

.EXAMPLE
    ./Generate-Badges.ps1

.EXAMPLE
    ./Generate-Badges.ps1 -DryRun

.NOTES
    Dependencies: PowerShell-Yaml module, scripts/plugins/Modules/PluginHelpers.psm1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Configuration

$RepoOwner = 'microsoft'
$RepoName = 'hve-core'
$Branch = 'main'
$RawBase = "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch"

#endregion Configuration

#region Helpers

function Get-FrontmatterApplyTo {
    <#
    .SYNOPSIS
        Extracts the applyTo field from a markdown file's YAML frontmatter.

    .DESCRIPTION
        Parses YAML frontmatter and returns the applyTo value. Returns an
        empty string when the field is absent or the file lacks frontmatter.

    .PARAMETER FilePath
        Path to the markdown file to parse.

    .OUTPUTS
        [string] The applyTo value, or empty string if absent.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -Path $FilePath -Raw
    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
            if ($data.ContainsKey('applyTo')) {
                return [string]$data.applyTo
            }
        }
        catch {
            Write-Warning "Failed to parse YAML frontmatter in $(Split-Path -Leaf $FilePath): $_"
        }
    }
    return ''
}

function New-BadgeMarkdown {
    <#
    .SYNOPSIS
        Generates a VS Code install badge markdown snippet.

    .DESCRIPTION
        Builds a shields.io badge linked to a vscode:chat-*/install deep-link
        URL for the specified artifact kind and raw file URL.

    .PARAMETER Kind
        The artifact kind: agent, prompt, or instruction.

    .PARAMETER RawFileUrl
        The raw GitHub URL for the artifact file.

    .OUTPUTS
        [string] Markdown badge image link.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction')]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$RawFileUrl
    )

    $kindMap = @{
        agent       = 'chat-agent'
        prompt      = 'chat-prompt'
        instruction = 'chat-instructions'
    }

    $installUrl = "vscode:$($kindMap[$Kind])/install?url=$RawFileUrl"
    $badgeUrl = 'https://img.shields.io/badge/VS_Code-Install-0098FF?style=flat-square&logo=visualstudiocode&logoColor=white'

    return "[![Install]($badgeUrl)]($installUrl)"
}

#endregion Helpers

#region Orchestration

function Invoke-BadgeGeneration {
    <#
    .SYNOPSIS
        Orchestrates artifact catalog generation with VS Code install badges.

    .DESCRIPTION
        Scans .github/ for agents, prompts, instructions, and skills. Reads
        frontmatter to extract descriptions and maturity. Filters out
        deprecated artifacts. Generates docs/catalog.md with sorted tables
        and one-click install badges.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER DryRun
        When specified, logs actions without writing files.

    .OUTPUTS
        Hashtable with Success, AgentCount, PromptCount, InstructionCount,
        SkillCount, and ErrorMessage keys.
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

    $githubDir = Join-Path -Path $RepoRoot -ChildPath '.github'

    # --- Scan agents ---
    $agentDir = Join-Path -Path $githubDir -ChildPath 'agents'
    $agentFiles = @(Get-ChildItem -Path $agentDir -Filter '*.agent.md' -File)
    $agents = @()

    foreach ($file in $agentFiles) {
        $frontmatter = Get-ArtifactFrontmatter -FilePath $file.FullName -FallbackDescription ($file.BaseName -replace '\.agent$', '')
        if ($frontmatter.maturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated agent: $($file.Name)"
            continue
        }
        $name = $file.Name -replace '\.agent\.md$', ''
        $rawUrl = "$RawBase/.github/agents/$($file.Name)"
        $agents += @{
            Name        = $name
            Description = $frontmatter.description
            Badge       = New-BadgeMarkdown -Kind 'agent' -RawFileUrl $rawUrl
        }
    }
    $agents = @($agents | Sort-Object { $_.Name })

    # --- Scan prompts ---
    $promptDir = Join-Path -Path $githubDir -ChildPath 'prompts'
    $promptFiles = @(Get-ChildItem -Path $promptDir -Filter '*.prompt.md' -File)
    $prompts = @()

    foreach ($file in $promptFiles) {
        $frontmatter = Get-ArtifactFrontmatter -FilePath $file.FullName -FallbackDescription ($file.BaseName -replace '\.prompt$', '')
        if ($frontmatter.maturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated prompt: $($file.Name)"
            continue
        }
        $name = $file.Name -replace '\.prompt\.md$', ''
        $rawUrl = "$RawBase/.github/prompts/$($file.Name)"
        $prompts += @{
            Name        = $name
            Description = $frontmatter.description
            Badge       = New-BadgeMarkdown -Kind 'prompt' -RawFileUrl $rawUrl
        }
    }
    $prompts = @($prompts | Sort-Object { $_.Name })

    # --- Scan instructions (recursive) ---
    $instructionDir = Join-Path -Path $githubDir -ChildPath 'instructions'
    $instructionFiles = @(Get-ChildItem -Path $instructionDir -Filter '*.instructions.md' -File -Recurse)
    $instructions = @()

    foreach ($file in $instructionFiles) {
        $frontmatter = Get-ArtifactFrontmatter -FilePath $file.FullName -FallbackDescription ($file.BaseName -replace '\.instructions$', '')
        if ($frontmatter.maturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated instruction: $($file.Name)"
            continue
        }
        # Build relative path from .github/instructions/ for the install URL
        $relativePath = [System.IO.Path]::GetRelativePath($instructionDir, $file.FullName) -replace '\\', '/'
        $name = $file.Name -replace '\.instructions\.md$', ''
        $rawUrl = "$RawBase/.github/instructions/$relativePath"
        $applyTo = Get-FrontmatterApplyTo -FilePath $file.FullName
        $instructions += @{
            Name        = $name
            Description = $frontmatter.description
            ApplyTo     = $applyTo
            Badge       = New-BadgeMarkdown -Kind 'instruction' -RawFileUrl $rawUrl
        }
    }
    $instructions = @($instructions | Sort-Object { $_.Name })

    # --- Scan skills ---
    $skillsDir = Join-Path -Path $githubDir -ChildPath 'skills'
    $skillDirs = @(Get-ChildItem -Path $skillsDir -Directory -ErrorAction SilentlyContinue)
    $skills = @()

    foreach ($dir in $skillDirs) {
        $skillFile = Join-Path -Path $dir.FullName -ChildPath 'SKILL.md'
        if (-not (Test-Path -Path $skillFile)) {
            Write-Verbose "No SKILL.md in $($dir.Name), skipping"
            continue
        }
        $frontmatter = Get-ArtifactFrontmatter -FilePath $skillFile -FallbackDescription $dir.Name
        if ($frontmatter.maturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated skill: $($dir.Name)"
            continue
        }
        $skills += @{
            Name        = $dir.Name
            Description = $frontmatter.description
        }
    }
    $skills = @($skills | Sort-Object { $_.Name })

    # --- Build catalog markdown ---
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- This file is auto-generated by scripts/plugins/Generate-Badges.ps1. Do not edit manually. -->')
    [void]$sb.AppendLine('<!-- markdownlint-disable-file -->')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('title: Artifact Catalog')
    [void]$sb.AppendLine('description: Browsable catalog of HVE Core agents, prompts, and instructions with one-click VS Code install')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('# Artifact Catalog')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('Browsable catalog of HVE Core agents, prompts, and instructions with one-click VS Code install badges.')

    # Agents table
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Agents')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Agent | Description | Install |')
    [void]$sb.AppendLine('| ----- | ----------- | ------- |')
    foreach ($agent in $agents) {
        [void]$sb.AppendLine("| $($agent.Name) | $($agent.Description) | $($agent.Badge) |")
    }

    # Prompts table
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Prompts')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Prompt | Description | Install |')
    [void]$sb.AppendLine('| ------ | ----------- | ------- |')
    foreach ($prompt in $prompts) {
        [void]$sb.AppendLine("| $($prompt.Name) | $($prompt.Description) | $($prompt.Badge) |")
    }

    # Instructions table
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Instructions')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Instruction | Description | Applies To | Install |')
    [void]$sb.AppendLine('| ----------- | ----------- | ---------- | ------- |')
    foreach ($instr in $instructions) {
        $applyToCell = if ($instr.ApplyTo) { "``$($instr.ApplyTo)``" } else { '' }
        [void]$sb.AppendLine("| $($instr.Name) | $($instr.Description) | $applyToCell | $($instr.Badge) |")
    }

    # Skills table
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Skills')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| Skill | Description |')
    [void]$sb.AppendLine('| ----- | ----------- |')
    foreach ($skill in $skills) {
        [void]$sb.AppendLine("| $($skill.Name) | $($skill.Description) |")
    }
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> Skills do not support one-click install. Use the [extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) or clone the repository to access skills.')

    # Footer
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('<!-- markdownlint-disable MD036 -->')
    [void]$sb.AppendLine('*Auto-generated by [scripts/plugins/Generate-Badges.ps1](../scripts/plugins/Generate-Badges.ps1). Do not edit manually.*')
    [void]$sb.AppendLine('<!-- markdownlint-enable MD036 -->')

    # --- Write output ---
    $catalogPath = Join-Path -Path $RepoRoot -ChildPath 'docs' -AdditionalChildPath 'catalog.md'

    if ($DryRun) {
        Write-Host '[DRY RUN] Would write catalog to:' -ForegroundColor Yellow
        Write-Host "  $catalogPath" -ForegroundColor Yellow
        Write-Host "`nPreview:" -ForegroundColor Cyan
        Write-Host $sb.ToString()
    }
    else {
        Set-Content -Path $catalogPath -Value $sb.ToString() -Encoding utf8 -NoNewline
        Write-Host "Wrote catalog to $catalogPath" -ForegroundColor Green
    }

    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "  Agents:       $($agents.Count)"
    Write-Host "  Prompts:      $($prompts.Count)"
    Write-Host "  Instructions: $($instructions.Count)"
    Write-Host "  Skills:       $($skills.Count)"

    return @{
        Success          = $true
        AgentCount       = $agents.Count
        PromptCount      = $prompts.Count
        InstructionCount = $instructions.Count
        SkillCount       = $skills.Count
        ErrorMessage     = ''
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName

        Write-Host 'HVE Core Badge Generator' -ForegroundColor Cyan
        Write-Host '=============================' -ForegroundColor Cyan

        $result = Invoke-BadgeGeneration -RepoRoot $RepoRoot -DryRun:$DryRun

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        $total = $result.AgentCount + $result.PromptCount + $result.InstructionCount + $result.SkillCount
        Write-Host ''
        Write-Host "🎉 Done! $total artifact(s) cataloged." -ForegroundColor Green

        exit 0
    }
    catch {
        Write-Error "Badge generation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
