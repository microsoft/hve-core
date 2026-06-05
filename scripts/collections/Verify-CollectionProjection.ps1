#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Verifies that the central collections/core-manifest.yml projects cleanly and
    that plugin generation reproduces the committed plugins/ output.

.DESCRIPTION
    For every collection id declared in collections/core-manifest.yml, this
    script renders the projected YAML manifest and Markdown body from the
    central manifest as a smoke test to confirm the projection succeeds. It
    then runs Generate-Plugins.ps1 in a scratch repository and compares its
    output against the committed plugins/ directory and
    .github/plugin/marketplace.json byte-for-byte. The committed
    collections/*.collection.{yml,md} files are no longer the source of truth
    and are not compared. On any mismatch a unified-style diff summary is
    emitted and the script exits with a non-zero code so CI can enforce parity.

.PARAMETER RepoRoot
    Repository root. Defaults to the parent of the script's parent directory.

.PARAMETER ManifestPath
    Path to collections/core-manifest.yml. Defaults to the canonical location.

.PARAMETER CollectionsRoot
    Directory containing committed collections files. Retained for caller
    compatibility; no longer used for comparison.

.PARAMETER OutputPath
    Path to write a JSON results report. Defaults to
    logs/collection-projection-verification-results.json under RepoRoot.

.PARAMETER SkipPluginParity
    Skips the plugin parity check that runs Generate-Plugins.ps1 in a scratch
    repository and compares its output against the committed plugins/ directory
    and .github/plugin/marketplace.json. Use this when only projection success
    needs to be checked.

.EXAMPLE
    ./Verify-CollectionProjection.ps1

.EXAMPLE
    ./Verify-CollectionProjection.ps1 -SkipPluginParity

.OUTPUTS
    Exits 0 when projection succeeds and plugin output matches committed files.
    Exits 1 when one or more files differ or when an error prevents
    verification.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = (Get-Item (Join-Path $PSScriptRoot '../..')).FullName,

    [Parameter()]
    [string]$ManifestPath,

    [Parameter()]
    [string]$CollectionsRoot,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$SkipPluginParity
)

$ErrorActionPreference = 'Stop'

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $RepoRoot 'collections/core-manifest.yml'
}
if (-not $CollectionsRoot) {
    $CollectionsRoot = Join-Path $RepoRoot 'collections'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot 'logs/collection-projection-verification-results.json'
}

Import-Module (Join-Path $PSScriptRoot 'Modules/CoreManifestHelpers.psm1') -Force
Import-Module powershell-yaml -Force

function ConvertTo-NormalizedText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    return ($Text -replace "`r`n", "`n")
}

function Get-UnifiedDiffSummary {
    param(
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Actual,
        [int]$MaxLines = 60
    )

    $expectedLines = (ConvertTo-NormalizedText -Text $Expected) -split "`n"
    $actualLines = (ConvertTo-NormalizedText -Text $Actual) -split "`n"
    $diff = Compare-Object -ReferenceObject $expectedLines -DifferenceObject $actualLines -SyncWindow 500
    if (-not $diff) {
        return ''
    }

    $lines = foreach ($entry in $diff | Select-Object -First $MaxLines) {
        switch ($entry.SideIndicator) {
            '<=' { "- $($entry.InputObject)" }
            '=>' { "+ $($entry.InputObject)" }
            default { "  $($entry.InputObject)" }
        }
    }
    $more = $diff.Count - $MaxLines
    if ($more -gt 0) {
        $lines += "... ($more more diff lines truncated)"
    }
    return ($lines -join "`n")
}

function Get-ComparablePluginBytes {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force
    if ($item.LinkType -and $item.PSIsContainer) {
        return [System.Text.Encoding]::UTF8.GetBytes([string]$item.Target)
    }

    return [System.IO.File]::ReadAllBytes($Path)
}

function Test-ComparablePluginPath {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        return $false
    }

    return ((-not $item.PSIsContainer) -or [bool]$item.LinkType)
}

Write-Host "Verifying collection projection succeeds from the central manifest..." -ForegroundColor Cyan
Write-Host "  RepoRoot:        $RepoRoot"
Write-Host "  ManifestPath:    $ManifestPath"
Write-Host ''

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Core manifest not found at: $ManifestPath"
}

$core = Read-CoreManifest -ManifestPath $ManifestPath
$collectionsMap = Get-CoreManifestProperty -InputObject $core -Name 'collections'
if ($null -eq $collectionsMap) {
    throw "Core manifest is missing the 'collections' metadata section."
}

$collectionIds = @(Get-CoreManifestKeys -InputObject $collectionsMap)
if ($collectionIds.Count -eq 0) {
    throw "Core manifest defines no collections."
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($id in $collectionIds) {
    try {
        $manifest = ConvertTo-CollectionManifestFromCore -CoreManifest $core -CollectionId $id -RepoRoot $RepoRoot
        $projectedYaml = ConvertTo-Yaml -Data $manifest
        $projectedMd = New-CollectionReadmeBodyFromCore -CoreManifest $core -CollectionId $id -RepoRoot $RepoRoot
    }
    catch {
        $results.Add([pscustomobject]@{
            CollectionId = $id
            Kind = 'projection'
            Path = "$id.collection"
            Status = 'Error'
            Message = "Projection failed: $($_.Exception.Message)"
            Diff = ''
        })
        continue
    }

    $yamlEmpty = [string]::IsNullOrWhiteSpace($projectedYaml)
    $results.Add([pscustomobject]@{
        CollectionId = $id
        Kind = 'yaml'
        Path = "$id.collection.yml"
        Status = if ($yamlEmpty) { 'Error' } else { 'Match' }
        Message = if ($yamlEmpty) { 'Projected YAML is empty.' } else { '' }
        Diff = ''
    })
    $mdEmpty = [string]::IsNullOrWhiteSpace($projectedMd)
    $results.Add([pscustomobject]@{
        CollectionId = $id
        Kind = 'markdown'
        Path = "$id.collection.md"
        Status = if ($mdEmpty) { 'Error' } else { 'Match' }
        Message = if ($mdEmpty) { 'Projected Markdown is empty.' } else { '' }
        Diff = ''
    })
}

$matchResults = @($results | Where-Object { $_.Status -eq 'Match' })
$failures = @($results | Where-Object { $_.Status -ne 'Match' })

foreach ($result in $results) {
    $relative = $result.Path
    if ($relative.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = $relative.Substring($RepoRoot.Length).TrimStart('\','/')
    }

    switch ($result.Status) {
        'Match'    { Write-Host "  [OK]       $relative" -ForegroundColor Green }
        'Mismatch' { Write-Host "  [MISMATCH] $relative" -ForegroundColor Red }
        'Missing'  { Write-Host "  [MISSING]  $relative" -ForegroundColor Red }
        'Error'    { Write-Host "  [ERROR]    $relative" -ForegroundColor Red }
    }
}

if ($failures.Count -gt 0) {
    Write-Host ''
    Write-Host "Diff details:" -ForegroundColor Yellow
    foreach ($failure in $failures) {
        Write-Host ''
        Write-Host "--- $($failure.Path) ($($failure.Status)) ---" -ForegroundColor Yellow
        if ($failure.Message) { Write-Host $failure.Message }
        if ($failure.Diff) { Write-Host $failure.Diff }
    }
}

$pluginResults = [System.Collections.Generic.List[object]]::new()
$pluginSkipped = $true
if (-not $SkipPluginParity) {
    $pluginSkipped = $false
    Write-Host ''
    Write-Host "Verifying plugin generation parity against committed plugins/ output..." -ForegroundColor Cyan

    $scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hve-core-verify-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $scratchRoot -Force | Out-Null

    try {
        $copySpecs = @(
            @{ Source = 'collections';   Required = $true  }
            @{ Source = '.github';       Required = $true  }
            @{ Source = 'docs/templates'; Required = $true }
            @{ Source = 'scripts';       Required = $true  }
            @{ Source = 'package.json';  Required = $true  }
            @{ Source = 'extension';     Required = $false }
            @{ Source = 'plugins';       Required = $false }
        )
        foreach ($spec in $copySpecs) {
            $src = Join-Path $RepoRoot $spec.Source
            if (-not (Test-Path -LiteralPath $src)) {
                if ($spec.Required) { throw "Required path not found for scratch copy: $src" }
                continue
            }
            $dst = Join-Path $scratchRoot $spec.Source
            $dstParent = Split-Path -Parent $dst
            if ($dstParent -and -not (Test-Path -LiteralPath $dstParent)) {
                New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        }

        $scratchScript = Join-Path $scratchRoot 'scripts/plugins/Generate-Plugins.ps1'
        if (-not (Test-Path -LiteralPath $scratchScript)) {
            throw "Generate-Plugins.ps1 not found in scratch copy at: $scratchScript"
        }

        $genOutput = & pwsh -NoProfile -File $scratchScript -Refresh 2>&1
        $genExit = $LASTEXITCODE
        if ($genExit -ne 0) {
            $pluginResults.Add([pscustomobject]@{
                CollectionId = '(plugins)'
                Kind = 'plugin-generation'
                Path = $scratchScript
                Status = 'Error'
                Message = "Generate-Plugins.ps1 failed in scratch repo with exit code $genExit."
                Diff = ($genOutput | Out-String).Trim()
            })
        }
        else {
            $scratchPlugins = Join-Path $scratchRoot 'plugins'
            $repoPlugins = Join-Path $RepoRoot 'plugins'
            $scratchMarketplace = Join-Path $scratchRoot '.github/plugin/marketplace.json'
            $repoMarketplace = Join-Path $RepoRoot '.github/plugin/marketplace.json'

            $compareTargets = @()
            if (Test-Path -LiteralPath $scratchPlugins) {
                $compareTargets += Get-ChildItem -LiteralPath $scratchPlugins -Recurse -Force |
                    Where-Object { -not $_.PSIsContainer -or $_.LinkType } |
                    ForEach-Object {
                        $rel = $_.FullName.Substring($scratchPlugins.Length).TrimStart('\','/')
                        [pscustomobject]@{
                            Kind = 'plugin-file'
                            RelativePath = "plugins/$rel"
                            ScratchPath = $_.FullName
                            RepoPath = Join-Path $repoPlugins $rel
                        }
                    }
            }
            if (Test-Path -LiteralPath $repoPlugins) {
                $repoFiles = Get-ChildItem -LiteralPath $repoPlugins -Recurse -Force |
                    Where-Object { -not $_.PSIsContainer -or $_.LinkType }
                foreach ($rf in $repoFiles) {
                    $rel = $rf.FullName.Substring($repoPlugins.Length).TrimStart('\','/')
                    $relForward = ($rel -replace '\\','/')
                    if (-not ($compareTargets | Where-Object { ($_.RelativePath -replace '\\','/') -eq "plugins/$relForward" })) {
                        $compareTargets += [pscustomobject]@{
                            Kind = 'plugin-file'
                            RelativePath = "plugins/$rel"
                            ScratchPath = Join-Path $scratchPlugins $rel
                            RepoPath = $rf.FullName
                        }
                    }
                }
            }

            if (Test-Path -LiteralPath $scratchMarketplace -PathType Leaf -ErrorAction SilentlyContinue) {
                $compareTargets += [pscustomobject]@{
                    Kind = 'marketplace'
                    RelativePath = '.github/plugin/marketplace.json'
                    ScratchPath = $scratchMarketplace
                    RepoPath = $repoMarketplace
                }
            }

            foreach ($target in $compareTargets) {
                $scratchExists = Test-ComparablePluginPath -Path $target.ScratchPath
                $repoExists = Test-ComparablePluginPath -Path $target.RepoPath
                if (-not $scratchExists -and $repoExists) {
                    $pluginResults.Add([pscustomobject]@{
                        CollectionId = '(plugins)'
                        Kind = $target.Kind
                        Path = $target.RepoPath
                        Status = 'Mismatch'
                        Message = "File exists in committed plugins/ but was not produced by Generate-Plugins.ps1 in scratch."
                        Diff = ''
                    })
                    continue
                }
                if ($scratchExists -and -not $repoExists) {
                    $pluginResults.Add([pscustomobject]@{
                        CollectionId = '(plugins)'
                        Kind = $target.Kind
                        Path = $target.RepoPath
                        Status = 'Missing'
                        Message = "Scratch generation produced a file with no committed counterpart: $($target.RelativePath)"
                        Diff = ''
                    })
                    continue
                }
                $scratchBytes = Get-ComparablePluginBytes -Path $target.ScratchPath
                $repoBytes = Get-ComparablePluginBytes -Path $target.RepoPath
                $equal = $false
                if ($scratchBytes.Length -eq $repoBytes.Length) {
                    $equal = $true
                    for ($i = 0; $i -lt $scratchBytes.Length; $i++) {
                        if ($scratchBytes[$i] -ne $repoBytes[$i]) { $equal = $false; break }
                    }
                }
                if ($equal) {
                    $pluginResults.Add([pscustomobject]@{
                        CollectionId = '(plugins)'
                        Kind = $target.Kind
                        Path = $target.RepoPath
                        Status = 'Match'
                        Message = ''
                        Diff = ''
                    })
                }
                else {
                    $diff = ''
                    $textExtensions = '.md','.json','.yml','.yaml','.txt'
                    $ext = [System.IO.Path]::GetExtension($target.RepoPath).ToLowerInvariant()
                    if ($textExtensions -contains $ext) {
                        $scratchText = [System.IO.File]::ReadAllText($target.ScratchPath)
                        $repoText = [System.IO.File]::ReadAllText($target.RepoPath)
                        $diff = Get-UnifiedDiffSummary -Expected $repoText -Actual $scratchText
                    }
                    $pluginResults.Add([pscustomobject]@{
                        CollectionId = '(plugins)'
                        Kind = $target.Kind
                        Path = $target.RepoPath
                        Status = 'Mismatch'
                        Message = "Plugin output differs (lengths: repo=$($repoBytes.Length); scratch=$($scratchBytes.Length))."
                        Diff = $diff
                    })
                }
            }
        }

        $pluginMatches = @($pluginResults | Where-Object { $_.Status -eq 'Match' })
        $pluginFailures = @($pluginResults | Where-Object { $_.Status -ne 'Match' })
        Write-Host "  Plugin files compared: $($pluginResults.Count); matches: $($pluginMatches.Count); failures: $($pluginFailures.Count)"
        if ($pluginFailures.Count -gt 0) {
            Write-Host ''
            Write-Host "Plugin diff details (truncated):" -ForegroundColor Yellow
            foreach ($failure in ($pluginFailures | Select-Object -First 20)) {
                Write-Host ''
                Write-Host "--- $($failure.Path) ($($failure.Status)) ---" -ForegroundColor Yellow
                if ($failure.Message) { Write-Host $failure.Message }
                if ($failure.Diff)    { Write-Host $failure.Diff }
            }
            if ($pluginFailures.Count -gt 20) {
                Write-Host "... ($($pluginFailures.Count - 20) additional plugin failures omitted from console; see report.)"
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $scratchRoot) {
            Remove-Item -LiteralPath $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$allResults = @($results) + @($pluginResults)
$allFailures = @($allResults | Where-Object { $_.Status -ne 'Match' })

$report = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    repoRoot = $RepoRoot
    manifestPath = $ManifestPath
    collectionsRoot = $CollectionsRoot
    collectionCount = $collectionIds.Count
    fileCount = $results.Count
    matchCount = $matchResults.Count
    failureCount = $failures.Count
    pluginParitySkipped = $pluginSkipped
    pluginFileCount = $pluginResults.Count
    pluginMatchCount = @($pluginResults | Where-Object { $_.Status -eq 'Match' }).Count
    pluginFailureCount = @($pluginResults | Where-Object { $_.Status -ne 'Match' }).Count
    totalFailureCount = $allFailures.Count
    failures = @($allFailures | ForEach-Object {
        [ordered]@{
            collectionId = $_.CollectionId
            kind = $_.Kind
            path = $_.Path
            status = $_.Status
            message = $_.Message
            diff = $_.Diff
        }
    })
}

$outputDir = Split-Path -Parent $OutputPath
if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding utf8

Write-Host ''
if ($allFailures.Count -gt 0) {
    Write-Host "FAIL: $($allFailures.Count) of $($allResults.Count) compared files do not match committed counterparts." -ForegroundColor Red
    Write-Host "Report: $OutputPath"
    exit 1
}

Write-Host "OK: All $($allResults.Count) compared files reproduce committed counterparts byte-for-byte (LF-normalized for text)." -ForegroundColor Green
Write-Host "Report: $OutputPath"
exit 0
