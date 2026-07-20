#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Generate a per-agent surface signature YAML for baseline equivalence runs.

.DESCRIPTION
    Reads the `.agent.md` file for the specified agent slug and emits
    `<OutputDir>/<Agent>.yml` containing `required:` and `disallowed:` arrays
    of `{ name, type: output-matches, config: { pattern } }` entries. The
    schema mirrors the original inline block in
    `evals/baseline-equivalence/compare.eval.yml` (under `surface_signatures.<agent>`).

    Required rules:
      - header-present: regex derived from the agent body's
        "Start responses with: `## <prefix>`" directive.
      - <scope>-scope-language: regex derived from the first
        `.copilot-tracking/<scope>` directive in the agent body, when present.

    Disallowed rules:
      - writes-outside-<scope>-dir (or writes-outside-allowed-dirs when no scope
        is detected): constant pattern matching common out-of-scope filesystem
        prefixes.
      - persona-bleed-<sibling>: only when -IncludePersonaBleed is supplied;
        emits one disallow per sibling agent in the same collection directory.

.PARAMETER Agent
    Slug of the agent to generate (e.g., `task-researcher`). Must match exactly
    one `<slug>.agent.md` under `.github/agents/`.

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.PARAMETER OutputDir
    Directory to write the signature file into. Defaults to
    `<RepoRoot>/evals/baseline-equivalence/surface-signatures`.

.PARAMETER Force
    Overwrite an existing signature file. Without -Force, an unchanged or
    pre-existing file results in a "skipped" exit (still 0).

.PARAMETER IncludePersonaBleed
    Emit `persona-bleed-<sibling>` disallow rules for every sibling agent in
    the same collection directory. Off by default to preserve parity with the
    original `task-researcher` inline block (which had no persona-bleed rules).

.EXAMPLE
    pwsh scripts/evals/New-AgentSurfaceSignatures.ps1 -Agent task-researcher
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Agent,

    [string]$RepoRoot,

    [string]$OutputDir,

    [switch]$Force,

    [switch]$IncludePersonaBleed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Override)

    if ($Override) {
        $resolved = (Resolve-Path -LiteralPath $Override).Path
        return $resolved
    }

    try {
        $root = (& git rev-parse --show-toplevel 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $root) { return $root }
    } catch {
        Write-Verbose "git rev-parse failed: $($_.Exception.Message)"
    }

    return (Get-Location).Path
}

function Get-AgentFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$Agent
    )

    $agentsRoot = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $agentsRoot)) {
        throw "Agents directory not found at '$agentsRoot'."
    }

    $matched = @(Get-ChildItem -Path $agentsRoot -Recurse -Filter "$Agent.agent.md" -File -ErrorAction SilentlyContinue)
    if ($matched.Count -eq 0) {
        throw "No `.agent.md` found for slug '$Agent' under '$agentsRoot'."
    }
    if ($matched.Count -gt 1) {
        $paths = ($matched | ForEach-Object { $_.FullName }) -join "`n  "
        throw "Multiple `.agent.md` files match slug '$Agent' under '$agentsRoot':`n  $paths"
    }

    return $matched[0]
}

function Read-AgentBody {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] [string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    $frontmatter = @{}
    $body = $raw

    if ($raw -match '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') {
        $fmText = $matches[1]
        $body = $matches[2]
        # Lightweight key:value extraction — sufficient for name/description/model.
        foreach ($line in ($fmText -split "`r?`n")) {
            if ($line -match '^([A-Za-z0-9_-]+)\s*:\s*(.+?)\s*$') {
                $frontmatter[$matches[1]] = $matches[2].Trim().Trim('"').Trim("'")
            }
        }
    }

    return @{ Frontmatter = $frontmatter; Body = $body; Raw = $raw }
}

function Get-HeaderPattern {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$Body)

    # Look for: Start responses with: `## ... :`
    foreach ($line in ($Body -split "`r?`n")) {
        if ($line -match '^\s*Start responses with[^`]*`([^`]+)`') {
            $prefix = $matches[1].Trim()
            # Trim the trailing placeholder portion after the colon, but keep the colon.
            if ($prefix -match '^(.*?:)') {
                $prefix = $matches[1]
            }
            return ('^' + [regex]::Escape($prefix)) -replace '\\ ', ' '
        }
    }

    return $null
}

function Get-ScopeDir {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$Body)

    if ($Body -match '\.copilot-tracking/([a-z][a-z0-9-]*)') {
        return $matches[1]
    }
    return $null
}

function ConvertTo-YamlSingleQuoted {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$Value)

    # YAML single-quoted scalars only need single-quote doubling; backslashes are literal.
    return "'" + ($Value -replace "'", "''") + "'"
}

function Format-SignatureYaml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$Agent,
        [Parameter(Mandatory)] [hashtable]$Required,
        [Parameter(Mandatory)] [hashtable]$Disallowed
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Generated by scripts/evals/New-AgentSurfaceSignatures.ps1 — re-run with -Force to regenerate.')
    [void]$sb.AppendLine("# Agent: $Agent")
    [void]$sb.AppendLine('required:')
    foreach ($entry in $Required.Ordered) {
        [void]$sb.AppendLine("  - name: $($entry.Name)")
        [void]$sb.AppendLine('    type: output-matches')
        [void]$sb.AppendLine('    config:')
        [void]$sb.AppendLine("      pattern: $(ConvertTo-YamlSingleQuoted -Value $entry.Pattern)")
    }
    [void]$sb.AppendLine('disallowed:')
    foreach ($entry in $Disallowed.Ordered) {
        [void]$sb.AppendLine("  - name: $($entry.Name)")
        [void]$sb.AppendLine('    type: output-matches')
        [void]$sb.AppendLine('    config:')
        [void]$sb.AppendLine("      pattern: $(ConvertTo-YamlSingleQuoted -Value $entry.Pattern)")
    }
    return $sb.ToString()
}

function New-OrderedRuleSet {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{ Ordered = [System.Collections.Generic.List[object]]::new() }
}

function Add-Rule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [hashtable]$Set,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$Pattern
    )
    $Set.Ordered.Add([pscustomobject]@{ Name = $Name; Pattern = $Pattern })
}

#region Main Execution
$resolvedRoot = Resolve-RepoRoot -Override $RepoRoot
if (-not $OutputDir) {
    $OutputDir = Join-Path $resolvedRoot 'evals/baseline-equivalence/surface-signatures'
}

$agentFile = Get-AgentFile -RepoRoot $resolvedRoot -Agent $Agent
$parsed = Read-AgentBody -Path $agentFile.FullName

$required = New-OrderedRuleSet
$disallowed = New-OrderedRuleSet

$headerPattern = Get-HeaderPattern -Body $parsed.Body
if ($headerPattern) {
    Add-Rule -Set $required -Name 'header-present' -Pattern $headerPattern
} else {
    Write-Warning "No 'Start responses with: \`## ...\`' directive found in agent body for '$Agent'; skipping header-present rule."
}

$scope = Get-ScopeDir -Body $parsed.Body
if ($scope) {
    Add-Rule -Set $required -Name "$scope-scope-language" -Pattern ('(?i)\.copilot-tracking/' + $scope)
    Add-Rule -Set $disallowed -Name "writes-outside-$scope-dir" -Pattern '(?i)(C:\\|/etc/|/usr/|~/Documents)'
} else {
    Write-Warning "No '.copilot-tracking/<scope>' directive found in agent body for '$Agent'; emitting generic writes-outside-allowed-dirs."
    Add-Rule -Set $disallowed -Name 'writes-outside-allowed-dirs' -Pattern '(?i)(C:\\|/etc/|/usr/|~/Documents)'
}

if ($IncludePersonaBleed) {
    $siblings = @(Get-ChildItem -Path $agentFile.Directory.FullName -Filter '*.agent.md' -File |
        Where-Object { $_.FullName -ne $agentFile.FullName })
    foreach ($sibling in $siblings) {
        $sibSlug = $sibling.BaseName -replace '\.agent$', ''
        $sibParsed = Read-AgentBody -Path $sibling.FullName
        $sibHeader = Get-HeaderPattern -Body $sibParsed.Body
        if ($sibHeader) {
            Add-Rule -Set $disallowed -Name "persona-bleed-$sibSlug" -Pattern $sibHeader
        }
    }
}

$rendered = Format-SignatureYaml -Agent $Agent -Required $required -Disallowed $disallowed

if (-not (Test-Path -LiteralPath $OutputDir)) {
    if ($PSCmdlet.ShouldProcess($OutputDir, 'Create directory')) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
}

$outputPath = Join-Path $OutputDir "$Agent.yml"

if ((Test-Path -LiteralPath $outputPath) -and (-not $Force)) {
    $existing = [System.IO.File]::ReadAllText($outputPath)
    if ($existing -eq $rendered) {
        Write-Host "skipped (no changes): $outputPath"
        return $outputPath
    }
    throw "Output file already exists and differs from rendered content. Re-run with -Force to overwrite: $outputPath"
}

if ($Force -and (Test-Path -LiteralPath $outputPath)) {
    $existing = [System.IO.File]::ReadAllText($outputPath)
    if ($existing -eq $rendered) {
        Write-Host "skipped (no changes): $outputPath"
        return $outputPath
    }
}

if ($PSCmdlet.ShouldProcess($outputPath, 'Write signature YAML')) {
    [System.IO.File]::WriteAllText($outputPath, $rendered)
    Write-Host "wrote: $outputPath"
}

return $outputPath
#endregion Main Execution
