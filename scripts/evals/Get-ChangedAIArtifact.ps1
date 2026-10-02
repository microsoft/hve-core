#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Emits a JSON manifest of AI customization artifacts from a canonical change set.

.DESCRIPTION
    Reads a required immutable eval change set and classifies each entry
    as an agent / prompt / instruction / skill artifact via the
    ArtifactDetection module. Writes a manifest JSON array to `-OutFile` (default
    `logs/changed-ai-artifacts.json`) where each entry has `kind`, `path`, `artifactId`,
    `status`, and (for renames/copies) `previousPath`. Repo-root-only artifacts and nested
    package-scoped artifacts are both detected.

    Exit codes:
      0 = manifest written successfully (manifest may be empty).
      2 = input processing or manifest generation failed.

.PARAMETER ChangeSetPath
    Required canonical manifest written by Get-EvalChangeSet.ps1, relative to RepoRoot.

.PARAMETER OutFile
    Output JSON path. Defaults to `logs/changed-ai-artifacts.json` (relative to RepoRoot).

.PARAMETER RepoRoot
    Repository root. Defaults to the git toplevel or this script's parent directory.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedAIArtifact.ps1 -ChangeSetPath logs/eval-change-set.json
    Classify the frozen comparison and emit logs/changed-ai-artifacts.json.

.NOTES
    Used by the PR-time eval coverage workflow to feed Test-StimulusPresence.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ChangeSetPath = 'logs/eval-change-set.json',

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

function Invoke-ChangedArtifactScan {
    <#
    .SYNOPSIS
    Classifies canonical change records into an artifact manifest.

    .OUTPUTS
    [hashtable] `@{ baseRef; headRef; artifacts = @(...) }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ChangeSetPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    if (-not [System.IO.Path]::IsPathRooted($ChangeSetPath)) { $ChangeSetPath = Join-Path $RepoRoot $ChangeSetPath }
    $changeSet = Read-EvalChangeSet -Path $ChangeSetPath
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
        $manifest = Invoke-ChangedArtifactScan -ChangeSetPath $ChangeSetPath -RepoRoot $resolvedRepoRoot
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

    Write-Host "Detected $($manifest.artifacts.Count) changed AI artifact(s) between $($manifest.baseRef) and $($manifest.headRef)."
    Write-Host "Affected agent slugs: $($manifest.affectedAgents.Count)"
    Write-Host "Manifest: $OutFile"
    exit 0
}
