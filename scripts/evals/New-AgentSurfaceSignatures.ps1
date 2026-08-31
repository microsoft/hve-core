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
      - <scope>-scope-language: regex accepting any
        `.copilot-tracking/<scope>` directive found in the agent body. An agent
        that declares several tracking roots yields one alternation accepting
        every detected scope; the rule name uses the first scope in first-seen
        order purely as a stable label.

    Disallowed rules:
      - writes-outside-<scope>-dir (or writes-outside-allowed-dirs when no scope
        is detected): matches out-of-scope filesystem prefixes, including any
        Windows drive-letter path.
      - persona-bleed-<sibling>: only when -IncludePersonaBleed is supplied;
        emits one disallow per sibling agent in the same package directory.

.PARAMETER Agent
    Slug of the agent to generate (e.g., `rpi-agent`). Must match exactly
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
    the same package directory. Off by default to preserve parity with the
    original inline block, which had no persona-bleed rules.

.EXAMPLE
    pwsh scripts/evals/New-AgentSurfaceSignatures.ps1 -Agent rpi-agent
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
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [string]$Body)

    # An agent may declare more than one tracking root (for example, one per
    # supported platform). Collect every distinct scope in first-seen order so
    # the generated signature accepts all of them rather than only the first.
    $scopes = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Body, '\.copilot-tracking/([a-z][a-z0-9-]*)')) {
        $scope = $match.Groups[1].Value
        if (-not $scopes.Contains($scope)) {
            [void]$scopes.Add($scope)
        }
    }

    if ($scopes.Count -eq 0) {
        return @()
    }

    return $scopes.ToArray()
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

# Wrap in @() so a zero-scope or single-scope result stays an array. PowerShell
# unrolls both, which would otherwise make .Count fail under StrictMode and make
# $scopes[0] return the first character of a single scope name.
$scopes = @(Get-ScopeDir -Body $parsed.Body)
if ($scopes.Count -gt 0) {
    $primaryScope = $scopes[0]
    $scopeAlternation = ($scopes | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $scopePattern = if ($scopes.Count -gt 1) {
        '(?i)\.copilot-tracking/(' + $scopeAlternation + ')'
    } else {
        '(?i)\.copilot-tracking/' + $primaryScope
    }
    Add-Rule -Set $required -Name "$primaryScope-scope-language" -Pattern $scopePattern

    Add-Rule -Set $disallowed -Name "writes-outside-$primaryScope-dir" -Pattern '(?i)([A-Za-z]:\\|/etc/|/usr/|~/Documents)'
} else {
    Write-Warning "No '.copilot-tracking/<scope>' directive found in agent body for '$Agent'; emitting generic writes-outside-allowed-dirs."
    Add-Rule -Set $disallowed -Name 'writes-outside-allowed-dirs' -Pattern '(?i)([A-Za-z]:\\|/etc/|/usr/|~/Documents)'
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
