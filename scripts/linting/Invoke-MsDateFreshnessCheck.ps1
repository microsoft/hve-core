#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Checks ms.date frontmatter freshness in markdown files.

.DESCRIPTION
    Scans markdown files for ms.date frontmatter and flags files where the date
    exceeds a configurable staleness threshold. Generates JSON report and markdown
    summary for GitHub Actions job summaries.

.PARAMETER ThresholdDays
    Number of days before ms.date is considered stale. Defaults to 90.

.PARAMETER Paths
    Directories to scan for markdown files. Defaults to repository root.

.PARAMETER ChangedFilesOnly
    Only check files changed relative to BaseBranch.

.PARAMETER BaseBranch
    Base branch for changed-file detection. Defaults to 'origin/main'.
#>

#Requires -Version 7.4

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Parameters consumed via script scope')]
[CmdletBinding()]
param(
    [Parameter()]
    [int]$ThresholdDays = 90,

    [Parameter()]
    [string[]]$Paths = @('.'),

    [Parameter()]
    [switch]$ChangedFilesOnly,

    [Parameter()]
    [string]$BaseBranch = 'origin/main'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
Import-Module (Join-Path $scriptRoot 'Modules' 'LintingHelpers.psm1') -Force
Import-Module (Join-Path $scriptRoot '..' 'lib' 'Modules' 'CIHelpers.psm1') -Force

#region Helper Functions

function Get-MarkdownFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SearchPaths,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedOnly,

        [Parameter(Mandatory = $false)]
        [string]$Base = 'origin/main'
    )

    if ($ChangedOnly) {
        Write-Verbose "Getting changed markdown files relative to $Base"
        $files = @(Get-ChangedFilesFromGit -BaseBranch $Base -FileExtensions @('*.md'))
        return @($files | Where-Object { Test-Path $_ -PathType Leaf })
    }

    $excludeDirNames = @('node_modules', '.git', 'logs', '.copilot-tracking', 'plugins')
    $excludeFileNames = @('CHANGELOG.md')
    $allFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    # Bypass exclusions only when the caller passes a single explicit file path.
    # Directory paths (including '.' or absolute paths) always receive standard exclusions.
    $isExplicitFilePath = @($SearchPaths).Count -eq 1 -and (Test-Path $SearchPaths[0] -PathType Leaf)

    foreach ($path in $SearchPaths) {
        if (-not (Test-Path $path)) {
            Write-Warning "Path not found: $path"
            continue
        }

        $resolvedRoot = (Resolve-Path -LiteralPath $path).Path

        if ($isExplicitFilePath) {
            if ([System.IO.Path]::GetExtension($resolvedRoot) -eq '.md') {
                $allFiles.Add([System.IO.FileInfo]::new($resolvedRoot))
            }
            continue
        }

        # Stack-based walk that prunes excluded directories during traversal,
        # avoiding descent into large excluded trees (node_modules, plugins, .git).
        $pending = [System.Collections.Generic.Stack[string]]::new()
        $pending.Push($resolvedRoot)

        while ($pending.Count -gt 0) {
            $currentDir = $pending.Pop()

            try {
                foreach ($file in [System.IO.Directory]::EnumerateFiles($currentDir, '*.md')) {
                    if ([System.IO.Path]::GetExtension($file) -ne '.md') {
                        continue
                    }

                    if ($excludeFileNames -notcontains [System.IO.Path]::GetFileName($file)) {
                        $allFiles.Add([System.IO.FileInfo]::new($file))
                    }
                }

                foreach ($subDir in [System.IO.Directory]::EnumerateDirectories($currentDir)) {
                    if ($excludeDirNames -contains [System.IO.Path]::GetFileName($subDir)) {
                        continue
                    }

                    # Do not follow reparse points (symlinks/junctions), matching
                    # the default non-following behavior of Get-ChildItem -Recurse.
                    if ([System.IO.File]::GetAttributes($subDir) -band [System.IO.FileAttributes]::ReparsePoint) {
                        continue
                    }

                    $pending.Push($subDir)
                }
            }
            catch {
                Write-Verbose "Skipping inaccessible directory '$currentDir': $($_.Exception.Message)"
            }
        }
    }

    Write-Verbose "Found $($allFiles.Count) markdown files"
    return $allFiles.ToArray()
}

function Get-MsDateFromFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    try {
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop

        if ($content -match '(?s)^---\r?\n(.*?)\r?\n---') {
            $yamlContent = $matches[1]

            if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
                Write-Warning "PowerShell-Yaml module not found. Install with: Install-Module -Name PowerShell-Yaml -RequiredVersion 0.4.7"
                return $null
            }

            try {
                $frontmatter = $yamlContent | ConvertFrom-Yaml

                if ($frontmatter -and $frontmatter.'ms.date') {
                    $msDateString = $frontmatter.'ms.date'

                    try {
                        $msDate = [DateTime]::ParseExact(
                            $msDateString,
                            'yyyy-MM-dd',
                            [Globalization.CultureInfo]::InvariantCulture
                        )
                        return $msDate
                    }
                    catch {
                        Write-Verbose "Invalid ms.date format in ${FilePath}: $msDateString"
                        return $null
                    }
                }
            }
            catch {
                Write-Verbose "Failed to parse YAML frontmatter in ${FilePath}: $($_.Exception.Message)"
                return $null
            }
        }

        return $null
    }
    catch {
        Write-Warning "Error reading file ${FilePath}: $($_.Exception.Message)"
        return $null
    }
}

function New-MsDateReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,

        [Parameter(Mandatory = $true)]
        [int]$Threshold,

        [Parameter()]
        [string]$OutputDirectory = ''
    )

    $logsDir = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $PSScriptRoot '..' '..' 'logs' }
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $jsonPath = Join-Path $logsDir 'msdate-freshness-results.json'
    $mdPath = Join-Path $logsDir 'msdate-summary.md'

    $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding utf8
    Write-Verbose "JSON report written to $jsonPath"

    $staleFiles = @($Results | Where-Object { $_.IsStale })
    $totalFiles = @($Results).Count

    $markdown = @"
# ms.date Freshness Check Results

**Threshold**: $Threshold days
**Files Checked**: $totalFiles
**Stale Files**: $(@($staleFiles).Count)
"@

    if (@($staleFiles).Count -gt 0) {
        $markdown += @"

## 🚨 Stale Documentation Files

| File | ms.date | Age (days) |
|------|---------|------------|
"@
        $markdown += "`n"

        $sortedStaleFiles = $staleFiles | Sort-Object -Property AgeDays -Descending

        foreach ($file in $sortedStaleFiles) {
            $markdown += "| $($file.File) | $($file.MsDate) | $($file.AgeDays) |`n"
        }
    }
    else {
        $markdown += @"

### ✅ All Files Fresh

All documentation files with ms.date frontmatter are within the $Threshold-day freshness threshold.
"@
    }

    $markdown | Out-File -FilePath $mdPath -Encoding utf8 -NoNewline

    return @{
        JsonPath     = $jsonPath
        MarkdownPath = $mdPath
        StaleCount   = @($staleFiles).Count
    }
}

#endregion

#region Main Logic

if ($MyInvocation.InvocationName -ne '.') {
    Write-Verbose "Starting ms.date freshness check with $ThresholdDays-day threshold"

    $markdownFiles = @(Get-MarkdownFiles -SearchPaths $Paths -ChangedOnly:$ChangedFilesOnly -Base $BaseBranch)

    if (@($markdownFiles).Count -eq 0) {
        Write-Warning "No markdown files found to check"
        exit 0
    }

    Write-Verbose "Checking $(@($markdownFiles).Count) markdown files"

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $currentDate = Get-Date

    foreach ($file in $markdownFiles) {
        $relativePath = if ($file -is [System.IO.FileInfo]) {
            $file.FullName.Replace("$PWD$([System.IO.Path]::DirectorySeparatorChar)", '')
        }
        else {
            $file.Replace("$PWD$([System.IO.Path]::DirectorySeparatorChar)", '')
        }

        $msDate = Get-MsDateFromFrontmatter -FilePath $file

        if ($null -eq $msDate) {
            Write-Verbose "Skipping $relativePath (no ms.date)"
            continue
        }

        $age = $currentDate - $msDate
        $ageDays = [int]$age.TotalDays
        $isStale = $ageDays -gt $ThresholdDays

        $result = [PSCustomObject]@{
            File      = $relativePath
            MsDate    = $msDate.ToString('yyyy-MM-dd')
            AgeDays   = $ageDays
            IsStale   = $isStale
            Threshold = $ThresholdDays
        }

        $results.Add($result)

        if ($isStale) {
            Write-Verbose "Stale file detected: $relativePath ($ageDays days old)"
            Write-CIAnnotation -Message "${relativePath}: ms.date is $ageDays days old (threshold: $ThresholdDays days)" -Level 'Warning' -File $relativePath
        }
    }

    if (@($results).Count -eq 0) {
        Write-Warning "No files with ms.date frontmatter found"
        exit 0
    }

    $report = New-MsDateReport -Results $results -Threshold $ThresholdDays

    Write-Host "`nms.date Freshness Check Summary:"
    Write-Host "  Files Checked: $(@($results).Count)"
    Write-Host "  Stale Files: $($report.StaleCount)"
    Write-Host "  Threshold: $ThresholdDays days"

    Write-CIStepSummary -Path $report.MarkdownPath

    if ($report.StaleCount -gt 0) {
        Write-Host "`n❌ Found $($report.StaleCount) stale documentation file(s)"
        exit 1
    }
    else {
        Write-Host "`n✅ All files are fresh"
        exit 0
    }
}

#endregion
