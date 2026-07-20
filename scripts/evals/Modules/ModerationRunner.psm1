# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# ModerationRunner.psm1
# Purpose: Helpers for content moderation batch processing and orchestration
#Requires -Version 7.4

<#
.SYNOPSIS
    Builds a JSON-lines input file from a batch of records.

.DESCRIPTION
    Accepts an array of hashtables with 'id' and 'text' keys and writes them
    as JSON-lines to a temporary file. Returns the file path.

.PARAMETER Records
    Array of hashtables, each with 'id' and 'text' keys.

.PARAMETER OutFile
    Path to the output JSON-lines file. Defaults to a temp file.

.OUTPUTS
    System.String - Path to the JSON-lines file.

.EXAMPLE
    $records = @(
        @{ id = 'rec1'; text = 'Hello world' },
        @{ id = 'rec2'; text = 'Test content' }
    )
    $inputFile = New-ModerationInputFile -Records $records
#>
function New-ModerationInputFile {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]$Records,

        [Parameter(Mandatory = $false)]
        [string]$OutFile
    )

    if (-not $OutFile) {
        $OutFile = [System.IO.Path]::GetTempFileName()
    }

    $jsonLines = $Records | ForEach-Object {
        ConvertTo-Json $_ -Compress -Depth 1
    }
    $jsonLines | Set-Content -Path $OutFile -Encoding utf8NoBOM

    Write-Verbose "Wrote $($Records.Count) records to $OutFile"
    return $OutFile
}

<#
.SYNOPSIS
    Reads files from a file list and builds moderation records.

.DESCRIPTION
    Accepts an array of file paths, reads each file, and constructs a hashtable
    record with 'id' (relative path) and 'text' (file content).

.PARAMETER FileList
    Array of file paths to read.

.PARAMETER RepoRoot
    Repository root for relativizing file paths. Defaults to the current directory.

.OUTPUTS
    System.Collections.Hashtable[] - Array of records with id and text keys.

.EXAMPLE
    $files = Get-ChildItem *.md
    $records = ConvertTo-ModerationRecords -FileList $files.FullName
#>
function ConvertTo-ModerationRecords {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$FileList,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot = $PWD
    )

    $records = @()
    foreach ($filePath in $FileList) {
        if (-not (Test-Path -LiteralPath $filePath)) {
            Write-Warning "File not found: $filePath"
            continue
        }
        $relativePath = (Resolve-Path -LiteralPath $filePath -Relative -RelativeBasePath $RepoRoot).TrimStart('.', '\', '/')
        $content = Get-Content -LiteralPath $filePath -Raw -Encoding utf8
        $records += @{
            id   = $relativePath
            text = $content
        }
    }
    Write-Verbose "Built $($records.Count) records from $($FileList.Count) files"
    return $records
}

<#
.SYNOPSIS
    Parses moderate.py JSON output and surfaces structured error messages.

.DESCRIPTION
    Reads the JSON output from moderate.py, extracts flagged records, and emits
    GitHub Actions error annotations for each flagged item.

.PARAMETER OutputPath
    Path to the moderate.py JSON output file.

.OUTPUTS
    System.Boolean - Returns $true if any records were flagged, $false otherwise.

.EXAMPLE
    if (Test-ModerationOutput -OutputPath logs/moderation-corpus.json) {
        Write-Error "Content moderation failed"
    }
#>
function Test-ModerationOutput {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        Write-Error "Moderation output file not found: $OutputPath"
        return $true
    }

    $output = Get-Content -Path $OutputPath -Raw | ConvertFrom-Json
    $flaggedCount = $output.summary.flaggedCount

    if ($flaggedCount -eq 0) {
        Write-Verbose "Content moderation passed: all $($output.summary.total) records clean"
        return $false
    }

    Write-Warning "Content moderation failed: $flaggedCount/$($output.summary.total) records flagged"
    foreach ($record in $output.records) {
        if ($record.flagged) {
            $labels = $record.flaggedLabels -join ', '
            Write-Host "::error file=$($record.id)::Content moderation flag: $labels"
        }
    }
    return $true
}

Export-ModuleMember -Function @(
    'New-ModerationInputFile',
    'ConvertTo-ModerationRecords',
    'Test-ModerationOutput'
)
