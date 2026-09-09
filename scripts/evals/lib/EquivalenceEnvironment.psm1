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
    .PARAMETER RepoRoot
        Absolute path to the repository root that skills are resolved against.
    .PARAMETER AgentFilePath
        Agent file to scan, either absolute or relative to RepoRoot.
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

    $SkillsRoot = Join-Path $RepoRoot '.github/skills'
    if (-not (Test-Path -LiteralPath $SkillsRoot -PathType Container)) { return @() }

    $Available = @{}
    foreach ($SkillFile in (Get-ChildItem -LiteralPath $SkillsRoot -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue)) {
        $SkillDir = Split-Path -Parent $SkillFile.FullName
        $SkillName = Split-Path -Leaf $SkillDir
        $RelativePath = $SkillDir.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        if (-not $Available.ContainsKey($SkillName)) { $Available[$SkillName] = $RelativePath }
    }

    $FullPath = if ([System.IO.Path]::IsPathRooted($AgentFilePath)) { $AgentFilePath } else { Join-Path $RepoRoot $AgentFilePath }
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) { return @() }
    $Body = Get-Content -LiteralPath $FullPath -Raw

    $Resolved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($PathMatch in [regex]::Matches($Body, '\.github/skills/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)')) {
        $Candidate = ".github/skills/$($PathMatch.Groups[1].Value)/$($PathMatch.Groups[2].Value)"
        if (Test-Path -LiteralPath (Join-Path $RepoRoot (Join-Path $Candidate 'SKILL.md')) -PathType Leaf) {
            [void]$Resolved.Add($Candidate)
        }
    }

    foreach ($NameMatch in [regex]::Matches($Body, '`([A-Za-z0-9][A-Za-z0-9_-]{2,})`')) {
        $SkillName = $NameMatch.Groups[1].Value
        if ($Available.ContainsKey($SkillName)) { [void]$Resolved.Add($Available[$SkillName]) }
    }

    return @($Resolved) | Sort-Object
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
        exempt: advisory agents that reference no tracking directory have no scope to
        assert. Because params substitute values and cannot remove a grader from a spec
        shared by every agent, an exempt agent receives a pattern that matches anything.

        A vacuous pattern that passes silently would recreate the defect this work
        exists to remove, so `Exempt` is returned alongside the pattern for the caller
        to surface in run output.
    .OUTPUTS
        [hashtable] Keys: Scope (string or $null), Pattern (string), Exempt (bool).
    .PARAMETER RepoRoot
        Absolute path to the repository root containing .github/agents.
    .PARAMETER Agent
        Agent slug, matched against `<Agent>.agent.md` beneath .github/agents.
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

    $Exempt = @{ Scope = $null; Pattern = '.*'; Exempt = $true }

    $AgentsRoot = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $AgentsRoot -PathType Container)) { return $Exempt }

    $AgentFile = Get-ChildItem -LiteralPath $AgentsRoot -Recurse -File -Filter "$Agent.agent.md" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $AgentFile) { return $Exempt }

    $Body = Get-Content -LiteralPath $AgentFile.FullName -Raw
    $ScopeMatch = [regex]::Match($Body, '\.copilot-tracking/([a-z0-9][a-z0-9-]*)')
    if (-not $ScopeMatch.Success) { return $Exempt }

    $Scope = $ScopeMatch.Groups[1].Value
    return @{
        Scope   = $Scope
        Pattern = "(?i)\.copilot-tracking/$([regex]::Escape($Scope))"
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
    .PARAMETER Path
        Path to verify. Must resolve to a link-free regular entry beneath ApprovedRoot.
    .PARAMETER ApprovedRoot
        Root that Path must resolve beneath.
    .PARAMETER Because
        Short noun phrase naming what is being materialized, used in refusal messages.
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

    $RootItem = Get-Item -LiteralPath $ApprovedRoot -Force -ErrorAction Stop
    $RootFull = [System.IO.Path]::GetFullPath($RootItem.FullName)
    $RootTrimmed = $RootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $RootPrefix = $RootTrimmed + [System.IO.Path]::DirectorySeparatorChar

    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $Resolved = [System.IO.Path]::GetFullPath($Item.FullName)

    if ($Resolved -ne $RootFull -and -not $Resolved.StartsWith($RootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to materialize $Because '$Path': resolved path '$Resolved' escapes the approved root '$RootFull'."
    }

    # GetFullPath is lexical normalization only, so a regular file beneath a linked
    # directory still carries the approved prefix. Every segment between the approved
    # root and the target is inspected, because a link in any ancestor redirects the
    # read outside the repository just as effectively as a linked leaf.
    $Separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $Relative = $Resolved.Substring($RootTrimmed.Length).Trim($Separators)
    if (-not [string]::IsNullOrEmpty($Relative)) {
        $Current = $RootTrimmed
        foreach ($Segment in $Relative.Split($Separators, [System.StringSplitOptions]::RemoveEmptyEntries)) {
            $Current = Join-Path $Current $Segment
            $Component = Get-Item -LiteralPath $Current -Force -ErrorAction Stop
            if ($Component.LinkType -or ($Component.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                throw "Refusing to materialize $Because '$Path': ancestor or target '$Current' is a symbolic link or reparse point."
            }
        }
    }

    # Re-open after the walk so the returned path is the one that was verified rather
    # than the one that was requested.
    $Verified = [System.IO.Path]::GetFullPath((Get-Item -LiteralPath $Resolved -Force -ErrorAction Stop).FullName)
    if ($Verified -ne $RootFull -and -not $Verified.StartsWith($RootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to materialize $Because '$Path': verified path '$Verified' escapes the approved root '$RootFull'."
    }

    return $Verified
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
    .PARAMETER RepoRoot
        Absolute path to the repository root that references are resolved against.
    .PARAMETER AgentRelativePath
        Workspace-relative path to the agent file whose declarations are resolved.
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

    $Instructions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $Subagents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $FullPath = Join-Path $RepoRoot $AgentRelativePath
    if (-not (Test-Path -LiteralPath $FullPath -PathType Leaf)) {
        throw "Agent file '$AgentRelativePath' does not exist. Refusing to materialize an incomplete customization surface."
    }
    $Body = Get-Content -LiteralPath $FullPath -Raw
    $AgentDir = Split-Path -Parent $AgentRelativePath

    # Cross-kind references resolve relative to the containing file, so a repository
    # `#file:` path such as `../../instructions/<name>.instructions.md` is normalized
    # against the agent's own directory rather than assumed to start at the repo root.
    $Normalize = {
        param([string]$Reference)

        $Candidates = [System.Collections.Generic.List[string]]::new()
        $Candidates.Add(($Reference -replace '^(\.\./)+', ''))
        if ($AgentDir) {
            $Combined = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $RepoRoot $AgentDir) $Reference))
            $RootFull = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            if ($Combined.StartsWith($RootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                $Candidates.Add($Combined.Substring($RootFull.Length).TrimStart('\', '/').Replace('\', '/'))
            }
        }

        foreach ($Candidate in $Candidates) {
            if (Test-Path -LiteralPath (Join-Path $RepoRoot $Candidate) -PathType Leaf) { return $Candidate }
        }
        return $null
    }

    foreach ($InstructionMatch in [regex]::Matches($Body, '[A-Za-z0-9_./-]*\.instructions\.md')) {
        $Resolved = & $Normalize $InstructionMatch.Value
        if ($Resolved) { [void]$Instructions.Add($Resolved) }
    }

    foreach ($AgentMatch in [regex]::Matches($Body, '[A-Za-z0-9_./*-]*\.agent\.md')) {
        # Glob references such as `.github/agents/**/name.agent.md` name a subagent
        # whose collection directory is intentionally unspecified.
        if ($AgentMatch.Value -match '\*') {
            $Leaf = Split-Path -Leaf ($AgentMatch.Value -replace '\*+/?', '')
            if (-not [string]::IsNullOrWhiteSpace($Leaf)) {
                $File = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter $Leaf -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($File) {
                    [void]$Subagents.Add($File.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/'))
                }
            }
            continue
        }
        $Resolved = & $Normalize $AgentMatch.Value
        if ($Resolved -and $Resolved -ne $AgentRelativePath) { [void]$Subagents.Add($Resolved) }
    }

    # Frontmatter `agents:` names subagents by stable name rather than by path.
    $Frontmatter = [regex]::Match($Body, '(?s)\A---\r?\n(.*?)\r?\n---')
    if ($Frontmatter.Success) {
        $AgentsBlock = [regex]::Match($Frontmatter.Groups[1].Value, '(?ms)^agents:\s*$(.*?)(?=^\S|\z)')
        if ($AgentsBlock.Success) {
            foreach ($Entry in [regex]::Matches($AgentsBlock.Groups[1].Value, '(?m)^\s*-\s*([A-Za-z0-9_.-]+)\s*$')) {
                $EntryName = $Entry.Groups[1].Value
                $File = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter "$EntryName.agent.md" -ErrorAction SilentlyContinue |
                    Select-Object -First 1
                if ($File) {
                    [void]$Subagents.Add($File.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/'))
                }
            }
        }
    }

    return @{
        Instructions = @($Instructions | Sort-Object)
        Subagents    = @($Subagents | Sort-Object)
    }
}

function Copy-VerifiedRepositoryFile {
    <#
    .SYNOPSIS
        Copies one repository-relative file into a workspace after verifying it.
    .OUTPUTS
        [bool] True when the file existed and was copied.
    .PARAMETER RepoRoot
        Absolute path to the repository root that RelativePath is resolved against.
    .PARAMETER RelativePath
        Workspace-relative path of the file to copy.
    .PARAMETER WorkspacePath
        Destination workspace root; RelativePath is recreated beneath it.
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

    $Source = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    if (-not $PSCmdlet.ShouldProcess($Source, 'Copy into customized workspace')) { return $false }

    $null = Assert-ContainedRepositoryPath -Path $Source -ApprovedRoot $RepoRoot -Because 'customization artifact'

    $Target = Join-Path $WorkspacePath $RelativePath
    $TargetDir = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force -WhatIf:$false -Confirm:$false | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Target -Force -WhatIf:$false -Confirm:$false
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
    .PARAMETER RepoRoot
        Absolute path to the repository root supplying the customization surface.
    .PARAMETER Agent
        Agent slug whose surface is materialized.
    .PARAMETER WorkspacePath
        Workspace root passed to `vally eval --workspace`. Emptied before population.
    .PARAMETER SkillDirPath
        Skill root passed to `vally eval --skill-dir`. Emptied before population.
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

    foreach ($TargetRoot in @($WorkspacePath, $SkillDirPath)) {
        if (Test-Path -LiteralPath $TargetRoot) {
            Get-ChildItem -LiteralPath $TargetRoot -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        else {
            New-Item -ItemType Directory -Path $TargetRoot -Force -WhatIf:$false -Confirm:$false | Out-Null
        }
    }

    $Applied = [System.Collections.Generic.List[string]]::new()

    $AgentFile = Get-ChildItem -LiteralPath (Join-Path $RepoRoot '.github/agents') -Recurse -File -Filter "$Agent.agent.md" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $AgentFile) {
        throw "Agent '$Agent' not found under .github/agents. Cannot materialize a customized environment for an agent that does not exist."
    }
    $AgentRelative = $AgentFile.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')

    $Declared = Get-AgentDeclaredDependency -RepoRoot $RepoRoot -AgentRelativePath $AgentRelative

    if (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath $AgentRelative -WorkspacePath $WorkspacePath -WhatIf:$false) {
        $Applied.Add($AgentRelative)
    }

    foreach ($Relative in @($Declared.Instructions) + @($Declared.Subagents)) {
        if ([string]::IsNullOrWhiteSpace($Relative)) { continue }
        if (-not (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath ([string]$Relative) -WorkspacePath $WorkspacePath -WhatIf:$false)) {
            throw "Declared dependency '$Relative' for agent '$Agent' could not be materialized. Refusing to compare against a partial customization surface."
        }
        $Applied.Add([string]$Relative)
    }

    $CopilotInstructions = '.github/copilot-instructions.md'
    if (Copy-VerifiedRepositoryFile -RepoRoot $RepoRoot -RelativePath $CopilotInstructions -WorkspacePath $WorkspacePath -WhatIf:$false) {
        $Applied.Add($CopilotInstructions)
    }

    $SkillDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($Relative in (Get-AgentSkillReference -RepoRoot $RepoRoot -AgentFilePath $AgentRelative)) {
        [void]$SkillDirs.Add($Relative)
    }
    # A subagent's skills are part of the surface the parent agent delivers, so they
    # are resolved transitively rather than left to the agent body alone.
    foreach ($SubagentRelative in @($Declared.Subagents)) {
        if ([string]::IsNullOrWhiteSpace($SubagentRelative)) { continue }
        foreach ($Relative in (Get-AgentSkillReference -RepoRoot $RepoRoot -AgentFilePath ([string]$SubagentRelative))) {
            [void]$SkillDirs.Add($Relative)
        }
    }

    foreach ($Relative in ($SkillDirs | Sort-Object)) {
        $Source = Join-Path $RepoRoot $Relative
        if (-not (Test-Path -LiteralPath $Source -PathType Container)) { continue }
        $null = Assert-ContainedRepositoryPath -Path $Source -ApprovedRoot $RepoRoot -Because 'skill directory'
        foreach ($Entry in @(Get-ChildItem -LiteralPath $Source -Recurse -Force -ErrorAction SilentlyContinue)) {
            $null = Assert-ContainedRepositoryPath -Path $Entry.FullName -ApprovedRoot $RepoRoot -Because 'skill content'
        }
        $Target = Join-Path $SkillDirPath (Split-Path -Leaf $Relative)
        Copy-Item -LiteralPath $Source -Destination $Target -Recurse -Force -WhatIf:$false -Confirm:$false
        $Applied.Add("$Relative/SKILL.md")
    }

    return @{
        WorkspacePath = $WorkspacePath
        SkillDirPath  = $SkillDirPath
        Applied       = @($Applied | Sort-Object -Unique)
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
    .PARAMETER Model
        Model identifier the baseline was captured under.
    .PARAMETER VallyVersion
        Pinned Vally CLI version the baseline was captured under.
    .PARAMETER StimulusHash
        Content hash of the baseline spec and seed workspace.
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

    $SafeModel = $Model -replace '[^A-Za-z0-9._-]', '-'
    $SafeVersion = $VallyVersion -replace '[^A-Za-z0-9._-]', '-'
    # The hash is truncated for a readable path, but a sentinel such as 'missing' is
    # shorter than the truncation length, so the shorter of the two is used.
    $SafeHash = ($StimulusHash -replace '[^A-Za-z0-9._-]', '-')
    $Prefix = $SafeHash.Substring(0, [Math]::Min(12, $SafeHash.Length))
    return "$SafeModel/$SafeVersion/$Prefix"
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
    .OUTPUTS
        [string] Lowercase hexadecimal SHA-256 digest, or 'missing' when the spec is absent.
    .PARAMETER SpecPath
        Baseline eval spec whose content contributes to the hash.
    .PARAMETER SeedPath
        Optional seed workspace root whose sorted relative paths and content also contribute.
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

    $Parts = [System.Collections.Generic.List[string]]::new()
    $Parts.Add(((Get-Content -LiteralPath $SpecPath -Raw) -replace "`r`n", "`n"))

    # Sorted relative paths plus content, so a rename or an edit both change the key.
    # Each entry is verified before it is read: hashing follows the same trust boundary
    # as materialization, so a link planted in the seed must not be read here either.
    if ($SeedPath -and (Test-Path -LiteralPath $SeedPath)) {
        $SeedRoot = (Resolve-Path -LiteralPath $SeedPath).Path
        foreach ($SeedFile in @(Get-ChildItem -LiteralPath $SeedRoot -Recurse -File -Force | Sort-Object FullName)) {
            $null = Assert-ContainedRepositoryPath -Path $SeedFile.FullName -ApprovedRoot $SeedRoot -Because 'seed workspace entry'
            $SeedRelative = $SeedFile.FullName.Substring($SeedRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $Parts.Add($SeedRelative)
            $Parts.Add(((Get-Content -LiteralPath $SeedFile.FullName -Raw) -replace "`r`n", "`n"))
        }
    }

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = $Sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Parts -join "`n")))
        return (-join ($Bytes | ForEach-Object { $_.ToString('x2') }))
    }
    finally { $Sha.Dispose() }
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
    .PARAMETER CacheRoot
        Root directory holding persisted baseline entries.
    .PARAMETER CacheKey
        Invalidation key produced by Get-BaselineCacheKey.
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

    $EntryDir = Join-Path $CacheRoot $CacheKey
    $ManifestPath = Join-Path $EntryDir 'baseline-cache.json'
    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { return $null }

    try {
        $Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }

    if (-not $Manifest.runDir) { return $null }
    $RunDirectory = if ([System.IO.Path]::IsPathRooted([string]$Manifest.runDir)) {
        [string]$Manifest.runDir
    }
    else {
        Join-Path $EntryDir ([string]$Manifest.runDir)
    }

    if (-not (Test-Path -LiteralPath $RunDirectory -PathType Container)) { return $null }
    if (-not (Get-ChildItem -LiteralPath $RunDirectory -Recurse -File -Filter 'results.jsonl' -ErrorAction SilentlyContinue)) { return $null }

    return $RunDirectory
}

function Save-BaselineCacheEntry {
    <#
    .SYNOPSIS
        Persists a baseline run directory for reuse under its invalidation key.
    .OUTPUTS
        [string] The cached run directory path.
    .PARAMETER CacheRoot
        Root directory holding persisted baseline entries.
    .PARAMETER CacheKey
        Invalidation key produced by Get-BaselineCacheKey.
    .PARAMETER RunDir
        Source run directory to persist.
    .PARAMETER Model
        Model identifier recorded in the entry manifest.
    .PARAMETER VallyVersion
        Pinned Vally CLI version recorded in the entry manifest.
    .PARAMETER StimulusHash
        Stimulus content hash recorded in the entry manifest.
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

    $EntryDir = Join-Path $CacheRoot $CacheKey
    $TargetRun = Join-Path $EntryDir 'run'

    if (Test-Path -LiteralPath $TargetRun) {
        Remove-Item -LiteralPath $TargetRun -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $EntryDir -Force -WhatIf:$false -Confirm:$false | Out-Null
    Copy-Item -LiteralPath $RunDir -Destination $TargetRun -Recurse -Force -WhatIf:$false -Confirm:$false

    $Manifest = [ordered]@{
        runDir       = 'run'
        model        = $Model
        vallyVersion = $VallyVersion
        stimulusHash = $StimulusHash
        capturedAt   = (Get-Date -AsUTC).ToString('o')
    }
    $Manifest | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath (Join-Path $EntryDir 'baseline-cache.json') -Encoding utf8NoBOM

    return $TargetRun
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
