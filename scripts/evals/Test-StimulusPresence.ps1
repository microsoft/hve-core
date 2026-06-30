#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies every changed AI artifact has at least one matching eval-spec stimulus backlink.

.DESCRIPTION
    Reads a manifest JSON produced by `Get-ChangedAIArtifact.ps1`, builds a stimulus
    coverage index from `evals/**/*.yaml`, and reports artifacts that lack any matching
    `stimuli[].tags.<kind> = <slug>` backlink. Deleted artifacts (status `D`) are skipped
    because coverage cannot be retroactively required for removed files.

    The script writes a structured report (covered / missing / errors / skipped) to
    `-OutFile` (default `logs/stimulus-presence.json`) and emits one GitHub Actions
    `::error file=...::` annotation per missing artifact.

    Exit codes:
      0 = all changed artifacts are covered (or the manifest is empty / only deletions).
      1 = at least one changed artifact is missing eval coverage.
      2 = invalid input (missing manifest, missing eval root, or YAML parse errors).

.PARAMETER ManifestPath
    Path to the changed-artifact manifest. Defaults to `logs/changed-ai-artifacts.json`.

.PARAMETER EvalRoot
    Filesystem path to the eval specs root. Defaults to `evals/`.

.PARAMETER OutFile
    Output JSON report path. Defaults to `logs/stimulus-presence.json`.

.PARAMETER RepoRoot
    Repository root. Defaults to the git toplevel or this script's parent directory.

.PARAMETER FailOnSpecError
    When set, exits 2 if any eval spec fails to parse (in addition to the missing-coverage
    failure mode). Default behavior records parse errors in the report but does not fail
    solely because of them.

.PARAMETER EnforceFullCoverageKinds
    Artifact kinds (subset of skill/agent/prompt/instruction) for which coverage is enforced
    across the full repository, not just the diff manifest. Repo-root-only artifacts under
    `.github/<kind>/` (without a collection subdirectory) are excluded because they are
    repo-specific and not packaged. Defaults to `@('prompt')`.

.EXAMPLE
    pwsh -File scripts/evals/Test-StimulusPresence.ps1
    Validate the default manifest against `evals/`.

.NOTES
    Runs via the PR-time eval coverage workflow after Get-ChangedAIArtifact.ps1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$EvalRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [switch]$FailOnSpecError,

    [Parameter(Mandatory = $false)]
    [string[]]$EnforceFullCoverageKinds = @('prompt')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/StimulusIndex.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force

if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Write-Error "Test-StimulusPresence.ps1 requires the 'powershell-yaml' module."
    exit 2
}
Import-Module powershell-yaml -ErrorAction Stop

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

function Resolve-RelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return (Join-Path -Path $RepoRoot -ChildPath $Path)
}

function Get-EnforcedArtifact {
    <#
    .SYNOPSIS
    Enumerates AI artifacts on disk for kinds requiring full-repository coverage.

    .DESCRIPTION
    Returns artifact records (kind / path / artifactId) for files under `.github/<kind>/`
    excluding repo-root-only artifacts (no collection subdirectory). Repo-root-only
    artifacts are repo-specific per `.github/copilot-instructions.md` and are not packaged
    into collections, so eval coverage is not enforced for them.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Kinds
    )

    $kindMap = @{
        prompt      = @{ Dir = '.github/prompts';      Filter = '*.prompt.md';       Suffix = '.prompt' }
        agent       = @{ Dir = '.github/agents';       Filter = '*.agent.md';        Suffix = '.agent' }
        instruction = @{ Dir = '.github/instructions'; Filter = '*.instructions.md'; Suffix = '.instructions' }
    }

    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($kind in $Kinds) {
        if (-not $kindMap.ContainsKey($kind)) { continue }
        $meta = $kindMap[$kind]
        $rootDir = Join-Path -Path $RepoRoot -ChildPath $meta.Dir
        if (-not (Test-Path -LiteralPath $rootDir -PathType Container)) { continue }

        $rootDirResolved = (Resolve-Path -LiteralPath $rootDir).ProviderPath
        $files = Get-ChildItem -LiteralPath $rootDirResolved -Recurse -File -Filter $meta.Filter -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $parent = Split-Path -Path $file.FullName -Parent
            if ($parent -eq $rootDirResolved) { continue }
            $rel = ([System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName)) -replace '\\', '/'
            $slug = $file.BaseName
            if ($meta.Suffix) { $slug = $slug -replace ([regex]::Escape($meta.Suffix) + '$'), '' }
            $results.Add(@{ kind = $kind; path = $rel; artifactId = $slug; status = 'F' })
        }
    }

    return ,$results.ToArray()
}

function Invoke-StimulusPresenceCheck {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,

        [Parameter(Mandatory = $true)]
        [string]$EvalRoot,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string[]]$EnforceFullCoverageKinds = @()
    )

    if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
        throw "Manifest not found: $ManifestPath"
    }
    if (-not (Test-Path -LiteralPath $EvalRoot -PathType Container)) {
        throw "Eval root not found: $EvalRoot"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    $artifacts = @()
    if ($null -ne $manifest -and $null -ne $manifest.artifacts) {
        $artifacts = @($manifest.artifacts)
    }

    if ($EnforceFullCoverageKinds.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($RepoRoot)) {
        $seen = @{}
        foreach ($a in $artifacts) {
            $key = "$([string]$a.kind):$([string]$a.path)"
            $seen[$key] = $true
        }
        $merged = [System.Collections.Generic.List[object]]::new()
        foreach ($a in $artifacts) { $merged.Add($a) }
        foreach ($extra in (Get-EnforcedArtifact -RepoRoot $RepoRoot -Kinds $EnforceFullCoverageKinds)) {
            $key = "$($extra.kind):$($extra.path)"
            if ($seen.ContainsKey($key)) { continue }
            $merged.Add([pscustomobject]$extra)
            $seen[$key] = $true
        }
        $artifacts = $merged.ToArray()
    }

    $index = New-StimulusIndex -EvalRoot $EvalRoot

    $covered = [System.Collections.Generic.List[hashtable]]::new()
    $missing = [System.Collections.Generic.List[hashtable]]::new()
    $skipped = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($artifact in $artifacts) {
        $kind = [string]$artifact.kind
        $artifactId = [string]$artifact.artifactId
        $path = [string]$artifact.path
        $status = [string]$artifact.status

        if ($status -eq 'D') {
            $skipped.Add(@{ kind = $kind; artifactId = $artifactId; path = $path; reason = 'deleted' })
            continue
        }

        if (Test-RepoRootArtifact -Kind $kind -Path $path) {
            $skipped.Add(@{ kind = $kind; artifactId = $artifactId; path = $path; reason = 'repo-specific' })
            continue
        }

        $specs = Test-StimulusCoverage -Index $index -Kind $kind -ArtifactId $artifactId
        if ($specs.Count -gt 0) {
            $covered.Add(@{ kind = $kind; artifactId = $artifactId; path = $path; specs = $specs })
        }
        else {
            $missing.Add(@{ kind = $kind; artifactId = $artifactId; path = $path; status = $status })
        }
    }

    return @{
        manifestPath              = $ManifestPath
        evalRoot                  = $index.root
        specsScanned              = $index.specsScanned
        enforceFullCoverageKinds  = $EnforceFullCoverageKinds
        covered                   = $covered.ToArray()
        missing                   = $missing.ToArray()
        skipped                   = $skipped.ToArray()
        errors                    = $index.errors
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot

    if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
        $ManifestPath = 'logs/changed-ai-artifacts.json'
    }
    if ([string]::IsNullOrWhiteSpace($EvalRoot)) {
        $EvalRoot = 'evals'
    }
    if ([string]::IsNullOrWhiteSpace($OutFile)) {
        $OutFile = 'logs/stimulus-presence.json'
    }

    $resolvedManifest = Resolve-RelativePath -Path $ManifestPath -RepoRoot $resolvedRepoRoot
    $resolvedEvalRoot = Resolve-RelativePath -Path $EvalRoot -RepoRoot $resolvedRepoRoot
    $resolvedOutFile = Resolve-RelativePath -Path $OutFile -RepoRoot $resolvedRepoRoot

    try {
        $report = Invoke-StimulusPresenceCheck -ManifestPath $resolvedManifest -EvalRoot $resolvedEvalRoot -RepoRoot $resolvedRepoRoot -EnforceFullCoverageKinds $EnforceFullCoverageKinds
    }
    catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 2
    }

    $outDir = Split-Path -Path $resolvedOutFile -Parent
    if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resolvedOutFile -Encoding UTF8

    foreach ($entry in $report.missing) {
        $msg = "Missing eval coverage for $($entry.kind) '$($entry.artifactId)' (no stimulus declares tags.$($entry.kind) = $($entry.artifactId))"
        Write-Host "::error file=$($entry.path)::$msg"
    }

    Write-Host "Checked $($report.covered.Count + $report.missing.Count + $report.skipped.Count) changed artifact(s): $($report.covered.Count) covered, $($report.missing.Count) missing, $($report.skipped.Count) skipped."
    Write-Host "Report: $resolvedOutFile"

    if ($report.missing.Count -gt 0) {
        exit 1
    }
    if ($FailOnSpecError -and $report.errors.Count -gt 0) {
        Write-Host "Failing due to $($report.errors.Count) eval-spec parse error(s)."
        exit 2
    }

    exit 0
}
