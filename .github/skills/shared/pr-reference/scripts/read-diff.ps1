# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
Reads diff content from a PR reference XML with chunking and file filtering.

.DESCRIPTION
Provides structured access to pr-reference.xml content including chunk-based
reading, line range extraction, and single-file diff isolation.

.PARAMETER InputPath
Path to the PR reference XML file. Defaults to .copilot-tracking/pr/pr-reference.xml.

.PARAMETER Chunk
Chunk number to read (1-based).

.PARAMETER ChunkSize
Number of lines per chunk. Defaults to 500.

.PARAMETER Lines
Line range to read in format "START,END" or "START-END".

.PARAMETER File
Extract diff for a specific file path.

.PARAMETER Summary
Show diff summary with file list and change stats.

.PARAMETER Info
Show chunk information without content.

.EXAMPLE
./read-diff.ps1 -Chunk 1
Reads the first 500 lines of the diff.

.EXAMPLE
./read-diff.ps1 -Chunk 2 -ChunkSize 300
Reads lines 301-600 of the diff.

.EXAMPLE
./read-diff.ps1 -File "src/main.ts"
Extracts the diff for a specific file.

.EXAMPLE
./read-diff.ps1 -Info
Shows chunk breakdown without content.
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter()]
    [Alias('i', 'Input')]
    [string]$InputPath = "",

    [Parameter(ParameterSetName = 'Chunk')]
    [Alias('c')]
    [int]$Chunk = 0,

    [Parameter()]
    [Alias('s')]
    [int]$ChunkSize = 500,

    [Parameter(ParameterSetName = 'Lines')]
    [Alias('l')]
    [string]$Lines = "",

    [Parameter(ParameterSetName = 'File')]
    [Alias('f')]
    [string]$File = "",

    [Parameter(ParameterSetName = 'Summary')]
    [switch]$Summary,

    [Parameter(ParameterSetName = 'Info')]
    [switch]$Info
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'shared.psm1') -Force

function Get-ChunkInfo {
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [int]$TotalLines,

        [Parameter(Mandatory)]
        [int]$ChunkSize
    )

    $totalChunks = [math]::Ceiling($TotalLines / $ChunkSize)

    return [PSCustomObject]@{
        TotalLines  = $TotalLines
        ChunkSize   = $ChunkSize
        TotalChunks = $totalChunks
    }
}

function Get-ChunkRange {
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [int]$ChunkNumber,

        [Parameter(Mandatory)]
        [int]$ChunkSize,

        [Parameter(Mandatory)]
        [int]$TotalLines
    )

    $start = (($ChunkNumber - 1) * $ChunkSize) + 1
    $end = [math]::Min($ChunkNumber * $ChunkSize, $TotalLines)

    return [PSCustomObject]@{
        Start = $start
        End   = $end
    }
}

function Get-FileDiff {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Content,

        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $inTargetFile = $false
    $diffLines = @()
    $escapedPath = [regex]::Escape($FilePath)

    foreach ($line in $Content) {
        if ($line -match "^diff --git") {
            if ($line -match "a/$escapedPath b/") {
                $inTargetFile = $true
            }
            elseif ($inTargetFile) {
                break
            }
        }

        if ($inTargetFile) {
            $diffLines += $line
        }
    }

    return $diffLines -join [Environment]::NewLine
}

function Get-DiffSummary {
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Content
    )

    $files = @()
    $currentFile = $null
    $added = 0
    $removed = 0

    foreach ($line in $Content) {
        if ($line -match "^diff --git a/(.+?) b/") {
            if ($currentFile) {
                $files += [PSCustomObject]@{
                    Path    = $currentFile
                    Added   = $added
                    Removed = $removed
                }
            }
            $currentFile = $Matches[1]
            $added = 0
            $removed = 0
        }
        elseif ($currentFile) {
            if ($line -match "^\+[^+]") { $added++ }
            elseif ($line -match "^-[^-]") { $removed++ }
        }
    }

    if ($currentFile) {
        $files += [PSCustomObject]@{
            Path    = $currentFile
            Added   = $added
            Removed = $removed
        }
    }

    $output = @("Changed files:")
    foreach ($file in ($files | Sort-Object Path)) {
        $output += "  $($file.Path) (+$($file.Added)/-$($file.Removed))"
    }

    return $output -join [Environment]::NewLine
}

function Invoke-ReadDiff {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InputPath = "",

        [Parameter()]
        [int]$Chunk = 0,

        [Parameter()]
        [int]$ChunkSize = 500,

        [Parameter()]
        [string]$Lines = "",

        [Parameter()]
        [string]$File = "",

        [Parameter()]
        [switch]$Summary,

        [Parameter()]
        [switch]$Info
    )

    $repoRoot = Get-RepositoryRoot
    $xmlPath = if ($InputPath) {
        $InputPath
    } else {
        Join-Path $repoRoot '.copilot-tracking/pr/pr-reference.xml'
    }

    if (-not (Test-Path -LiteralPath $xmlPath)) {
        throw "PR reference file not found: $xmlPath`nRun generate.ps1 first to create the PR reference."
    }

    $content = Get-Content -LiteralPath $xmlPath
    $totalLines = $content.Count
    $chunkInfo = Get-ChunkInfo -TotalLines $totalLines -ChunkSize $ChunkSize

    # Info mode
    if ($Info) {
        Write-Output "File: $xmlPath"
        Write-Output "Total lines: $totalLines"
        Write-Output "Chunk size: $ChunkSize"
        Write-Output "Total chunks: $($chunkInfo.TotalChunks)"
        Write-Output ""
        Write-Output "Chunk breakdown:"
        for ($i = 1; $i -le $chunkInfo.TotalChunks; $i++) {
            $range = Get-ChunkRange -ChunkNumber $i -ChunkSize $ChunkSize -TotalLines $totalLines
            Write-Output "  Chunk ${i}: lines $($range.Start)-$($range.End)"
        }
        return
    }

    # Summary mode
    if ($Summary) {
        $summaryOutput = Get-DiffSummary -Content $content
        Write-Output $summaryOutput
        return
    }

    # File extraction mode
    if ($File) {
        $fileDiff = Get-FileDiff -Content $content -FilePath $File
        if ($fileDiff) {
            Write-Output $fileDiff
        }
        else {
            Write-Warning "No diff found for file: $File"
        }
        return
    }

    # Chunk mode
    if ($Chunk -gt 0) {
        if ($Chunk -gt $chunkInfo.TotalChunks) {
            throw "Chunk $Chunk exceeds file (only $($chunkInfo.TotalChunks) chunks available)"
        }

        $range = Get-ChunkRange -ChunkNumber $Chunk -ChunkSize $ChunkSize -TotalLines $totalLines
        Write-Output "# Chunk $Chunk/$($chunkInfo.TotalChunks) (lines $($range.Start)-$($range.End) of $totalLines)"
        Write-Output ""
        $content[($range.Start - 1)..($range.End - 1)] | ForEach-Object { Write-Output $_ }
        return
    }

    # Line range mode
    if ($Lines) {
        $rangeParts = $Lines -replace ',', '-' -split '-'
        if ($rangeParts.Count -ne 2) {
            throw "Invalid line range format. Use START,END or START-END"
        }

        $start = [int]$rangeParts[0]
        $end = [math]::Min([int]$rangeParts[1], $totalLines)

        if ($start -gt $totalLines) {
            throw "Start line $start exceeds file length ($totalLines lines)"
        }

        Write-Output "# Lines $start-$end of $totalLines"
        Write-Output ""
        $content[($start - 1)..($end - 1)] | ForEach-Object { Write-Output $_ }
        return
    }

    # Default: show info
    Write-Output "File: $xmlPath"
    Write-Output "Total lines: $totalLines"
    Write-Output "Total chunks: $($chunkInfo.TotalChunks) (at $ChunkSize lines/chunk)"
    Write-Output ""
    Write-Output "Use -Chunk N to read a specific chunk, -Lines START,END for a range,"
    Write-Output "or -File PATH to extract a specific file's diff."
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ReadDiff -InputPath $InputPath -Chunk $Chunk -ChunkSize $ChunkSize -Lines $Lines -File $File -Summary:$Summary -Info:$Info
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue $_.Exception.Message
        exit 1
    }
}
#endregion
