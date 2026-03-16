# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
Extracts and lists all changed files from a PR reference XML.

.DESCRIPTION
Parses the pr-reference.xml file to extract file paths from diff headers.
Supports filtering by change type and multiple output formats.

.PARAMETER InputPath
Path to the PR reference XML file. Defaults to .copilot-tracking/pr/pr-reference.xml.

.PARAMETER Type
Filter by change type. Accepts a single value or comma-separated values:
Added, Deleted, Modified, Renamed, or All. Defaults to All.

.PARAMETER ExcludeType
Exclude specific change types. Accepts a single value or comma-separated values:
Added, Deleted, Modified, or Renamed. Mutually exclusive with -Type when -Type is not All.

.PARAMETER Format
Output format: Plain, Json, or Markdown. Defaults to Plain.

.EXAMPLE
./list-changed-files.ps1
Lists all changed files in plain text format.

.EXAMPLE
./list-changed-files.ps1 -Type Added -Format Markdown
Lists only added files in markdown table format.

.EXAMPLE
./list-changed-files.ps1 -Type Added,Modified,Renamed
Lists added, modified, and renamed files.

.EXAMPLE
./list-changed-files.ps1 -ExcludeType Deleted
Lists all files except deleted ones.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [Alias('i', 'Input')]
    [string]$InputPath = "",

    [Parameter()]
    [Alias('t')]
    [string[]]$Type = @('All'),

    [Parameter()]
    [string[]]$ExcludeType = @(),

    [Parameter()]
    [Alias('f')]
    [ValidateSet('Plain', 'Json', 'Markdown')]
    [string]$Format = "Plain"
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'shared.psm1') -Force

function Get-FileChanges {
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$XmlPath,

        [Parameter()]
        [string[]]$FilterType = @('All'),

        [Parameter()]
        [string[]]$ExcludeFilterType = @()
    )

    # Normalize comma-separated strings into arrays
    $normalizedFilter = @()
    foreach ($ft in $FilterType) {
        $normalizedFilter += $ft -split ','
    }
    $normalizedExclude = @()
    foreach ($et in $ExcludeFilterType) {
        $normalizedExclude += $et -split ','
    }

    $validTypes = @('All', 'Added', 'Deleted', 'Modified', 'Renamed')
    foreach ($t in $normalizedFilter) {
        if ($t -and $t -notin $validTypes) {
            throw "Invalid type filter: '$t'. Valid values: $($validTypes -join ', ')"
        }
    }
    foreach ($t in $normalizedExclude) {
        if ($t -and $t -notin @('Added', 'Deleted', 'Modified', 'Renamed')) {
            throw "Invalid exclude type: '$t'. Valid values: Added, Deleted, Modified, Renamed"
        }
    }

    $content = Get-Content -LiteralPath $XmlPath -Raw
    $changes = @()

    # Match diff headers and analyze change type
    $diffPattern = '(?ms)diff --git a/(.+?) b/(.+?)(?=\n)(.*?)(?=diff --git|</full_diff>)'
    $regexMatches = [regex]::Matches($content, $diffPattern)

    foreach ($match in $regexMatches) {
        $oldPath = $match.Groups[1].Value.Trim()
        $newPath = $match.Groups[2].Value.Trim()
        $diffBlock = $match.Groups[3].Value

        $changeType = 'Modified'
        if ($diffBlock -match 'new file mode') {
            $changeType = 'Added'
        }
        elseif ($diffBlock -match 'deleted file mode') {
            $changeType = 'Deleted'
        }
        elseif ($diffBlock -match 'rename from' -or $oldPath -ne $newPath) {
            $changeType = 'Renamed'
        }

        # Apply exclusion filter
        if ($normalizedExclude.Count -gt 0 -and $changeType -in $normalizedExclude) {
            continue
        }

        # Apply inclusion filter
        if ('All' -notin $normalizedFilter -and $changeType -notin $normalizedFilter) {
            continue
        }

        $displayPath = if ($changeType -eq 'Renamed') {
            "$oldPath -> $newPath"
        } else {
            $newPath
        }

        $changes += [PSCustomObject]@{
            Path = $displayPath
            Type = $changeType
        }
    }

    return $changes | Sort-Object -Property Path
}

function Format-Output {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Changes,

        [Parameter()]
        [string]$OutputFormat = "Plain"
    )

    switch ($OutputFormat) {
        'Plain' {
            return ($Changes | ForEach-Object { $_.Path }) -join [Environment]::NewLine
        }
        'Json' {
            return $Changes | ConvertTo-Json -Depth 2
        }
        'Markdown' {
            $lines = @(
                "| File | Change Type |",
                "|------|-------------|"
            )
            foreach ($change in $Changes) {
                $lines += "| ``$($change.Path)`` | $($change.Type) |"
            }
            return $lines -join [Environment]::NewLine
        }
    }
}

function Invoke-ListChangedFiles {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$InputPath = "",

        [Parameter()]
        [string[]]$Type = @('All'),

        [Parameter()]
        [string[]]$ExcludeType = @(),

        [Parameter()]
        [ValidateSet('Plain', 'Json', 'Markdown')]
        [string]$Format = "Plain"
    )

    # Validate mutual exclusion
    $hasNonAllType = ($Type | Where-Object { $_ -ne 'All' }).Count -gt 0
    if ($hasNonAllType -and $ExcludeType.Count -gt 0) {
        throw "-Type and -ExcludeType are mutually exclusive when -Type is not 'All'."
    }

    $repoRoot = Get-RepositoryRoot
    $xmlPath = if ($InputPath) {
        $InputPath
    } else {
        Join-Path $repoRoot '.copilot-tracking/pr/pr-reference.xml'
    }

    if (-not (Test-Path -LiteralPath $xmlPath)) {
        throw "PR reference file not found: $xmlPath`nRun generate.ps1 first to create the PR reference."
    }

    $changes = Get-FileChanges -XmlPath $xmlPath -FilterType $Type -ExcludeFilterType $ExcludeType
    $output = Format-Output -Changes $changes -OutputFormat $Format

    Write-Output $output
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ListChangedFiles -InputPath $InputPath -Type $Type -ExcludeType $ExcludeType -Format $Format
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
