#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Emits a JSON manifest of AI customization artifacts changed between two git refs.

.DESCRIPTION
    Runs `git diff --name-status <BaseRef>...<HeadRef>` (three-dot diff to use the merge base)
    and classifies each entry as an agent / prompt / instruction / skill artifact via the
    ArtifactDetection module. Writes a manifest JSON array to `-OutFile` (default
    `logs/changed-ai-artifacts.json`) where each entry has `kind`, `path`, `artifactId`,
    `status`, and (for renames/copies) `previousPath`. Repo-root-only artifacts and nested
    collection-scoped artifacts are both detected.

    Exit codes:
      0 = manifest written successfully (manifest may be empty).
      2 = git invocation failed.

.PARAMETER BaseRef
    Base git ref for the diff. Defaults to `origin/main`.

.PARAMETER HeadRef
    Head git ref for the diff. Defaults to `HEAD`.

.PARAMETER OutFile
    Output JSON path. Defaults to `logs/changed-ai-artifacts.json` (relative to RepoRoot).

.PARAMETER RepoRoot
    Repository root. Defaults to the git toplevel or this script's parent directory.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedAIArtifact.ps1
    Diff origin/main...HEAD and emit logs/changed-ai-artifacts.json.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedAIArtifact.ps1 -BaseRef origin/main -HeadRef feature/branch
    Diff a specific branch pair.

.NOTES
    Used by the PR-time eval coverage workflow to feed Test-StimulusPresence.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseRef = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$HeadRef = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/AffectedAgents.psm1') -Force

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
    Runs git diff and classifies the results into an artifact manifest.

    .OUTPUTS
    [hashtable] `@{ baseRef; headRef; artifacts = @(...) }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseRef,

        [Parameter(Mandatory = $true)]
        [string]$HeadRef,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    Push-Location -LiteralPath $RepoRoot
    try {
        $diffOutput = & git diff --name-status "$BaseRef...$HeadRef" 2>&1
        $exit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($exit -ne 0) {
        throw "git diff failed (exit $exit): $($diffOutput -join [Environment]::NewLine)"
    }

    $lines = @($diffOutput | Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) })
    $changes = ConvertFrom-GitDiffNameStatus -Lines $lines

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
        try {
            $affectedAgents = Get-AffectedAgentSlugs -ChangedFiles $changedPaths.ToArray() -RepoRoot $RepoRoot
        }
        catch {
            Write-Warning "Failed to resolve affected agents: $($_.Exception.Message)"
            $affectedAgents = [string[]]@()
        }
    }

    return @{
        baseRef        = $BaseRef
        headRef        = $HeadRef
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
        $manifest = Invoke-ChangedArtifactScan -BaseRef $BaseRef -HeadRef $HeadRef -RepoRoot $resolvedRepoRoot
    }
    catch {
        Write-Error $_.Exception.Message
        exit 2
    }

    $outDir = Split-Path -Path $OutFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8

    Write-Host "Detected $($manifest.artifacts.Count) changed AI artifact(s) between $BaseRef and $HeadRef."
    Write-Host "Affected agent slugs: $($manifest.affectedAgents.Count)"
    Write-Host "Manifest: $OutFile"
    exit 0
}
