#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Skill-local safety lint that flags stimuli matching the refusal taxonomy.

.DESCRIPTION
    Parses the regex source-of-truth blocks from
    references/refusal-taxonomy.md and evaluates the combined per-category
    alternation against the candidate stimulus YAML or CSV files. Exit codes:
      0 = clean (no match)
      1 = at least one match (refusal required)
      2 = ambiguous (multiple categories matched or pattern parse error)
    Implements deviation DR-02 (skill-local copy of the repo-wide safety lint).

.PARAMETER Path
    One or more files to scan. Accepts stimulus YAML, corpus CSV/XLSX, or
    arbitrary text. Directories are walked recursively.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$skillRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$taxonomyPath = Join-Path $skillRoot 'references/refusal-taxonomy.md'
if (-not (Test-Path -LiteralPath $taxonomyPath)) {
    throw "Refusal taxonomy not found at $taxonomyPath."
}

function Get-Categories {
    param([Parameter(Mandatory)][string]$TaxonomyPath)

    $text = Get-Content -LiteralPath $TaxonomyPath -Raw
    $sectionRegex = [Regex]'(?ms)^##\s+Category:\s+(?<name>[\w\-]+)\s*$(?<body>.*?)(?=^##\s+Category:|^##\s+Lint\s+script\s+contract|\z)'
    $regexBlock = [Regex]'(?ms)^[ \t]*```regex[^\r\n]*\r?\n(?<body>.*?)^[ \t]*```'

    $result = [Collections.Generic.List[hashtable]]::new()
    foreach ($section in $sectionRegex.Matches($text)) {
        $name = $section.Groups['name'].Value
        $body = $section.Groups['body'].Value
        $patterns = [Collections.Generic.List[string]]::new()
        foreach ($block in $regexBlock.Matches($body)) {
            $trimmed = $block.Groups['body'].Value.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $patterns.Add($trimmed)
            }
        }
        if ($patterns.Count -gt 0) {
            $result.Add(@{ Name = $name; Patterns = $patterns })
        }
    }
    , $result
}

function Get-CandidateFiles {
    param([Parameter(Mandatory)][string[]]$InputPaths)

    foreach ($p in $InputPaths) {
        if (-not (Test-Path -LiteralPath $p)) {
            Write-Warning "Path not found: $p"
            continue
        }
        $item = Get-Item -LiteralPath $p
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $p -Recurse -File -Include *.yml, *.yaml, *.csv, *.md, *.txt
        }
        else {
            $item
        }
    }
}

$categories = Get-Categories -TaxonomyPath $taxonomyPath
if (-not $categories -or $categories.Count -eq 0) {
    throw "No regex categories parsed from $taxonomyPath."
}

$combined = foreach ($cat in $categories) {
    [pscustomobject]@{
        Name    = $cat.Name
        Joined  = ($cat.Patterns -join '|')
        Members = $cat.Patterns
    }
}

$matchList = [Collections.Generic.List[psobject]]::new()
foreach ($file in (Get-CandidateFiles -InputPaths $Path)) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($cat in $combined) {
        try {
            $rx = [Regex]::new($cat.Joined)
        }
        catch {
            Write-Error "Pattern parse error for category '$($cat.Name)': $($_.Exception.Message)"
            exit 2
        }
        foreach ($m in $rx.Matches($content)) {
            $matchList.Add([pscustomobject]@{
                    File     = $file.FullName
                    Category = $cat.Name
                    Match    = $m.Value
                    Index    = $m.Index
                })
        }
    }
}

if ($matchList.Count -eq 0) {
    Write-Output 'vally-test-safety: clean (0 matches)'
    exit 0
}

$byCategory = $matchList | Group-Object -Property Category
foreach ($g in $byCategory) {
    Write-Output ('vally-test-safety: category={0} count={1}' -f $g.Name, $g.Count)
    foreach ($hit in $g.Group) {
        Write-Output ('  {0}:{1} -> {2}' -f $hit.File, $hit.Index, $hit.Match)
    }
}

if ($byCategory.Count -gt 1) {
    exit 2
}
exit 1
