#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Repo-wide safety lint that flags eval stimuli and corpora matching the
    skill-local refusal taxonomy.

.DESCRIPTION
    Parses the regex source-of-truth blocks from the refusal taxonomy markdown
    (default: .github/skills/hve-core/vally-tests/references/refusal-taxonomy.md)
    and scans the requested root (default: evals/) for files whose content
    matches any pattern. Surfaces matches as GitHub Actions error annotations
    and writes a structured JSON report. Exit codes:
      0 = clean (no match)
      1 = at least one match
      2 = taxonomy parse error or input error

.PARAMETER Root
    Repository-relative path to scan recursively. Defaults to 'evals'.

.PARAMETER RepoRoot
    Absolute path to the repository root. Inferred from git when omitted.

.PARAMETER OutputPath
    Output file path for the JSON safety report. Defaults to
    'logs/vally-test-safety.json'.

.PARAMETER TaxonomyPath
    Repository-relative path to the refusal taxonomy markdown that supplies
    the regex categories. Defaults to the canonical skill-local reference.

.PARAMETER Include
    Glob extensions to include when walking the root. Defaults to YAML and
    CSV stimulus formats. Markdown is excluded because the taxonomy and
    related references deliberately quote refusal language.

.EXAMPLE
    pwsh -File scripts/evals/Test-VallyTestSafety.ps1

.EXAMPLE
    pwsh -File scripts/evals/Test-VallyTestSafety.ps1 -Root evals -OutputPath logs/vally-test-safety.json
#>

#Requires -Version 7.4

[CmdletBinding()]
[OutputType([void])]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root = 'evals',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/vally-test-safety.json',

    [Parameter(Mandatory = $false)]
    [string]$TaxonomyPath = '.github/skills/hve-core/vally-tests/references/refusal-taxonomy.md',

    [Parameter(Mandatory = $false)]
    [string[]]$Include = @('*.yml', '*.yaml', '*.csv')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

function Get-RefusalCategory {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Refusal taxonomy not found at '$Path'."
    }

    $text = Get-Content -LiteralPath $Path -Raw
    $sectionRegex = [Regex]'(?ms)^##\s+Category:\s+(?<name>[\w\-]+)\s*$(?<body>.*?)(?=^##\s+Category:|^##\s+Lint\s+script\s+contract|\z)'
    $regexBlock = [Regex]'(?ms)^[ \t]*```regex[^\r\n]*\r?\n(?<body>.*?)^[ \t]*```'

    $sectionMatches = $sectionRegex.Matches($text)
    $categories = [System.Collections.Generic.List[hashtable]]::new()
    $totalBlocks = 0
    foreach ($section in $sectionMatches) {
        $name = $section.Groups['name'].Value
        $body = $section.Groups['body'].Value
        $patterns = [System.Collections.Generic.List[string]]::new()
        foreach ($block in $regexBlock.Matches($body)) {
            $trimmed = $block.Groups['body'].Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $patterns.Add($trimmed)
                $totalBlocks++
            }
        }
        if ($patterns.Count -gt 0) {
            $categories.Add(@{ Name = $name; Patterns = $patterns })
        }
    }

    if ($categories.Count -eq 0) {
        throw "No regex categories parsed from '$Path'. Sections matched: $($sectionMatches.Count); regex blocks extracted: $totalBlocks. Verify '## Category: <name>' headings and indented ```regex fenced blocks."
    }

    return , $categories
}

function Get-LineNumberFromIndex {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    if ($Index -le 0) { return 1 }
    $prefix = $Content.Substring(0, [Math]::Min($Index, $Content.Length))
    $lineCount = ([Regex]::Matches($prefix, "`n")).Count
    return $lineCount + 1
}

function Invoke-VallyTestSafetyScan {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$TaxonomyPath,

        [Parameter(Mandatory = $true)]
        [string[]]$Include,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $taxonomyFull = if ([System.IO.Path]::IsPathRooted($TaxonomyPath)) {
        $TaxonomyPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $TaxonomyPath
    }

    $rootFull = if ([System.IO.Path]::IsPathRooted($Root)) {
        $Root
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $Root
    }

    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
        throw "Scan root '$rootFull' does not exist."
    }

    $categories = Get-RefusalCategory -Path $taxonomyFull

    $compiled = foreach ($cat in $categories) {
        [pscustomobject]@{
            Name     = $cat.Name
            Patterns = @($cat.Patterns)
        }
    }

    $scanned = [System.Collections.Generic.List[string]]::new()
    $matchList = [System.Collections.Generic.List[hashtable]]::new()
    $categoryCounts = @{}

    $files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Include $Include -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $relPath = ($file.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')
        $scanned.Add($relPath)

        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
        if ([string]::IsNullOrEmpty($content)) { continue }

        foreach ($cat in $compiled) {
            for ($i = 0; $i -lt $cat.Patterns.Count; $i++) {
                $pattern = $cat.Patterns[$i]
                try {
                    $rx = [Regex]::new($pattern)
                }
                catch {
                    throw "Pattern parse error for category '$($cat.Name)' index $i in '$($taxonomyFull)': $($_.Exception.Message)"
                }

                foreach ($m in $rx.Matches($content)) {
                    $lineNumber = Get-LineNumberFromIndex -Content $content -Index $m.Index
                    $matchList.Add(@{
                            path         = $relPath
                            category     = $cat.Name
                            patternIndex = $i
                            matchText    = $m.Value
                            lineNumber   = $lineNumber
                        })
                    if (-not $categoryCounts.ContainsKey($cat.Name)) {
                        $categoryCounts[$cat.Name] = 0
                    }
                    $categoryCounts[$cat.Name] += 1
                }
            }
        }
    }

    $report = [ordered]@{
        taxonomyPath = ($taxonomyFull.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')
        root         = $Root
        scanned      = $scanned
        matches      = $matchList
        summary      = [ordered]@{
            scannedCount   = $scanned.Count
            matchCount     = $matchList.Count
            categoryCounts = $categoryCounts
        }
    }

    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    return $report
}

function Write-VallyTestSafetyAnnotation {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$MatchList
    )

    foreach ($entry in $MatchList) {
        $snippet = $entry.matchText
        if ($snippet.Length -gt 120) {
            $snippet = $snippet.Substring(0, 117) + '...'
        }
        $snippet = $snippet -replace "[\r\n]+", ' '
        $msg = "vally-test-safety: $($entry.category) (pattern #$($entry.patternIndex)) match -> $snippet"
        Write-Host "::error file=$($entry.path),line=$($entry.lineNumber)::$msg"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot

    $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $resolvedRepoRoot -ChildPath $OutputPath
    }

    try {
        $report = Invoke-VallyTestSafetyScan `
            -RepoRoot $resolvedRepoRoot `
            -Root $Root `
            -TaxonomyPath $TaxonomyPath `
            -Include $Include `
            -OutputPath $resolvedOutput
    }
    catch {
        Write-Error $_.Exception.Message
        exit 2
    }

    Write-Host "vally-test-safety: scanned $($report.summary.scannedCount) file(s); $($report.summary.matchCount) match(es)."
    Write-Host "Report: $resolvedOutput"

    if ($report.summary.matchCount -gt 0) {
        Write-VallyTestSafetyAnnotation -MatchList $report.matches
        exit 1
    }

    exit 0
}
