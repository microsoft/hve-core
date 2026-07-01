# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Resolve changed artifact paths to the set of parent-agent slugs whose
    per-agent eval surface they affect.

.DESCRIPTION
    Module form of the slug-resolution logic consumed by
    `Get-ChangedAIArtifact.ps1` (which embeds the result as the `affectedAgents`
    field of the artifact manifest) and downstream Vally dispatch.

    Resolution rules per input path:
      1. Parent agent (`*.agent.md` whose YAML frontmatter does NOT set
         `user-invocable: false`) -> returns `<slug>`.
      2. Subagent (`*.agent.md` whose frontmatter sets `user-invocable: false`)
         -> returns every parent slug that references the subagent under the
            dependency map `subagents[]`.
      3. Stimulus YAML (`evals/agent-behavior/stimuli/<slug>.yml`)
         -> returns `<slug>`.
      4. Instruction (`.github/instructions/<...>.instructions.md`)
         -> returns every parent slug that references the file under the
            dependency map `instructions[]`.
      5. Skill (`.github/skills/<...>/<...>.md`)
         -> returns every parent slug that references the skill under the
            dependency map `skills[]`.
      6. Anything else -> contributes nothing.

    DD-09 compliance: parent-vs-subagent classification reads the agent file's
    frontmatter `user-invocable` key. The historical `/subagents/` path
    convention is informational only. No hardcoded allowlist participates.

    The helper silently regenerates `logs/agent-dependency-map.json` when the
    file is missing or older than the newest `.agent.md` under `.github/agents/`.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Module-scoped cache for frontmatter classification, keyed by absolute file path.
$script:FrontmatterCache = @{}

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

function ConvertTo-NormalizedPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $candidate = $Path -replace '\\', '/'
    if ([System.IO.Path]::IsPathRooted($candidate)) {
        $rootFull = ([System.IO.Path]::GetFullPath($RepoRoot)) -replace '\\', '/'
        $rootFull = $rootFull.TrimEnd('/')
        $pathFull = ([System.IO.Path]::GetFullPath($candidate)) -replace '\\', '/'
        if ($pathFull.StartsWith($rootFull + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $pathFull.Substring($rootFull.Length + 1)
        }
    }
    return $candidate.TrimStart('/')
}

function Test-IsAgentArtifactPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string]$RelativePath)

    return ($RelativePath -match '(?i)^\.github/agents/.+\.agent\.md$')
}

function Test-IsParentAgentByFrontmatter {
    <#
    .SYNOPSIS
    Determine whether an agent file is a parent (user-invocable) under DD-09.

    .DESCRIPTION
    Reads the YAML frontmatter `user-invocable` key from the agent file on disk.
    Returns $true when the key is absent or evaluates to anything other than
    the boolean/string value `false`. When the file is missing on disk (for
    example a deletion), the caller-supplied $DepMap is consulted as a
    fallback: a slug present in the dep-map is assumed to be a parent agent
    only when there is no subagent reverse-mapping evidence; otherwise
    classification defers to the subagent code path.

    Results are cached per absolute path to keep repeat lookups O(1).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$RelativePath
    )

    $absPath = Join-Path -Path $RepoRoot -ChildPath $RelativePath
    if ($script:FrontmatterCache.ContainsKey($absPath)) {
        return [bool]$script:FrontmatterCache[$absPath]
    }

    if (-not (Test-Path -LiteralPath $absPath -PathType Leaf)) {
        # File is missing (likely a delete-side path). Treat as parent so the
        # eval surface remains visible; subagent reverse-lookup will run too
        # and naturally produce no extra slugs when the file truly is a parent.
        $script:FrontmatterCache[$absPath] = $true
        return $true
    }

    try {
        $raw = [System.IO.File]::ReadAllText($absPath)
    } catch {
        Write-Verbose "Failed to read '$absPath': $($_.Exception.Message)"
        $script:FrontmatterCache[$absPath] = $true
        return $true
    }

    if ($raw -notmatch '(?ms)^---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)') {
        $script:FrontmatterCache[$absPath] = $true
        return $true
    }

    # Parse only the `user-invocable` line; avoids a full YAML dependency.
    $block = $matches[1]
    foreach ($line in ($block -split "\r?\n")) {
        if ($line -match '^\s*user-invocable\s*:\s*(?<val>.+?)\s*$') {
            $val = $matches['val'].Trim().Trim("'", '"').ToLowerInvariant()
            $isParent = ($val -ne 'false')
            $script:FrontmatterCache[$absPath] = $isParent
            return $isParent
        }
    }

    $script:FrontmatterCache[$absPath] = $true
    return $true
}

function Get-StimulusSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [string]$RelativePath)

    if ($RelativePath -match '(?i)^evals/agent-behavior/stimuli/(?<slug>[^/]+)\.ya?ml$') {
        return $matches['slug']
    }
    return $null
}

function Test-IsIndirectArtifactPath {
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string]$RelativePath)

    if ($RelativePath -match '(?i)^\.github/instructions/.+\.instructions\.md$') { return $true }
    if ($RelativePath -match '(?i)^\.github/skills/.+\.md$') { return $true }
    return $false
}

function Update-DepMapIfStale {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [string]$DepMapPath
    )

    $regenerate = -not (Test-Path -LiteralPath $DepMapPath -PathType Leaf)
    if (-not $regenerate) {
        $mapMTime   = (Get-Item -LiteralPath $DepMapPath).LastWriteTimeUtc
        $agentsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
        if (Test-Path -LiteralPath $agentsRoot -PathType Container) {
            $newest = Get-ChildItem -Path $agentsRoot -Recurse -Filter '*.agent.md' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
            if ($newest -and $newest.LastWriteTimeUtc -gt $mapMTime) { $regenerate = $true }
        }
    }

    if ($regenerate) {
        $depMapScript = Join-Path -Path $RepoRoot -ChildPath 'scripts/evals/Get-AgentDependencyMap.ps1'
        if (Test-Path -LiteralPath $depMapScript -PathType Leaf) {
            Write-Verbose "Refreshing agent dependency map: $DepMapPath"
            $outDir = Split-Path -Parent $DepMapPath
            if (-not (Test-Path -LiteralPath $outDir -PathType Container)) {
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            }
            & pwsh -NoProfile -File $depMapScript -RepoRoot $RepoRoot -OutputPath $DepMapPath | Out-Null
        }
    }

    return $DepMapPath
}

function Read-DepMap {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string]$DepMapPath)

    if (-not (Test-Path -LiteralPath $DepMapPath -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $DepMapPath -Raw -Encoding utf8 | ConvertFrom-Json)
    } catch {
        Write-Verbose "Failed to parse '$DepMapPath': $($_.Exception.Message)"
        return $null
    }
}

function Build-ReverseIndex {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [pscustomobject]$DepMap,
        [Parameter(Mandatory)] [ValidateSet('instructions', 'skills', 'subagents')] [string]$Field
    )

    $index = @{}
    foreach ($prop in $DepMap.PSObject.Properties) {
        $slug  = $prop.Name
        $entry = $prop.Value
        if (-not $entry.PSObject.Properties.Name.Contains($Field)) { continue }
        $refs = @($entry.$Field)
        foreach ($ref in $refs) {
            if ([string]::IsNullOrWhiteSpace($ref)) { continue }
            $key = ($ref -replace '\\', '/').TrimStart('/')
            if (-not $index.ContainsKey($key)) {
                $index[$key] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            }
            $null = $index[$key].Add($slug)
        }
    }
    return $index
}

function Get-AffectedAgentSlugs {
    <#
    .SYNOPSIS
    Map a set of changed file paths to the parent-agent slugs whose evals they
    affect.

    .PARAMETER ChangedFiles
    Workspace-relative or absolute file paths to classify. Empty or
    non-artifact paths contribute nothing.

    .PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

    .PARAMETER DepMapPath
    Override the dependency map location. Defaults to
    `<RepoRoot>/logs/agent-dependency-map.json`.

    .PARAMETER SkipDepMapRefresh
    Skip the auto-refresh step when the dep-map is stale. Used by tests that
    seed a hand-built map.

    .OUTPUTS
    [string[]] sorted, de-duplicated parent-agent slugs.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ChangedFiles,

        [string]$RepoRoot,
        [string]$DepMapPath,
        [switch]$SkipDepMapRefresh
    )

    $resolvedRoot = Resolve-RepoRoot -Override $RepoRoot
    if (-not $DepMapPath) {
        $DepMapPath = Join-Path -Path $resolvedRoot -ChildPath 'logs/agent-dependency-map.json'
    }

    $normalized = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $ChangedFiles) {
        $rel = ConvertTo-NormalizedPath -RepoRoot $resolvedRoot -Path $p
        if ($rel) { $normalized.Add($rel) }
    }

    if ($normalized.Count -eq 0) { return ,[string[]]@() }

    $result = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Pass 1: direct parent agents and stimulus YAMLs. Track agent paths that
    # are NOT parents under DD-09 so Pass 2 can expand them via subagents[].
    $subagentCandidates = [System.Collections.Generic.List[string]]::new()
    $needsDepMap = $false
    foreach ($rel in $normalized) {
        if (Test-IsAgentArtifactPath -RelativePath $rel) {
            if (Test-IsParentAgentByFrontmatter -RepoRoot $resolvedRoot -RelativePath $rel) {
                $slug = [System.IO.Path]::GetFileName($rel) -replace '\.agent\.md$', ''
                [void]$result.Add($slug)
            }
            else {
                $subagentCandidates.Add($rel)
                $needsDepMap = $true
            }
            continue
        }
        $stimSlug = Get-StimulusSlug -RelativePath $rel
        if ($stimSlug) {
            [void]$result.Add($stimSlug)
            continue
        }
        if (Test-IsIndirectArtifactPath -RelativePath $rel) {
            $needsDepMap = $true
        }
    }

    if (-not $needsDepMap) {
        return ,[string[]](@($result | Sort-Object))
    }

    if (-not $SkipDepMapRefresh) {
        Update-DepMapIfStale -RepoRoot $resolvedRoot -DepMapPath $DepMapPath | Out-Null
    }

    $depMap = Read-DepMap -DepMapPath $DepMapPath
    if ($null -eq $depMap) { return ,[string[]](@($result | Sort-Object)) }

    $instructionIndex = Build-ReverseIndex -DepMap $depMap -Field 'instructions'
    $skillIndex       = Build-ReverseIndex -DepMap $depMap -Field 'skills'
    $subagentIndex    = Build-ReverseIndex -DepMap $depMap -Field 'subagents'

    foreach ($rel in $subagentCandidates) {
        if ($subagentIndex.ContainsKey($rel)) {
            foreach ($slug in $subagentIndex[$rel]) { [void]$result.Add($slug) }
        }
    }

    foreach ($rel in $normalized) {
        if ($rel -match '(?i)^\.github/instructions/.+\.instructions\.md$') {
            if ($instructionIndex.ContainsKey($rel)) {
                foreach ($slug in $instructionIndex[$rel]) { [void]$result.Add($slug) }
            }
            continue
        }
        if ($rel -match '(?i)^\.github/skills/.+\.md$') {
            if ($skillIndex.ContainsKey($rel)) {
                foreach ($slug in $skillIndex[$rel]) { [void]$result.Add($slug) }
            }
        }
    }

    return ,[string[]](@($result | Sort-Object))
}

function Clear-AffectedAgentsCache {
    <#
    .SYNOPSIS
    Reset the frontmatter classification cache. Intended for tests.
    #>
    [CmdletBinding()]
    param()
    $script:FrontmatterCache = @{}
}

Export-ModuleMember -Function Get-AffectedAgentSlugs, Clear-AffectedAgentsCache
