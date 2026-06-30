#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Generate the authoritative inventory of parent agents at evals/agent-behavior/AGENTS.yml.

.DESCRIPTION
    Scans `.github/agents/**/*.agent.md` and emits a deterministic YAML inventory of all
    parent agents enrolled in the per-agent eval-behavior matrix. The inventory becomes the
    single source of truth shared by `Build-AgentBehaviorSpec.ps1`, `Invoke-VallyEvals.ps1`,
    `Test-AgentBehaviorCoverage.ps1`, and the dashboard.

    Discovery rule:
      1. Enumerate every `.agent.md` file under `.github/agents/`.
      2. Drop any file whose YAML frontmatter sets `user-invocable: false`. This is the
         canonical parent/subagent boundary marker; the `subagents/` folder convention is
         informational only and is not consulted.
      3. Files with no `user-invocable` key are treated as parent agents.

    Frontmatter fields read per agent:
      * `eval-class:` (Phase 2.2 populates) -> class slug; defaults to `unknown` when absent.
      * `cost_tier:`  (Phase 2.2 populates) -> light|medium|heavy; defaults to `light`.

    Output shape (sorted by slug for determinism):
        generated_at: <ISO-8601 UTC>
        generator: scripts/evals/Build-AgentInventory.ps1
        agents:
          - slug: <slug>
            path: <workspace-relative path>
            class: <eval-class or unknown>
            cost_tier: <light|medium|heavy>

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.PARAMETER OutputPath
    YAML output path. Defaults to `<RepoRoot>/evals/agent-behavior/AGENTS.yml`.

.PARAMETER Force
    Overwrite an existing inventory file even when content matches.

.PARAMETER GeneratedAt
    Optional fixed ISO-8601 UTC timestamp for deterministic test fixtures.

.EXAMPLE
    pwsh scripts/evals/Build-AgentInventory.ps1
    Regenerate the inventory in-place.

.EXAMPLE
    pwsh scripts/evals/Build-AgentInventory.ps1 -WhatIf
    Report drift between the current inventory and what would be generated.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([string])]
param(
    [string]$RepoRoot,
    [string]$OutputPath,
    [switch]$Force,
    [string]$GeneratedAt
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Import-YamlModule {
    [CmdletBinding()]
    param()

    if (Get-Module -Name 'powershell-yaml') { return }
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Required module 'powershell-yaml' is not installed. Run 'Install-Module powershell-yaml -Scope CurrentUser' before invoking this script."
    }
    Import-Module powershell-yaml -ErrorAction Stop | Out-Null
}

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Override)

    if ($Override) { return (Resolve-Path -LiteralPath $Override).Path }
    try {
        $root = (& git rev-parse --show-toplevel 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $root) { return $root }
    } catch {
        Write-Verbose "git rev-parse failed: $($_.Exception.Message)"
    }
    return (Get-Location).Path
}

function ConvertTo-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($RepoRoot)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if ($pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $pathFull.Substring($rootFull.Length).TrimStart([char]'\', [char]'/')
        return ($rel -replace '\\', '/')
    }
    return ($Path -replace '\\', '/')
}

function Read-AgentFrontmatter {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] [string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)') {
        return @{}
    }

    $yamlBlock = $matches[1]
    try {
        $parsed = ConvertFrom-Yaml -Yaml $yamlBlock
    } catch {
        throw "Failed to parse YAML frontmatter in '$Path': $($_.Exception.Message)"
    }

    $result = @{}
    if ($parsed -is [System.Collections.IDictionary]) {
        foreach ($key in $parsed.Keys) {
            $result[[string]$key] = $parsed[$key]
        }
    }
    return $result
}

function Get-AgentSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$RelativePath)
    return [System.IO.Path]::GetFileName($RelativePath) -replace '\.agent\.md$', ''
}

function Test-IsParentAgent {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [hashtable]$Frontmatter)

    if (-not $Frontmatter.ContainsKey('user-invocable')) { return $true }
    $value = $Frontmatter['user-invocable']
    if ($value -is [bool]) { return $value }
    # Defensive fallback: tolerate string forms that some authors may write.
    if ($value -is [string]) { return ($value.Trim().ToLowerInvariant() -ne 'false') }
    return $true
}

function Get-ParentAgentInventory {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param([Parameter(Mandatory)] [string]$RepoRoot)

    $agentsDir = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $agentsDir -PathType Container)) {
        throw "Agents directory not found at '$agentsDir'."
    }

    $entries = [System.Collections.Generic.List[hashtable]]::new()
    $files = @(Get-ChildItem -Path $agentsDir -Recurse -Filter '*.agent.md' -File -ErrorAction Stop)

    foreach ($file in $files) {
        $rel = ConvertTo-RelativePath -RepoRoot $RepoRoot -Path $file.FullName
        $fm = Read-AgentFrontmatter -Path $file.FullName
        if (-not (Test-IsParentAgent -Frontmatter $fm)) { continue }

        $entries.Add([ordered]@{
                slug      = Get-AgentSlug -RelativePath $rel
                path      = $rel
                class     = if ($fm.ContainsKey('eval-class') -and $fm['eval-class']) { [string]$fm['eval-class'] } else { 'unknown' }
                cost_tier = if ($fm.ContainsKey('cost_tier') -and $fm['cost_tier']) { [string]$fm['cost_tier'] } else { 'light' }
            })
    }

    return [System.Collections.Generic.List[hashtable]]($entries | Sort-Object -Property { $_.slug })
}

function ConvertTo-YamlSingleQuoted {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

function Format-InventoryYaml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$GeneratedAt,
        [Parameter(Mandatory)] [System.Collections.Generic.List[hashtable]]$Agents
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Generated by scripts/evals/Build-AgentInventory.ps1 - re-run with -Force to regenerate.')
    [void]$sb.AppendLine('# Source of truth for the per-agent eval-behavior matrix.')
    [void]$sb.AppendLine("generated_at: $GeneratedAt")
    [void]$sb.AppendLine("generator: 'scripts/evals/Build-AgentInventory.ps1'")
    [void]$sb.AppendLine('agents:')
    foreach ($entry in $Agents) {
        [void]$sb.AppendLine("  - slug: $($entry.slug)")
        [void]$sb.AppendLine("    path: $(ConvertTo-YamlSingleQuoted -Value $entry.path)")
        [void]$sb.AppendLine("    class: $($entry.class)")
        [void]$sb.AppendLine("    cost_tier: $($entry.cost_tier)")
    }
    return $sb.ToString()
}

#region Main Execution
Import-YamlModule

$resolvedRoot = Resolve-RepoRoot -Override $RepoRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $resolvedRoot 'evals/agent-behavior/AGENTS.yml'
}

if (-not $GeneratedAt) {
    $GeneratedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$agents = Get-ParentAgentInventory -RepoRoot $resolvedRoot
$rendered = Format-InventoryYaml -GeneratedAt $GeneratedAt -Agents $agents

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($outputDir, 'Create directory')) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
}

$drift = $true
if (Test-Path -LiteralPath $OutputPath -PathType Leaf) {
    $existing = [System.IO.File]::ReadAllText($OutputPath)
    # Compare ignoring the generated_at line (always changes when not pinned).
    $existingNormalized = ($existing -split "`r?`n" | Where-Object { $_ -notmatch '^generated_at:' }) -join "`n"
    $renderedNormalized = ($rendered -split "`r?`n" | Where-Object { $_ -notmatch '^generated_at:' }) -join "`n"
    if ($existingNormalized -eq $renderedNormalized) { $drift = $false }
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write agent inventory YAML')) {
    if (-not $drift -and -not $Force) {
        Write-Host "skipped (no drift): $OutputPath"
        return $OutputPath
    }
    [System.IO.File]::WriteAllText($OutputPath, $rendered)
    Write-Host "wrote: $OutputPath ($($agents.Count) agents)"
} else {
    if ($drift) {
        Write-Host "drift detected: $OutputPath would change ($($agents.Count) agents)"
    } else {
        Write-Host "no drift: $OutputPath ($($agents.Count) agents)"
    }
}

return $OutputPath
#endregion Main Execution
