#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Emits a JSON manifest of AI customization artifacts from a canonical change set
    or from every tracked file.

.DESCRIPTION
    Reads a required immutable eval change set, or with -AllTracked every file
    tracked at HEAD, and classifies each entry
    as an agent / prompt / instruction / skill artifact via the
    ArtifactDetection module. Writes a manifest JSON array to `-OutFile` (default
    `logs/changed-ai-artifacts.json`) where each entry has `kind`, `path`, `artifactId`,
    `status`, and (for renames/copies) `previousPath`. Repo-root-only artifacts and nested
    package-scoped artifacts are both detected.

    With -AllTracked, every tracked file is classified as an added (`A`) record,
    `baseRef` is null, and `headRef` is the checked-out commit. Full-scope
    validation uses this mode when no verified change range exists.

    Exit codes:
      0 = manifest written successfully (manifest may be empty).
      2 = input processing or manifest generation failed.

.PARAMETER ChangeSetPath
    Required canonical manifest written by Get-EvalChangeSet.ps1, relative to RepoRoot.
    Cannot be combined with -AllTracked.

.PARAMETER AllTracked
    Classify every file tracked at HEAD instead of reading a change set.

.PARAMETER OutFile
    Output JSON path. Defaults to `logs/changed-ai-artifacts.json` (relative to RepoRoot).

.PARAMETER RepoRoot
    Repository root. Defaults to the git toplevel or this script's parent directory.

.PARAMETER EquivalenceSubject
    Agents whose baseline-equivalence surface is checked against the changed paths.
    A change inside a skill directory that the equivalence harness materializes for
    one of these agents adds the agent to `affectedAgents`, even when the dependency
    map does not record the skill. Deleted and renamed-away paths are checked against
    the surface at the comparison base. Each nonblank subject must match exactly one
    agent file, otherwise manifest generation fails. Defaults to `rpi-agent`.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedAIArtifact.ps1 -ChangeSetPath logs/eval-change-set.json
    Classify the frozen comparison and emit logs/changed-ai-artifacts.json.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedAIArtifact.ps1 -AllTracked
    Classify every tracked file for full-scope validation.

.NOTES
    Used by the PR-time eval coverage workflow to feed Test-StimulusPresence.ps1.
#>

[CmdletBinding(DefaultParameterSetName = 'ChangeSet')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'ChangeSet')]
    [string]$ChangeSetPath = 'logs/eval-change-set.json',

    [Parameter(Mandatory = $true, ParameterSetName = 'AllTracked')]
    [switch]$AllTracked,

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string[]]$EquivalenceSubject = @('rpi-agent')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/AffectedAgents.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/EvalChangeSet.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'lib/EquivalenceEnvironment.psm1') -Force

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hint)

    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        return (Resolve-Path -LiteralPath $Hint).ProviderPath
    }

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -LiteralPath $gitRoot.Trim()).ProviderPath
        }
    }
    catch {
        $null = $_
    }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
}

function Get-TrackedFileChangeSet {
    <#
    .SYNOPSIS
    Represents every file tracked at HEAD as added change records.

    .PARAMETER RepoRoot
    Repository root.

    .OUTPUTS
    [hashtable] `@{ baseRef = $null; headRef; changes = @(...) }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $headRef = & git -C $RepoRoot rev-parse --verify 'HEAD^{commit}' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($headRef)) {
        throw "Cannot resolve HEAD in '$RepoRoot'."
    }

    $trackedOutput = & git -C $RepoRoot ls-files -z 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot list tracked files in '$RepoRoot'."
    }

    $paths = @((@($trackedOutput) -join "`n") -split "`0" | Where-Object { -not [string]::IsNullOrEmpty($_) } | Sort-Object -CaseSensitive)
    $changes = foreach ($path in $paths) {
        @{ status = 'A'; path = $path; previousPath = $null }
    }

    return @{
        baseRef = $null
        headRef = ([string]$headRef).Trim()
        changes = @($changes)
    }
}

function Resolve-EquivalenceSubjectPath {
    <#
    .SYNOPSIS
    Resolves an equivalence subject slug to its single agent file.

    .DESCRIPTION
    A subject that matches no agent file, or more than one, would produce a manifest
    that looks valid while baseline equivalence is silently skipped, so both cases
    throw. A subject can be absent from a comparison base that predates it, so
    -AllowMissing returns $null for that case only. Duplicates always throw.

    .PARAMETER Root
    Repository root, or an exported comparison-base tree, to resolve against.

    .PARAMETER Slug
    Agent slug matched against `<Slug>.agent.md` beneath `.github/agents`.

    .PARAMETER AllowMissing
    Return $null instead of throwing when no agent file matches.

    .OUTPUTS
    [string] Root-relative agent path, or $null when missing and allowed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Slug,

        [switch]$AllowMissing
    )

    $AgentsRoot = Join-Path $Root '.github/agents'
    $Candidates = @(
        Get-ChildItem -LiteralPath $AgentsRoot -Recurse -File -Filter "$Slug.agent.md" -ErrorAction SilentlyContinue |
            ForEach-Object { $_.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/') } |
            Sort-Object
    )
    if ($Candidates.Count -gt 1) {
        throw "Equivalence subject '$Slug' matches $($Candidates.Count) agent files ($($Candidates -join ', ')); expected exactly one."
    }
    if ($Candidates.Count -eq 0) {
        if ($AllowMissing) { return $null }
        throw "Equivalence subject '$Slug' matches no agent file under .github/agents; expected exactly one."
    }
    return $Candidates[0]
}

function Export-ComparisonBaseSurfaceTree {
    <#
    .SYNOPSIS
    Writes the agent and skill trees of the comparison base to a scratch directory.

    .DESCRIPTION
    Deleted and renamed-away skill paths exist only at the comparison base, so their
    surface is resolved against the base tree rather than the checkout. Only
    `.github/agents` and `.github/skills` are exported, which is everything
    Get-AgentSurfaceSkill reads.

    .PARAMETER RepoRoot
    Repository root containing the commit.

    .PARAMETER Commit
    Comparison-base commit to export.

    .PARAMETER Destination
    Existing empty directory that receives the exported trees.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Commit,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $Listing = Invoke-EvalGit -RepoRoot $RepoRoot -Arguments @('ls-tree', '-z', '--name-only', $Commit, '--', '.github/agents', '.github/skills')
    $Entries = @($Listing -split "`0" | Where-Object { -not [string]::IsNullOrEmpty($_) })
    if ($Entries.Count -eq 0) { return }

    $ArchivePath = Join-Path $Destination 'comparison-base.tar'
    $null = Invoke-EvalGit -RepoRoot $RepoRoot -Arguments (@('archive', '--format=tar', "--output=$ArchivePath", $Commit, '--') + $Entries)
    [System.Formats.Tar.TarFile]::ExtractToDirectory($ArchivePath, $Destination, $true)
    Remove-Item -LiteralPath $ArchivePath -Force
}

function Get-EquivalenceSurfaceAgent {
    <#
    .SYNOPSIS
    Returns the equivalence subjects whose materialized skill surface a change touches.

    .DESCRIPTION
    The dependency map behind Get-AffectedAgentSlugs records only skills referenced
    by path. The baseline-equivalence harness also resolves skills an agent names in
    backticks, which is how the RPI agent references `rpi-research` and its peers, and
    copies those whole skill directories into the surface it measures. Checking the
    changes against the directories the harness materializes keeps the equivalence
    gate and the harness in agreement. The check covers only the equivalence
    subjects, not every agent in the dependency map.

    Paths that exist at HEAD are checked against the surface resolved from the
    checkout. Deleted paths and the previous path of a rename or copy are checked
    against the surface resolved at the comparison base, because a deleted or
    renamed-away skill no longer exists at HEAD. Every subject must resolve to
    exactly one agent file at HEAD.

    .PARAMETER Change
    Canonical change records with `status`, `path`, and `previousPath`.

    .PARAMETER Subject
    Agent slugs whose equivalence surface is checked.

    .PARAMETER RepoRoot
    Repository root.

    .PARAMETER ComparisonBase
    Commit the change records were computed from. Required when a deleted or previous
    path falls under `.github/skills`.

    .OUTPUTS
    [string[]] Subjects with at least one changed path inside their skill surface.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Change,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Subject,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [string]$ComparisonBase
    )

    $HeadPaths = [System.Collections.Generic.List[string]]::new()
    $BasePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($Record in $Change) {
        if ([string]$Record.status -eq 'D') {
            $BasePaths.Add(([string]$Record.path -replace '\\', '/').TrimStart('/'))
            continue
        }
        if ($Record.path) { $HeadPaths.Add(([string]$Record.path -replace '\\', '/').TrimStart('/')) }
        if ($Record.previousPath) { $BasePaths.Add(([string]$Record.previousPath -replace '\\', '/').TrimStart('/')) }
    }
    # The surface holds only skill directories, so base paths elsewhere can never match.
    $BaseSkillPaths = @($BasePaths | Where-Object { $_ -like '.github/skills/*' })

    $TestSurface = {
        param([string[]]$Path, [string[]]$SkillDir)

        foreach ($Candidate in $Path) {
            foreach ($Dir in $SkillDir) {
                if ($Candidate.StartsWith("$Dir/", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
            }
        }
        return $false
    }

    $Touched = [System.Collections.Generic.List[string]]::new()
    $BaseRoot = $null
    try {
        foreach ($Slug in $Subject) {
            if ([string]::IsNullOrWhiteSpace($Slug)) { continue }
            $AgentRelative = Resolve-EquivalenceSubjectPath -Root $RepoRoot -Slug $Slug
            $HeadSurface = @(Get-AgentSurfaceSkill -RepoRoot $RepoRoot -AgentRelativePath $AgentRelative)
            $IsTouched = & $TestSurface -Path $HeadPaths.ToArray() -SkillDir $HeadSurface

            if (-not $IsTouched -and $BaseSkillPaths.Count -gt 0) {
                if ($null -eq $BaseRoot) {
                    if ([string]::IsNullOrWhiteSpace($ComparisonBase)) {
                        throw 'Deleted or renamed skill paths require a comparison base to resolve the equivalence surface.'
                    }
                    $BaseRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('eval-surface-base-' + [Guid]::NewGuid().ToString('N'))
                    $null = New-Item -ItemType Directory -Path $BaseRoot -Force
                    Export-ComparisonBaseSurfaceTree -RepoRoot $RepoRoot -Commit $ComparisonBase -Destination $BaseRoot
                }
                $BaseAgent = Resolve-EquivalenceSubjectPath -Root $BaseRoot -Slug $Slug -AllowMissing
                if ($BaseAgent) {
                    $BaseSurface = @(Get-AgentSurfaceSkill -RepoRoot $BaseRoot -AgentRelativePath $BaseAgent)
                    $IsTouched = & $TestSurface -Path $BaseSkillPaths -SkillDir $BaseSurface
                }
            }

            if ($IsTouched) { $Touched.Add($Slug) }
        }
    }
    finally {
        if ($BaseRoot) { Remove-Item -LiteralPath $BaseRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    return , [string[]]$Touched.ToArray()
}

function Invoke-ChangedArtifactScan {
    <#
    .SYNOPSIS
    Classifies canonical change records into an artifact manifest.

    .PARAMETER ChangeSetPath
    Canonical change-set path, relative to RepoRoot when not rooted.

    .PARAMETER AllTracked
    Classify every file tracked at HEAD as an added record.

    .PARAMETER RepoRoot
    Repository root.

    .PARAMETER EquivalenceSubject
    Agents whose baseline-equivalence skill surface is checked against the changes.

    .OUTPUTS
    [hashtable] `@{ baseRef; headRef; artifacts = @(...) }`.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ChangeSet')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ChangeSet')]
        [string]$ChangeSetPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'AllTracked')]
        [switch]$AllTracked,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [string[]]$EquivalenceSubject = @('rpi-agent')
    )

    if ($PSCmdlet.ParameterSetName -eq 'AllTracked') {
        $changeSet = Get-TrackedFileChangeSet -RepoRoot $RepoRoot
    }
    else {
        if (-not [System.IO.Path]::IsPathRooted($ChangeSetPath)) { $ChangeSetPath = Join-Path $RepoRoot $ChangeSetPath }
        $changeSet = Read-EvalChangeSet -Path $ChangeSetPath
    }
    $changes = $changeSet.changes

    $artifacts = [System.Collections.Generic.List[hashtable]]::new()
    $changedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($change in $changes) {
        $record = Get-ChangedArtifactRecord -Change $change
        if ($null -ne $record) {
            $artifacts.Add($record)
        }
        if ($change.path) { $changedPaths.Add([string]$change.path) }
        if ($change.previousPath) { $changedPaths.Add([string]$change.previousPath) }
    }

    $affectedAgents = [string[]]@()
    if ($changedPaths.Count -gt 0) {
        $affectedAgents = Get-AffectedAgentSlugs -ChangedFiles $changedPaths.ToArray() -RepoRoot $RepoRoot
        $SurfaceAgents = Get-EquivalenceSurfaceAgent -Change @($changes) -Subject $EquivalenceSubject -RepoRoot $RepoRoot -ComparisonBase ([string]$changeSet['comparisonBase'])
        $affectedAgents = [string[]]@(@($affectedAgents) + @($SurfaceAgents) | Sort-Object -Unique)
    }

    return @{
        baseRef        = $changeSet.baseRef
        headRef        = $changeSet.headRef
        artifacts      = $artifacts.ToArray()
        affectedAgents = [string[]]$affectedAgents
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot

    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        $OutFile = Join-Path -Path $resolvedRepoRoot -ChildPath 'logs/changed-ai-artifacts.json'
    }
    elseif (-not [System.IO.Path]::IsPathRooted($OutFile)) {
        $OutFile = Join-Path -Path $resolvedRepoRoot -ChildPath $OutFile
    }

    try {
        $manifest = if ($AllTracked) {
            Invoke-ChangedArtifactScan -AllTracked -RepoRoot $resolvedRepoRoot -EquivalenceSubject $EquivalenceSubject
        }
        else {
            Invoke-ChangedArtifactScan -ChangeSetPath $ChangeSetPath -RepoRoot $resolvedRepoRoot -EquivalenceSubject $EquivalenceSubject
        }
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 2
    }

    $outDir = Split-Path -Path $OutFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8

    if ($AllTracked) {
        Write-Host "Detected $($manifest.artifacts.Count) tracked AI artifact(s) at $($manifest.headRef)."
    }
    else {
        Write-Host "Detected $($manifest.artifacts.Count) changed AI artifact(s) between $($manifest.baseRef) and $($manifest.headRef)."
    }
    Write-Host "Affected agent slugs: $($manifest.affectedAgents.Count)"
    Write-Host "Manifest: $OutFile"
    exit 0
}
