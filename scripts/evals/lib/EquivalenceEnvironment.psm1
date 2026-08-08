# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# EquivalenceEnvironment.psm1
# Purpose: Materialize a per-agent customization surface, enforce filesystem
# containment on every materialization input, and manage baseline run reuse for the
# baseline-equivalence suite.

#Requires -Version 7.4

<#
.SYNOPSIS
    Environment materialization and baseline reuse for the baseline-equivalence suite.

.DESCRIPTION
    The equivalence suite answers "does adding a customization change behavior that
    should not change". Answering it requires two things this module provides.

    First, the customized side must be specific to the agent under test. Passing the
    whole `.github/skills` tree loads every skill for every agent, so two different
    agents produce identical customized runs and the comparison cannot discriminate
    between them. `New-CustomizedEnvironment` materializes only the agent under test:
    its own agent file, its declared instructions, its subagents, and just the skills
    it actually references.

    Second, the baseline is the same for every agent, so re-running it per agent wastes
    roughly half of all trials. `Get-BaselineCacheEntry` and `Save-BaselineCacheEntry`
    persist one baseline run and reuse it, keyed on the inputs that would invalidate
    it. A cached baseline produced by a different model or a different Vally version is
    not reused, because comparing against it would silently attribute a tooling change
    to the customization under test.
#>

Set-StrictMode -Version Latest

function Get-AgentSkillReference {
    <#
    .SYNOPSIS
        Returns the skill directories an agent references, by path or by name.
    .DESCRIPTION
        Agent bodies cite skills two ways. Some use explicit paths such as
        `.github/skills/<collection>/<skill>/SKILL.md`. Others name the skill in
        backticks, which is how the RPI agent references `rpi-research` and its peers.
        Resolving only the path form yields an empty skill set for those agents, which
        would materialize an empty customization and make the comparison meaningless.
        Both forms are resolved here against the skills actually present on disk.
    .OUTPUTS
        [string[]] Workspace-relative skill directory paths, deduplicated and sorted.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentFilePath
    )

    $skillsRoot = Join-Path $RepoRoot '.github/skills'
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) { return @() }

    $available = @{}
    foreach ($skillFile in (Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue)) {
        $dir = Split-Path -Parent $skillFile.FullName
        $name = Split-Path -Leaf $dir
        $relative = $dir.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        if (-not $available.ContainsKey($name)) { $available[$name] = $relative }
    }

    $full = if ([System.IO.Path]::IsPathRooted($AgentFilePath)) { $AgentFilePath } else { Join-Path $RepoRoot $AgentFilePath }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return @() }
    $body = Get-Content -LiteralPath $full -Raw

    $resolved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($match in [regex]::Matches($body, '\.github/skills/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)')) {
        $candidate = ".github/skills/$($match.Groups[1].Value)/$($match.Groups[2].Value)"
        if (Test-Path -LiteralPath (Join-Path $RepoRoot (Join-Path $candidate 'SKILL.md')) -PathType Leaf) {
            [void]$resolved.Add($candidate)
        }
    }

    foreach ($match in [regex]::Matches($body, '`([A-Za-z0-9][A-Za-z0-9_-]{2,})`')) {
        $name = $match.Groups[1].Value
        if ($available.ContainsKey($name)) { [void]$resolved.Add($available[$name]) }
    }

    return @($resolved) | Sort-Object
}

function Resolve-AgentScopePattern {
    <#
    .SYNOPSIS
        Resolves the customized-run scope-language grader pattern for an agent.
    .DESCRIPTION
        The retired surface-signature generator derived a per-agent rule from the first
        `.copilot-tracking/<scope>` directive in the agent body, then wrote it into a
        top-level key that Vally never read. The rule is reinstated here as a real
        grader pattern supplied through `vally eval --param`.

        Agents that write tracking artifacts get an anchored pattern asserting the
        customized run names its own tracking directory. Agents that write none are
        exempt: advisory agents such as agile-coach and dependency-reviewer reference
        no tracking directory at all, so there is no scope to assert. Because params
        substitute values and cannot remove a grader from a spec shared by every agent,
        an exempt agent receives a pattern that matches anything.

        A vacuous pattern that passes silently would recreate the defect this work
        exists to remove, so `Exempt` is returned alongside the pattern for the caller
        to surface in run output.
    .OUTPUTS
        [hashtable] Keys: Scope (string or $null), Pattern (string), Exempt (bool).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Agent
    )

    $exempt = @{ Scope = $null; Pattern = '.*'; Exempt = $true }

    $agentsRoot = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $agentsRoot -PathType Container)) { return $exempt }

    $agentFile = Get-ChildItem -LiteralPath $agentsRoot -Recurse -File -Filter "$Agent.agent.md" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $agentFile) { return $exempt }

    $body = Get-Content -LiteralPath $agentFile.FullName -Raw
    $match = [regex]::Match($body, '\.copilot-tracking/([a-z0-9][a-z0-9-]*)')
    if (-not $match.Success) { return $exempt }

    $scope = $match.Groups[1].Value
    return @{
        Scope   = $scope
        Pattern = "(?i)\.copilot-tracking/$([regex]::Escape($scope))"
        Exempt  = $false
    }
}

function Assert-ContainedRepositoryPath {
    <#
    .SYNOPSIS
        Verifies a path is a link-free regular entry beneath an approved root.
    .DESCRIPTION
        Materialization copies repository-controlled content into a workspace that a
        credential-bearing evaluation process then reads. A pull request can replace an
        expected file with a symbolic link or reparse point, so copying by path alone
        would let the run follow that link outside the repository and surface whatever
        it points at through model output and logs.

        Containment is checked on the resolved path rather than the supplied string,
        because a path that looks contained can still resolve elsewhere through a link
        in any of its parent segments.
    .OUTPUTS
        [string] The verified full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovedRoot,

        [Parameter(Mandatory = $false)]
        [string]$Because = 'materialization input'
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.LinkType -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw "Refusing to materialize $Because '$Path': symbolic links and reparse points are not permitted."
    }

    $rootFull = [System.IO.Path]::GetFullPath((Get-Item -LiteralPath $ApprovedRoot -Force -ErrorAction Stop).FullName)
    $rootPrefix = $rootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $resolved = [System.IO.Path]::GetFullPath($item.FullName)

    if ($resolved -ne $rootFull -and -not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to materialize $Because '$Path': resolved path '$resolved' escapes the approved root '$rootFull'."
    }

    return $resolved
}

function Get-AgentDeclaredDependency {
    <#
    .SYNOPSIS
        Resolves the instructions and subagents an agent declares.
    .DESCRIPTION
        Dependency discovery lives here rather than in an optional side-channel file.
        The driver previously read a generated map from an ignored logs path and treated
        any read failure as an empty map, so a run that never generated it materialized
        only the agent file and its directly referenced skills. The comparison then
        reported a clean result for a surface that omitted every declared instruction
        and subagent.

        Resolution reads the agent body directly, so it cannot silently degrade: a
        declared reference that does not exist on disk is an error rather than an
        omission.
    .OUTPUTS
        [hashtable] With keys Instructions and Subagents, each workspace-relative paths.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentRelativePath
    )

    $instructions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $subagents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $full = Join-Path $RepoRoot $AgentRelativePath
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Agent file '$AgentRelativePath' does not exist. Refusing to materialize an incomplete customization surface."
    }
    $body = Get-Content -LiteralPath $full -Raw
    $agentDir = Split-Path -Parent $AgentRelativePath

    # Cross-kind references resolve relative to the containing file, so a repository
    # `#file:` path such as `../../instructions/<name>.instructions.md` is normalized
    # against the agent's own directory rather than assumed to start at the repo root.
    $normalize = {
        param([string]$Reference)

        $candidates = [System.Collections.Generic.List[string]]::new()
        $candidates.Add(($Reference -replace '^(\.\./)+', ''))
        if ($agentDir) {
            $combined = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $RepoRoot $agentDir) $Reference))
            $rootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            if ($combined.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $candidates.Add($combined.Substring($rootFull.Length).TrimStart('\', '/').Replace('\', '/'))
            }
        }

        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath (Join-Path $RepoRoot $candidate) -PathType Leaf) { return $candidate }
        }
        return $null
    }

    foreach ($match in [regex]::Matches($body, '[A-Za-z0-9_./-]*\.instructions\.md')) {
        $resolved = & $normalize $match.Value
        if ($resolved) { [void]$instructions.Add($resolved) }
    }

    foreach ($match in [regex]::Matches($body, '[A-Za-z0-9_./*-]*\.agent\.md')) {
        # Glob references such as `.github/agents/**/name.agent.md` name a subagent
        # whose collection directory is intentionally unspecified.
        if ($match.Value -match '\*') {
            $leaf = Split-Path -Leaf ($match.Value -replace '\*+/?', '')
            if (-not [string]::IsNullOrWhiteSpace($leaf)) {
                $file = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($file) {
                    [void]$subagents.Add($file.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/'))
                }
            }
            continue
        }
        $resolved = & $normalize $match.Value
        if ($resolved -and $resolved -ne $AgentRelativePath) { [void]$subagents.Add($resolved) }
    }

    # Frontmatter `agents:` names subagents by stable name rather than by path.
    $frontmatter = [regex]::Match($body, '(?s)\A---\r?\n(.*?)\r?\n---')
    if ($frontmatter.Success) {
        $agentsBlock = [regex]::Match($frontmatter.Groups[1].Value, '(?ms)^agents:\s*$(.*?)(?=^\S|\z)')
        if ($agentsBlock.Success) {
            foreach ($entry in [regex]::Matches($agentsBlock.Groups[1].Value, '(?m)^\s*-\s*([A-Za-z0-9_.-]+)\s*$')) {
                $name = $entry.Groups[1].Value
                $file = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter "$name.agent.md" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($file) {
                    [void]$subagents.Add($file.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/'))
                }
            }
        }
    }

    return @{
        Instructions = @($instructions | Sort-Object)
        Subagents    = @($subagents | Sort-Object)
    }
}

function Copy-VerifiedRepositoryFile {
    <#
    .SYNOPSIS
        Copies one repository-relative file into a workspace after verifying it.
    .OUTPUTS
        [bool] True when the file existed and was copied.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspacePath
    )

    $source = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { return $false }
    if (-not $PSCmdlet.ShouldProcess($source, 'Copy into customized workspace')) { return $false }

    $null = Assert-ContainedRepositoryPath -Path $source -ApprovedRoot $RepoRoot -Because 'customization artifact'

    $target = Join-Path $WorkspacePath $RelativePath
    $targetDir = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force -WhatIf:$false -Confirm:$false | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force -WhatIf:$false -Confirm:$false
    return $true
}

function New-CustomizedEnvironment {
    <#
    .SYNOPSIS
        Materializes one agent's customization surface into an isolated workspace.
    .DESCRIPTION
        Copies the agent file, its declared instructions, its subagents, and only the
        skills it references into a clean workspace and skill directory. Vally receives
        the skill directory through `--skill-dir` and the workspace through
        `--workspace`, so the customized run sees this agent's surface and nothing else.

        Dependencies are resolved from the agent body rather than from an optional
        generated map, so a run cannot quietly materialize a partial surface and then
        report the comparison as clean. Every copied entry is verified to be a
        link-free regular file beneath the repository root.
    .OUTPUTS
        [hashtable] With keys WorkspacePath, SkillDirPath, and Applied.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Agent,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkspacePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillDirPath
    )

    foreach ($path in @($WorkspacePath, $SkillDirPath)) {
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            New-Item -ItemType Directory -Path $path -Force -WhatIf:$false -Confirm:$false | Out-Null
        }
    }

    $applied = [System.Collections.Generic.List[string]]::new()

    $agentFile = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter "$Agent.agent.md" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $agentFile) {
        throw "Agent '$Agent' not found under .github/agents. Cannot materialize a customized environment for an agent that does not exist."
    }
    $agentRelative = $agentFile.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')

    $declared = Get-AgentDeclaredDependency -RepoRoot $RepoRoot -AgentRelativePath $agentRelative

    if (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath $agentRelative -WorkspacePath $WorkspacePath -WhatIf:$false) {
        $applied.Add($agentRelative)
    }

    foreach ($relative in @($declared.Instructions) + @($declared.Subagents)) {
        if ([string]::IsNullOrWhiteSpace($relative)) { continue }
        if (-not (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath ([string]$relative) -WorkspacePath $WorkspacePath -WhatIf:$false)) {
            throw "Declared dependency '$relative' for agent '$Agent' could not be materialized. Refusing to compare against a partial customization surface."
        }
        $applied.Add([string]$relative)
    }

    $copilotInstructions = '.github/copilot-instructions.md'
    if (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath $copilotInstructions -WorkspacePath $WorkspacePath -WhatIf:$false) {
        $applied.Add($copilotInstructions)
    }

    $skillDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($relative in (Get-AgentSkillReference -RepoRoot $RepoRoot -AgentFilePath $agentRelative)) {
        [void]$skillDirs.Add($relative)
    }
    # A subagent's skills are part of the surface the parent agent delivers, so they
    # are resolved transitively rather than left to the agent body alone.
    foreach ($subagentRelative in @($declared.Subagents)) {
        if ([string]::IsNullOrWhiteSpace($subagentRelative)) { continue }
        foreach ($relative in (Get-AgentSkillReference -RepoRoot $RepoRoot -AgentFilePath ([string]$subagentRelative))) {
            [void]$skillDirs.Add($relative)
        }
    }

    foreach ($relative in ($skillDirs | Sort-Object)) {
        $source = Join-Path $RepoRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Container)) { continue }
        $null = Assert-ContainedRepositoryPath -Path $source -ApprovedRoot $RepoRoot -Because 'skill directory'
        foreach ($entry in @(Get-ChildItem -LiteralPath $source -Recurse -Force -ErrorAction SilentlyContinue)) {
            $null = Assert-ContainedRepositoryPath -Path $entry.FullName -ApprovedRoot $RepoRoot -Because 'skill content'
        }
        $target = Join-Path $SkillDirPath (Split-Path -Leaf $relative)
        Copy-Item -LiteralPath $source -Destination $target -Recurse -Force -WhatIf:$false -Confirm:$false
        $applied.Add("$relative/SKILL.md")
    }

    return @{
        WorkspacePath = $WorkspacePath
        SkillDirPath  = $SkillDirPath
        Applied       = @($applied | Sort-Object -Unique)
    }
}

function Get-BaselineCacheKey {
    <#
    .SYNOPSIS
        Builds the invalidation key for a persisted baseline run.
    .DESCRIPTION
        A baseline is reusable only while the inputs that shaped it are unchanged. The
        model and the Vally version both alter agent output, so a baseline captured
        under different values must not be compared against. The stimulus set is
        included through a content hash so that editing a prompt invalidates the cache
        rather than silently comparing new questions against old answers.
    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VallyVersion,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StimulusHash
    )

    $safeModel = $Model -replace '[^A-Za-z0-9._-]', '-'
    $safeVersion = $VallyVersion -replace '[^A-Za-z0-9._-]', '-'
    # The hash is truncated for a readable path, but a sentinel such as 'missing' is
    # shorter than the truncation length, so the shorter of the two is used.
    $safeHash = ($StimulusHash -replace '[^A-Za-z0-9._-]', '-')
    $prefix = $safeHash.Substring(0, [Math]::Min(12, $safeHash.Length))
    return "$safeModel/$safeVersion/$prefix"
}

function Get-StimulusContentHash {
    <#
    .SYNOPSIS
        Returns a stable content hash for the baseline eval spec and its seed workspace.
    .DESCRIPTION
        The hash keys the baseline cache, so it must cover every input that shapes a
        baseline run. The spec supplies the stimuli; the seed workspace supplies the
        files those stimuli act on. Hashing only the spec would let a baseline captured
        against an empty workspace be reused after the seed changed, silently comparing
        a customized run that could act against a baseline that could not.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SpecPath,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$SeedPath
    )

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { return 'missing' }

    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add(((Get-Content -LiteralPath $SpecPath -Raw) -replace "`r`n", "`n"))

    # Sorted relative paths plus content, so a rename or an edit both change the key.
    # Each entry is verified before it is read: hashing follows the same trust boundary
    # as materialization, so a link planted in the seed must not be read here either.
    if ($SeedPath -and (Test-Path -LiteralPath $SeedPath)) {
        $root = (Resolve-Path -LiteralPath $SeedPath).Path
        foreach ($f in @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName)) {
            $null = Assert-ContainedRepositoryPath -Path $f.FullName -ApprovedRoot $root -Because 'seed workspace entry'
            $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            $parts.Add($rel)
            $parts.Add(((Get-Content -LiteralPath $f.FullName -Raw) -replace "`r`n", "`n"))
        }
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n")))
        return (-join ($bytes | ForEach-Object { $_.ToString('x2') }))
    }
    finally { $sha.Dispose() }
}

function Get-BaselineCacheEntry {
    <#
    .SYNOPSIS
        Returns a reusable persisted baseline run directory, or null when none applies.
    .DESCRIPTION
        Returns null rather than a stale directory when the key does not match, so the
        caller regenerates instead of comparing against a baseline captured under
        different conditions.
    .OUTPUTS
        [string] Run directory path, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CacheRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CacheKey
    )

    $entryDir = Join-Path $CacheRoot $CacheKey
    $manifestPath = Join-Path $entryDir 'baseline-cache.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }

    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }

    if (-not $manifest.runDir) { return $null }
    $runDir = if ([System.IO.Path]::IsPathRooted([string]$manifest.runDir)) {
        [string]$manifest.runDir
    }
    else {
        Join-Path $entryDir ([string]$manifest.runDir)
    }

    if (-not (Test-Path -LiteralPath $runDir -PathType Container)) { return $null }
    if (-not (Get-ChildItem -LiteralPath $runDir -Recurse -File -Filter 'results.jsonl' -ErrorAction SilentlyContinue)) { return $null }

    return $runDir
}

function Save-BaselineCacheEntry {
    <#
    .SYNOPSIS
        Persists a baseline run directory for reuse under its invalidation key.
    .OUTPUTS
        [string] The cached run directory path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CacheRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$CacheKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RunDir,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VallyVersion,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StimulusHash
    )

    $entryDir = Join-Path $CacheRoot $CacheKey
    $targetRun = Join-Path $entryDir 'run'

    if (Test-Path -LiteralPath $targetRun) {
        Remove-Item -LiteralPath $targetRun -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $entryDir -Force -WhatIf:$false -Confirm:$false | Out-Null
    Copy-Item -LiteralPath $RunDir -Destination $targetRun -Recurse -Force -WhatIf:$false -Confirm:$false

    $manifest = [ordered]@{
        runDir       = 'run'
        model        = $Model
        vallyVersion = $VallyVersion
        stimulusHash = $StimulusHash
        capturedAt   = (Get-Date -AsUTC).ToString('o')
    }
    $manifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $entryDir 'baseline-cache.json') -Encoding utf8NoBOM

    return $targetRun
}

Export-ModuleMember -Function @(
    'Get-AgentSkillReference',
    'Get-AgentDeclaredDependency',
    'Assert-ContainedRepositoryPath',
    'Resolve-AgentScopePattern',
    'New-CustomizedEnvironment',
    'Get-BaselineCacheKey',
    'Get-StimulusContentHash',
    'Get-BaselineCacheEntry',
    'Save-BaselineCacheEntry'
)
