#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates that every instruction and prompt artifact is referenced in its hub README.

.DESCRIPTION
    Checks two documentation hub indexes against the artifacts on disk:
      - .github/instructions/README.md  <- .github/instructions/**/*.instructions.md
      - .github/prompts/README.md       <- .github/prompts/**/*.prompt.md

    The prompts hub excludes dt-method-* per-method coaching prompts, which are
    summarized in a note rather than linked individually.

    Matching is filename-substring based and case-insensitive. Supports
    -ChangedFilesOnly for PR-scoped validation. Exports JSON results and writes
    GitHub Actions annotations + step summary via shared CI helpers.

.PARAMETER RepoRoot
    Repository root to scan. Defaults to the current directory.

.PARAMETER ChangedFilesOnly
    Only check artifacts changed relative to -BaseBranch.

.PARAMETER BaseBranch
    Base branch for changed-file detection. Defaults to origin/main.

.PARAMETER OutputPath
    JSON results output path. Defaults to logs/doc-hub-completeness-results.json.

.EXAMPLE
    ./Test-DocHubCompleteness.ps1 -RepoRoot .
.EXAMPLE
    ./Test-DocHubCompleteness.ps1 -ChangedFilesOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/doc-hub-completeness-results.json'
)

Set-StrictMode -Version Latest
 $ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "Modules/LintingHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Functions

function Get-HubArtifact {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HubDefinition
    )

    $absoluteArtifactRoot = Join-Path $RepoRoot $HubDefinition.ArtifactRoot
    $artifacts = [System.Collections.Generic.List[pscustomobject]]::new()

    if (-not (Test-Path -Path $absoluteArtifactRoot -PathType Container)) {
        return $artifacts
    }

    $files = Get-ChildItem -Path $absoluteArtifactRoot -Recurse -File -Filter $HubDefinition.ArtifactFilter

    foreach ($file in $files) {
        if ($null -ne $HubDefinition.ExcludePattern -and $file.Name -like $HubDefinition.ExcludePattern) {
            continue
        }

        $relativePath = $file.FullName.Substring($RepoRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $artifacts.Add([pscustomobject]@{
            Name         = $file.Name
            RelativePath = $relativePath
        })
    }

    return $artifacts
}

function Test-HubCompleteness {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$HubDefinition,

        [Parameter(Mandatory = $false)]
        [string[]]$ChangedFiles = @()
    )

    $absoluteReadme = Join-Path $RepoRoot $HubDefinition.ReadmePath
    $absoluteArtifactRoot = Join-Path $RepoRoot $HubDefinition.ArtifactRoot

    if (-not (Test-Path -Path $absoluteArtifactRoot -PathType Container)) {
        return @{
            Hub           = $HubDefinition.Name
            Missing       = @()
            Duplicates    = @()
            ExcludedCount = 0
            TotalChecked  = 0
            ReadmeMissing = $false
            Issue         = $null
        }
    }

    if (-not (Test-Path -Path $absoluteReadme -PathType Leaf)) {
        return @{
            Hub           = $HubDefinition.Name
            Missing       = @()
            Duplicates    = @()
            ExcludedCount = 0
            TotalChecked  = 0
            ReadmeMissing = $true
            Issue         = "[$($HubDefinition.Name)] Hub README not found: $($HubDefinition.ReadmePath)"
        }
    }

    $excludedCount = 0
    $allFiles = Get-ChildItem -Path $absoluteArtifactRoot -Recurse -File -Filter $HubDefinition.ArtifactFilter
    foreach ($file in $allFiles) {
        if ($null -ne $HubDefinition.ExcludePattern -and $file.Name -like $HubDefinition.ExcludePattern) {
            $excludedCount++
        }
    }

    $checkedArtifacts = @(Get-HubArtifact -RepoRoot $RepoRoot -HubDefinition $HubDefinition)

    if ($ChangedFiles.Count -gt 0) {
        $checkedArtifacts = @($checkedArtifacts | Where-Object { $ChangedFiles -contains $_.RelativePath })
    }

    $readmeContent = (Get-Content -LiteralPath $absoluteReadme -Raw) ?? [string]::Empty

    $duplicates = [System.Collections.Generic.List[object]]::new()
    $dupeGroups = $checkedArtifacts |
        Group-Object -Property Name |
        Where-Object { $_.Count -gt 1 }

    foreach ($dupe in $dupeGroups) {
        $duplicates.Add([pscustomobject]@{
            Hub      = $HubDefinition.Name
            FileName = $dupe.Name
            Paths    = @($dupe.Group | ForEach-Object { $_.RelativePath })
        })
    }

    $missing = [System.Collections.Generic.List[object]]::new()
    foreach ($checked in $checkedArtifacts) {
        if ($readmeContent.IndexOf($checked.Name, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            $missing.Add([pscustomobject]@{
                Hub          = $HubDefinition.Name
                FileName     = $checked.Name
                RelativePath = $checked.RelativePath
                ReadmePath   = $HubDefinition.ReadmePath
            })
        }
    }

    return @{
        Hub           = $HubDefinition.Name
        Missing       = @($missing)
        Duplicates    = @($duplicates)
        ExcludedCount = $excludedCount
        TotalChecked  = $checkedArtifacts.Count
        ReadmeMissing = $false
        Issue         = $null
    }
}

function Test-DocHubCompleteness {
    <#
    .SYNOPSIS
        Validates both hubs and returns an aggregate result (no side effects).

    .DESCRIPTION
        Dot-sourceable core for unit testing. CLI integration lives in
        Invoke-DocHubCompletenessCore.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = 'origin/main'
    )

    if (-not (Test-Path -Path $RepoRoot -PathType Container)) {
        throw "RepoRoot not found or is not a directory: $RepoRoot"
    }

    $absoluteRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).path

    $hubDefinitions = @(
        [pscustomobject]@{
            Name           = 'instructions'
            ArtifactRoot   = '.github/instructions'
            ArtifactFilter = '*.instructions.md'
            ReadmePath     = '.github/instructions/README.md'
            ExcludePattern = $null
        },
        [pscustomobject]@{
            Name           = 'prompts'
            ArtifactRoot   = '.github/prompts'
            ArtifactFilter = '*.prompt.md'
            ReadmePath     = '.github/prompts/README.md'
            ExcludePattern = 'dt-method-*'
        }
    )

    $changedFiles = @()
    if ($ChangedFilesOnly) {
        $pushed = $false
        try {
            Push-Location -LiteralPath $absoluteRepoRoot -ErrorAction Stop
            $pushed = $true
            $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*.instructions.md', '*.prompt.md'))
        }
        catch {
            Write-Warning "Failed to detect changed files (falling back to full scan): $($_.Exception.Message)"
        }
        finally {
            if ($pushed) {Pop-Location -ErrorAction SilentlyContinue}
        }
    }

    $allMissing    = [System.Collections.Generic.List[object]]::new()
    $allDuplicates = [System.Collections.Generic.List[object]]::new()
    $allIssues     = [System.Collections.Generic.List[string]]::new()
    $totalChecked  = 0
    $totalExcluded = 0
    $hubResults    = @()

    foreach ($hub in $hubDefinitions) {
        $hubResult = Test-HubCompleteness -RepoRoot $absoluteRepoRoot -HubDefinition $hub -ChangedFiles $changedFiles

        $hubResults += [pscustomobject]@{
            Name           = $hubResult.Hub
            TotalChecked   = $hubResult.TotalChecked
            ExcludedCount  = $hubResult.ExcludedCount
            MissingCount   = $hubResult.Missing.Count
            DuplicateCount = $hubResult.Duplicates.Count
            ReadmeMissing  = $hubResult.ReadmeMissing
        }

        if ($hubResult.ReadmeMissing) {
            $allIssues.Add($hubResult.Issue)
        }

        foreach ($m in $hubResult.Missing) {
            $allMissing.Add($m)
            $allIssues.Add("[$($m.Hub)] '$($m.FileName)' is not referenced in $($m.ReadmePath) (artifact at $($m.RelativePath)).")
        }

        foreach ($d in $hubResult.Duplicates) {
            $allDuplicates.Add($d)
        }

        $totalChecked  += $hubResult.TotalChecked
        $totalExcluded += $hubResult.ExcludedCount
    }

    return @{
        Passed             = ($allMissing.Count -eq 0 -and $allIssues.Count -eq 0)
        MissingArtifacts   = @($allMissing)
        DuplicateBasenames = @($allDuplicates)
        Issues             = @($allIssues)
        TotalChecked       = $totalChecked
        ExcludedCount      = $totalExcluded
        Hubs               = $hubResults
    }
}

function Invoke-DocHubCompletenessCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RepoRoot = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = 'origin/main',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/doc-hub-completeness-results.json'
    )

    Write-Host "Running Doc Hub Completeness Check..." -ForegroundColor Cyan
    Write-Host ("Mode: " + $(if ($ChangedFilesOnly) { "changed-files-only (base: $BaseBranch)" } else { 'full scan' })) -ForegroundColor Cyan

    $result = Test-DocHubCompleteness -RepoRoot $RepoRoot -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch

    if ($result.MissingArtifacts.Count -gt 0) {
        foreach ($missing in $result.MissingArtifacts) {
            $readmeAbsPath = Join-Path $RepoRoot $missing.ReadmePath
            Write-CIAnnotation `
                -Message "Artifact '$($missing.FileName)' ($($missing.RelativePath)) is not referenced in this hub README." `
                -Level Error `
                -File $readmeAbsPath `
                -Line 1
        }
    }

    if ($result.DuplicateBasenames.Count -gt 0) {
        Write-Warning "Duplicate basenames detected (non-fatal; may cause false-pass on pure basename matching):"
        foreach ($dupe in $result.DuplicateBasenames) {
            Write-Warning "  [$($dupe.Hub)] '$($dupe.FileName)' at: $($dupe.Paths -join ', ')"
        }
    }

    $summary = [pscustomobject]@{
        TotalChecked          = $result.TotalChecked
        ExcludedCount         = $result.ExcludedCount
        MissingCount          = $result.MissingArtifacts.Count
        DuplicateBasenameCount = $result.DuplicateBasenames.Count
        Passed                = $result.Passed
        Mode                  = if ($ChangedFilesOnly) { 'changed-files-only' } else { 'full-scan' }
        Timestamp             = Get-StandardTimestamp
        Hubs                  = $result.Hubs
    }

    $logsDir = Split-Path $OutputPath -Parent
    if ($logsDir -and -not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    }

    $results = [pscustomobject]@{
        Summary            = $summary
        MissingArtifacts   = $result.MissingArtifacts
        DuplicateBasenames = $result.DuplicateBasenames
        Issues             = $result.Issues
    }

    $results | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutputPath -Encoding utf8NoBOM

    Set-CIOutput -Name 'count'    -Value $result.TotalChecked
    Set-CIOutput -Name 'excluded' -Value $result.ExcludedCount
    Set-CIOutput -Name 'issues'   -Value $result.Issues.Count
    Set-CIOutput -Name 'missing'  -Value $result.MissingArtifacts.Count
    Set-CIOutput -Name 'passed'   -Value $result.Passed

    if (-not $result.Passed) {
        Set-CIEnv -Name 'DOC_HUB_COMPLETENESS_FAILED' -Value 'true'
    }

    $statusText = if ($result.Passed) { 'Passed' } else { 'Failed' }

    $summaryLines = @(
        '## Doc Hub Completeness Results',
        '',
        "Status: $statusText",
        '',
        '| Metric | Count |',
        '|--------|-------|',
        "| Artifacts Checked | $($result.TotalChecked) |",
        "| Excluded | $($result.ExcludedCount) |",
        "| Missing | $($result.MissingArtifacts.Count) |",
        "| Duplicate Basenames | $($result.DuplicateBasenames.Count) |",
        ''
    )

    if ($result.Hubs.Count -gt 0) {
        $summaryLines += @(
            '### Per-Hub Breakdown',
            '',
            '| Hub | Checked | Excluded | Missing | Duplicates | README |',
            '|-----|---------|----------|---------|------------|--------|'
        )
        foreach ($hub in $result.Hubs) {
            $readmeStatus = if ($hub.ReadmeMissing) { 'Missing' } else { 'Present' }
            $summaryLines += "| $($hub.Name) | $($hub.TotalChecked) | $($hub.ExcludedCount) | $($hub.MissingCount) | $($hub.DuplicateCount) | $readmeStatus |"
        }
        $summaryLines += ''
    }

    if ($result.MissingArtifacts.Count -gt 0) {
        $summaryLines += @(
            '### Missing Artifacts',
            '',
            '| Hub | Artifact | Path |',
            '|-----|----------|------|'
        )
        foreach ($m in $result.MissingArtifacts) {
            $summaryLines += "| $($m.Hub) | $($m.FileName) | $($m.RelativePath) |"
        }
        $summaryLines += ''
    }

    Write-CIStepSummary -Content ($summaryLines -join "`n")

    if ($result.Passed) {
        Write-Host "Doc hub completeness check passed ($($result.TotalChecked) artifacts checked, $($result.ExcludedCount) excluded)." -ForegroundColor Green
    }
    else {
        Write-Host "Doc hub completeness check failed: $($result.MissingArtifacts.Count) missing artifact(s)." -ForegroundColor Red
        foreach ($issue in $result.Issues) {
            Write-Host "  FAIL: $issue" -ForegroundColor Red
        }
        throw "Doc hub completeness check failed: $($result.MissingArtifacts.Count) missing artifact(s)."
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-DocHubCompletenessCore -RepoRoot $RepoRoot -ChangedFilesOnly:$ChangedFilesOnly -BaseBranch $BaseBranch -OutputPath $OutputPath
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Doc hub completeness check failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}

#endregion Main Execution
