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
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/AffectedAgents.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/EvalChangeSet.psm1') -Force

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
        [string]$RepoRoot
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
            Invoke-ChangedArtifactScan -AllTracked -RepoRoot $resolvedRepoRoot
        }
        else {
            Invoke-ChangedArtifactScan -ChangeSetPath $ChangeSetPath -RepoRoot $resolvedRepoRoot
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
