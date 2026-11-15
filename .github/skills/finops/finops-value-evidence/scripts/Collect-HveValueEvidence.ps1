#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Collects a read-only, SHA-256-verified HVE value evidence snapshot for a Git repository.

.DESCRIPTION
    Inventories Git-tracked and non-ignored untracked files, HVE customization surfaces
    (.github/agents, .github/instructions, .github/skills, docs, tests), RPI delivery
    artifacts under .copilot-tracking/ (research, plans, changes, reviews, and review
    verdict outcomes), optional XML test results, and optional AI accounting telemetry.
    Refuses symbolic links/reparse points and inside-repository output paths so evidence
    collection never mutates the measured repository.

.PARAMETER RepoRoot
    Path to the Git repository root to inspect read-only. Defaults to current directory.

.PARAMETER OutputPath
    Destination path for the JSON evidence bundle. Must be outside RepoRoot.

.PARAMETER AccountingPath
    Optional JSON file carrying AI session/token/credit accounting records.

.PARAMETER TestReportPath
    Optional NUnit/JUnit XML test report path (relative to RepoRoot or absolute).
    Defaults to 'testResults.xml'.

.EXAMPLE
    ./Collect-HveValueEvidence.ps1 -RepoRoot . -OutputPath ../hve-evidence.json
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$AccountingPath = '',

    [Parameter(Mandatory = $false)]
    [string]$TestReportPath = 'testResults.xml'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Verifies a path and its existing ancestors contain no symbolic links or reparse points.
.PARAMETER CandidatePath
    Filesystem path to inspect.
#>
function Assert-SafeEvidencePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath
    )
    $full = [System.IO.Path]::GetFullPath($CandidatePath)
    $cursor = $full
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or $item.LinkTarget)) {
            throw "Refusing to follow reparse point or symbolic link: $CandidatePath"
        }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or $parent -eq $cursor) {
            break
        }
        $cursor = $parent
    }
    return $full
}

<#
.SYNOPSIS
    Executes a read-only git command with optional locks disabled.
.PARAMETER Repository
    Resolved repository root path.
.PARAMETER Arguments
    Git CLI arguments array.
#>
function Read-HveGitOutput {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )
    $env:GIT_OPTIONAL_LOCKS = '0'
    $result = @(& git --no-pager -C $Repository @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Git read failed: $($Arguments -join ' ')"
    }
    return $result
}

<#
.SYNOPSIS
    Summarizes RPI delivery artifacts and independent review verdicts under .copilot-tracking/.
.PARAMETER Repository
    Resolved repository root path.
#>
function Get-RpiDeliveryEvidence {
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository
    )
    $trackingRoot = Join-Path $Repository '.copilot-tracking'
    if (-not (Test-Path -LiteralPath $trackingRoot -PathType Container)) {
        return [ordered]@{
            present              = $false
            researchArtifacts    = 0
            planArtifacts        = 0
            changeArtifacts      = 0
            reviewArtifacts      = 0
            acceptedReviews      = 0
            rejectedReviews      = 0
            deliverablesProduced = 0
        }
    }
    $null = Assert-SafeEvidencePath -CandidatePath $trackingRoot
    $files = @(Get-ChildItem -LiteralPath $trackingRoot -Recurse -File -Force | Where-Object {
            -not (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or $_.LinkTarget)
        })

    $research = @($files | Where-Object { ($_.FullName -replace '\\', '/') -match '/research/' -and $_.Extension -eq '.md' })
    $plans = @($files | Where-Object { ($_.FullName -replace '\\', '/') -match '/plans/' -and $_.Extension -eq '.md' })
    $changes = @($files | Where-Object { ($_.FullName -replace '\\', '/') -match '/changes/' -and $_.Extension -eq '.md' })
    $reviews = @($files | Where-Object { ($_.FullName -replace '\\', '/') -match '/reviews/' -and $_.Extension -eq '.md' })

    $accepted = 0
    $rejected = 0
    foreach ($rev in $reviews) {
        $text = [System.IO.File]::ReadAllText($rev.FullName)
        if ($text -match '(?im)^(?:#+\s*)?Verdict:\s*(?:Pass|Pass-With-Findings|Approved)\b') {
            $accepted++
        }
        elseif ($text -match '(?im)^(?:#+\s*)?Verdict:\s*(?:Fail|Rejected|Blocked)\b') {
            $rejected++
        }
    }

    return [ordered]@{
        present              = $true
        researchArtifacts    = $research.Count
        planArtifacts        = $plans.Count
        changeArtifacts      = $changes.Count
        reviewArtifacts      = $reviews.Count
        acceptedReviews      = $accepted
        rejectedReviews      = $rejected
        deliverablesProduced = $changes.Count
    }
}

$resolvedRepo = Assert-SafeEvidencePath -CandidatePath (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
$resolvedOut = Assert-SafeEvidencePath -CandidatePath $OutputPath
$comparison = if ($IsWindows) { [System.StringComparison]::OrdinalIgnoreCase } else { [System.StringComparison]::Ordinal }
$repoPrefix = $resolvedRepo.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if ($resolvedOut.Equals($resolvedRepo.TrimEnd('\', '/'), $comparison) -or $resolvedOut.StartsWith($repoPrefix, $comparison)) {
    throw 'Collection OutputPath must be outside RepoRoot so evidence collection remains read-only.'
}

$startedUtc = [DateTime]::UtcNow.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
$statusBefore = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('status', '--porcelain=v1', '--untracked-files=all'))
$tracked = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('ls-files', '--cached'))
$untracked = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('ls-files', '--others', '--exclude-standard'))

$manifest = @(
    foreach ($relative in @($tracked + $untracked | Sort-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }
        $leafPath = Join-Path $resolvedRepo $relative
        if (-not (Test-Path -LiteralPath $leafPath -PathType Leaf)) {
            [pscustomobject][ordered]@{
                path    = $relative
                present = $false
                bytes   = $null
                sha256  = $null
            }
            continue
        }
        $item = Get-Item -LiteralPath $leafPath -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or $item.LinkTarget) {
            throw "Refusing to follow reparse point: $relative"
        }
        [pscustomobject][ordered]@{
            path    = $relative
            present = $true
            bytes   = [int64]$item.Length
            sha256  = (Get-FileHash -LiteralPath $leafPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    }
)

$categoryPrefixes = [ordered]@{
    agents       = '.github/agents/'
    instructions = '.github/instructions/'
    skills       = '.github/skills/'
    docs         = 'docs/'
    tests        = 'tests/'
}
$categories = [ordered]@{}
foreach ($catName in $categoryPrefixes.Keys) {
    $prefix = $categoryPrefixes[$catName]
    $matched = @($manifest | Where-Object { $_.present -and ($_.path -replace '\\', '/').StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
    $byteSum = [int64]0
    foreach ($entry in $matched) {
        $byteSum += [int64]$entry.bytes
    }
    $categories[$catName] = [ordered]@{
        files = $matched.Count
        bytes = $byteSum
    }
}

$rpiEvidence = Get-RpiDeliveryEvidence -Repository $resolvedRepo

$accountingSummary = $null
if (-not [string]::IsNullOrWhiteSpace($AccountingPath)) {
    $accCandidate = if ([System.IO.Path]::IsPathRooted($AccountingPath)) { $AccountingPath } else { Join-Path $resolvedRepo $AccountingPath }
    if (Test-Path -LiteralPath $accCandidate -PathType Leaf) {
        $safeAcc = Assert-SafeEvidencePath -CandidatePath $accCandidate
        $acc = Get-Content -LiteralPath $safeAcc -Raw | ConvertFrom-Json
        $knownUnits = if ($acc.PSObject.Properties['knownProviderUnits']) { [double]$acc.knownProviderUnits } else { $null }
        $costUsd = if ($acc.PSObject.Properties['costUsd']) {
            [double]$acc.costUsd
        }
        elseif ($null -ne $knownUnits) {
            [Math]::Round(($knownUnits * 0.01), 4)
        }
        else {
            $null
        }
        $baselineUsd = if ($acc.PSObject.Properties['counterfactualBaselineUsd']) { [double]$acc.counterfactualBaselineUsd } else { $null }
        $accountingSummary = [ordered]@{
            sessions                  = $(if ($acc.PSObject.Properties['sessions']) { [int]$acc.sessions } else { $null })
            calls                     = $(if ($acc.PSObject.Properties['calls']) { [int]$acc.calls } else { $null })
            knownProviderUnits        = $knownUnits
            costUsd                   = $costUsd
            counterfactualBaselineUsd = $baselineUsd
            basis                     = $(if ($acc.PSObject.Properties['basis']) { [string]$acc.basis } else { 'measured' })
        }
    }
}

$testXmlSummary = $null
if (-not [string]::IsNullOrWhiteSpace($TestReportPath)) {
    $xmlCandidate = if ([System.IO.Path]::IsPathRooted($TestReportPath)) { $TestReportPath } else { Join-Path $resolvedRepo $TestReportPath }
    if (Test-Path -LiteralPath $xmlCandidate -PathType Leaf) {
        $safeXml = Assert-SafeEvidencePath -CandidatePath $xmlCandidate
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [System.Xml.XmlReader]::Create($safeXml, $settings)
        try {
            $doc = [System.Xml.XmlDocument]::new()
            $doc.XmlResolver = $null
            $doc.Load($reader)
            $attrs = [ordered]@{}
            foreach ($attr in $doc.DocumentElement.Attributes) {
                if ($attr.Name -in @('total', 'passed', 'failed', 'errors', 'failures', 'skipped', 'result', 'duration', 'testcasecount')) {
                    $attrs[$attr.Name] = $attr.Value
                }
            }
            $testXmlSummary = [ordered]@{
                root         = $doc.DocumentElement.Name
                attributes   = $attrs
                lastWriteUtc = (Get-Item -LiteralPath $safeXml).LastWriteTimeUtc.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
            }
        }
        finally {
            $reader.Dispose()
        }
    }
}

$statusAfter = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('status', '--porcelain=v1', '--untracked-files=all'))
$manifestText = ($manifest | ForEach-Object { "$($_.path)`t$($_.bytes)`t$($_.sha256)" }) -join "`n"
$manifestSha = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($manifestText))).ToLowerInvariant()

$headSha = ''
try {
    $headSha = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('rev-parse', 'HEAD'))[0]
}
catch {
    $headSha = 'unborn'
}
$branchName = @(Read-HveGitOutput -Repository $resolvedRepo -Arguments @('branch', '--show-current'))
$branchValue = if ($branchName.Count -gt 0) { $branchName[0] } else { '' }

$snapshot = [ordered]@{
    schemaVersion                = '1.0'
    collectionStartedUtc         = $startedUtc
    collectionFinishedUtc        = [DateTime]::UtcNow.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    head                         = $headSha
    branch                       = $branchValue
    powerShellVersion            = $PSVersionTable.PSVersion.ToString()
    trackedPaths                 = $tracked.Count
    untrackedNonignoredPaths     = $untracked.Count
    statusStableDuringCollection = (($statusBefore -join "`n") -ceq ($statusAfter -join "`n"))
    fileManifestSha256           = $manifestSha
    categories                   = $categories
    rpiDelivery                  = $rpiEvidence
    accounting                   = $accountingSummary
    testReport                   = $testXmlSummary
    fileManifest                 = $manifest
}

$outParent = Split-Path -Parent $resolvedOut
if ($outParent -and -not (Test-Path -LiteralPath $outParent -PathType Container)) {
    New-Item -ItemType Directory -Path $outParent -Force | Out-Null
}
$jsonOut = ($snapshot | ConvertTo-Json -Depth 12) + "`n"
[System.IO.File]::WriteAllText($resolvedOut, $jsonOut, [System.Text.UTF8Encoding]::new($false))

$summaryProjection = [pscustomobject]$snapshot | Select-Object schemaVersion, collectionStartedUtc, collectionFinishedUtc, head, branch, trackedPaths, untrackedNonignoredPaths, statusStableDuringCollection, fileManifestSha256, categories, rpiDelivery, accounting, testReport
return ($summaryProjection | ConvertTo-Json -Depth 8)
