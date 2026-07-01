#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Build a JSON map of agent dependencies for the baseline-equivalence dispatcher.

.DESCRIPTION
    Walks `.github/agents/**/*.agent.md`, parses each agent's frontmatter and
    body for declared and inline references to instructions, skills, and
    subagents, and emits a deterministic JSON document at
    `<OutputPath>` (default `<RepoRoot>/logs/agent-dependency-map.json`).

    The JSON shape:
    {
      "<slug>": {
        "agent": "<workspace-relative path>",
        "instructions": [ "<path>", ... ],
        "skills":       [ "<path>", ... ],
        "subagents":    [ "<path>", ... ],
        "warnings":     [ "<message>", ... ]
      },
      ...
    }

    All sub-lists are workspace-relative paths, deduplicated, sorted.
    Missing-reference warnings do not fail the script (exit 0). Cyclic
    subagent chains are tolerated.

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.PARAMETER OutputPath
    JSON output path. Defaults to `<RepoRoot>/logs/agent-dependency-map.json`.

.EXAMPLE
    pwsh scripts/evals/Get-AgentDependencyMap.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([string])]
param(
    [string]$RepoRoot,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

function Read-AgentFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] [string]$Path)

    $raw = [System.IO.File]::ReadAllText($Path)
    $frontmatter = ''
    $body = $raw
    if ($raw -match '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') {
        $frontmatter = $matches[1]
        $body = $matches[2]
    }
    return @{ Frontmatter = $frontmatter; Body = $body }
}

function Get-FrontmatterListField {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [string]$Frontmatter,
        [Parameter(Mandatory)] [string]$Field
    )

    $results = New-Object System.Collections.Generic.List[string]
    $lines = $Frontmatter -split "`r?`n"
    $inList = $false
    foreach ($line in $lines) {
        if (-not $inList) {
            if ($line -match "^$Field\s*:\s*\[(.*)\]\s*$") {
                # Flow style: field: [a, b, c]
                $items = $matches[1] -split ','
                foreach ($item in $items) {
                    $t = $item.Trim().Trim('"').Trim("'")
                    if ($t) { $results.Add($t) }
                }
                return $results.ToArray()
            }
            if ($line -match "^$Field\s*:\s*$") {
                $inList = $true
                continue
            }
        } else {
            if ($line -match '^\s*-\s*(.+?)\s*$') {
                $results.Add($matches[1].Trim().Trim('"').Trim("'"))
            } elseif ($line -match '^\S') {
                # Next top-level key; stop.
                break
            }
        }
    }
    return $results.ToArray()
}

function Find-ReferenceMatches {
    [CmdletBinding()]
    [OutputType([string[]])]
    param([Parameter(Mandatory)] [string]$Body)

    $hits = New-Object System.Collections.Generic.List[string]
    # #file:<path> directives
    foreach ($m in [regex]::Matches($Body, '#file:([^\s\)`]+)')) {
        $hits.Add($m.Groups[1].Value)
    }
    # Markdown links into .github/{instructions,skills,agents}/
    foreach ($m in [regex]::Matches($Body, '\]\(([^)]*\.github/(?:instructions|skills|agents)/[^)]+)\)')) {
        $hits.Add($m.Groups[1].Value)
    }
    # Markdown links targeting any *.agent.md, *.instructions.md, or SKILL.md (covers `../../skills/...` relative links).
    foreach ($m in [regex]::Matches($Body, '\]\(([^)]+(?:\.agent\.md|\.instructions\.md|/SKILL\.md))\)')) {
        $hits.Add($m.Groups[1].Value)
    }
    # Bare path mentions of .github/{instructions,skills}/...md or .github/agents/...agent.md
    foreach ($m in [regex]::Matches($Body, '\.github/(?:instructions|skills|agents)/[A-Za-z0-9_./*-]+\.(?:md|agent\.md|instructions\.md)')) {
        $hits.Add($m.Value)
    }
    # Bare mentions of skill subpaths (e.g. `.github/skills/jira/jira/scripts/jira.py`) → resolve to SKILL.md anchor.
    foreach ($m in [regex]::Matches($Body, '\.github/skills/([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)/')) {
        $hits.Add(".github/skills/$($m.Groups[1].Value)/$($m.Groups[2].Value)/SKILL.md")
    }
    return $hits.ToArray()
}

function Resolve-RefToFiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$Ref,
        [string]$SourceDir
    )

    $normalized = $Ref -replace '\\', '/'
    # Strip a single leading './' but preserve other leading dots (e.g. `.github/...`).
    if ($normalized.StartsWith('./')) { $normalized = $normalized.Substring(2) }
    # Strip a leading absolute slash (treat as repo-root relative).
    $normalized = $normalized.TrimStart('/')
    # Drop a trailing punctuation char (sentence-end periods leaking into refs).
    $normalized = $normalized -replace '[.,;:)\]]+$', ''

    # Candidate bases: explicit source dir first (for `../../...` style refs), then repo root.
    $bases = New-Object System.Collections.Generic.List[string]
    if ($normalized.StartsWith('../') -or $normalized.StartsWith('./')) {
        if ($SourceDir) { $bases.Add($SourceDir) }
        $bases.Add($RepoRoot)
    } else {
        $bases.Add($RepoRoot)
        if ($SourceDir) { $bases.Add($SourceDir) }
    }

    # Glob expansion via Get-ChildItem when wildcards present
    if ($normalized.Contains('*')) {
        foreach ($base in $bases) {
            # Handle `**` (recursive any-dir) by splitting on `/**/` and using -Recurse from the prefix.
            if ($normalized -match '^(?<prefix>[^*]+)/\*\*/(?<leaf>.+)$') {
                $prefix = Join-Path $base $matches.prefix
                $leaf   = $matches.leaf
                $found  = @(Get-ChildItem -Path $prefix -Recurse -Filter $leaf -ErrorAction SilentlyContinue -File)
            } else {
                $globPath = Join-Path $base $normalized
                $found    = @(Get-ChildItem -Path $globPath -Recurse -ErrorAction SilentlyContinue -File)
            }
            if ($found.Count -gt 0) {
                return ,@($found | ForEach-Object { ConvertTo-RelativePath -RepoRoot $RepoRoot -Path $_.FullName })
            }
        }
        return ,@()
    }

    foreach ($base in $bases) {
        $full = Join-Path $base $normalized
        try { $full = [System.IO.Path]::GetFullPath($full) } catch { continue }
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            return ,@(ConvertTo-RelativePath -RepoRoot $RepoRoot -Path $full)
        }
    }
    return ,@()
}

function Get-AgentSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$AgentPath)
    $leaf = Split-Path -Leaf $AgentPath
    return ($leaf -replace '\.agent\.md$', '')
}

function ConvertTo-DeterministicJson {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [hashtable]$Map)

    $sortedKeys = @($Map.Keys | Sort-Object)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('{')
    for ($i = 0; $i -lt $sortedKeys.Count; $i++) {
        $key = $sortedKeys[$i]
        $record = $Map[$key]
        [void]$sb.AppendLine("  $(ConvertTo-Json $key -Compress): {")
        $fields = @('agent', 'instructions', 'skills', 'subagents', 'warnings')
        for ($j = 0; $j -lt $fields.Count; $j++) {
            $f = $fields[$j]
            $value = $record[$f]
            $jsonValue = if ($value -is [string]) {
                ConvertTo-Json $value -Compress
            } else {
                # Sorted, deduplicated array
                $arr = @($value | Sort-Object -Unique)
                if ($arr.Count -eq 0) {
                    '[]'
                } else {
                    "[`n      " + (($arr | ForEach-Object { ConvertTo-Json $_ -Compress }) -join ",`n      ") + "`n    ]"
                }
            }
            $sep = if ($j -lt ($fields.Count - 1)) { ',' } else { '' }
            [void]$sb.AppendLine("    `"$f`": $jsonValue$sep")
        }
        $sep = if ($i -lt ($sortedKeys.Count - 1)) { ',' } else { '' }
        [void]$sb.AppendLine("  }$sep")
    }
    [void]$sb.Append('}')
    return $sb.ToString() + "`n"
}

#region Main Execution
$resolvedRoot = Resolve-RepoRoot -Override $RepoRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $resolvedRoot 'logs/agent-dependency-map.json'
}

$agentsRoot = Join-Path $resolvedRoot '.github/agents'
if (-not (Test-Path -LiteralPath $agentsRoot)) {
    throw "Agents directory not found at '$agentsRoot'."
}

$agentFiles = @(Get-ChildItem -Path $agentsRoot -Recurse -Filter '*.agent.md' -File)
$map = @{}

foreach ($file in $agentFiles) {
    $slug = Get-AgentSlug -AgentPath $file.Name
    $parsed = Read-AgentFile -Path $file.FullName

    $instructions = New-Object System.Collections.Generic.HashSet[string]
    $skills       = New-Object System.Collections.Generic.HashSet[string]
    $subagents    = New-Object System.Collections.Generic.HashSet[string]
    $warnings     = New-Object System.Collections.Generic.List[string]

    $sourceDir = Split-Path -Parent $file.FullName

    # Frontmatter list fields
    foreach ($ref in (Get-FrontmatterListField -Frontmatter $parsed.Frontmatter -Field 'instructions')) {
        $resolved = Resolve-RefToFiles -RepoRoot $resolvedRoot -Ref $ref -SourceDir $sourceDir
        if ($resolved.Count -eq 0) { $warnings.Add("instructions ref not resolved: $ref") }
        foreach ($r in $resolved) { [void]$instructions.Add($r) }
    }
    foreach ($ref in (Get-FrontmatterListField -Frontmatter $parsed.Frontmatter -Field 'skills')) {
        $resolved = Resolve-RefToFiles -RepoRoot $resolvedRoot -Ref $ref -SourceDir $sourceDir
        if ($resolved.Count -eq 0) { $warnings.Add("skills ref not resolved: $ref") }
        foreach ($r in $resolved) { [void]$skills.Add($r) }
    }
    foreach ($ref in (Get-FrontmatterListField -Frontmatter $parsed.Frontmatter -Field 'agents')) {
        # Frontmatter `agents:` lists by display name (e.g., "Researcher Subagent"); skip path resolution.
        $warnings.Add("agents frontmatter entry recorded by name only: $ref")
    }

    # Body references
    foreach ($ref in (Find-ReferenceMatches -Body $parsed.Body)) {
        $resolved = Resolve-RefToFiles -RepoRoot $resolvedRoot -Ref $ref -SourceDir $sourceDir
        if ($resolved.Count -eq 0) {
            $warnings.Add("body ref not resolved: $ref")
            continue
        }
        foreach ($r in $resolved) {
            if ($r -like '*.agent.md') {
                if ((ConvertTo-RelativePath -RepoRoot $resolvedRoot -Path $file.FullName) -ne $r) {
                    [void]$subagents.Add($r)
                }
            } elseif ($r -like '*.instructions.md') {
                [void]$instructions.Add($r)
            } elseif ($r -like '*/.github/skills/*' -or $r -like '.github/skills/*') {
                [void]$skills.Add($r)
            } elseif ($r -like '*/instructions/*' -or $r -like '*instructions*') {
                [void]$instructions.Add($r)
            } elseif ($r -like '*/skills/*') {
                [void]$skills.Add($r)
            }
        }
    }

    $map[$slug] = @{
        agent        = ConvertTo-RelativePath -RepoRoot $resolvedRoot -Path $file.FullName
        instructions = @($instructions)
        skills       = @($skills)
        subagents    = @($subagents)
        warnings     = @($warnings)
    }
}

foreach ($w in ($map.Values.warnings | Where-Object { $_ })) {
    Write-Warning $w
}

$json = ConvertTo-DeterministicJson -Map $map

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir)) {
    if ($PSCmdlet.ShouldProcess($outDir, 'Create directory')) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write agent dependency map')) {
    # Write with LF line endings.
    [System.IO.File]::WriteAllText($OutputPath, ($json -replace "`r`n", "`n"))
    Write-Host "wrote: $OutputPath ($($map.Count) agents)"
}

return $OutputPath
#endregion Main Execution
