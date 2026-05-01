#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
<#
.SYNOPSIS
    Formats Markdown tables across the repository using markdown-table-formatter.

.DESCRIPTION
    Cross-platform wrapper around the markdown-table-formatter Node library.
    Enumerates tracked Markdown files via 'git ls-files' (deterministic, respects
    .gitignore, and includes dot-prefixed directories such as .github/) and
    delegates formatting to the library API.

    The upstream CLI uses 'glob' with the v13 default of dot:false, which
    silently skips .github/** and other dot-prefixed paths on Windows. This
    wrapper bypasses that bug by passing an explicit file list to the library.

.PARAMETER Check
    Check only; exit with non-zero status if any tables would be reformatted.

.EXAMPLE
    ./scripts/linting/Format-MarkdownTables.ps1
    Reformat Markdown tables in place across the repository.

.EXAMPLE
    ./scripts/linting/Format-MarkdownTables.ps1 -Check
    Verify formatting without modifying files; exits non-zero on drift.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$emitVerbose = $VerbosePreference -ne 'SilentlyContinue'

Push-Location $repoRoot
try {
    $gitOutput = & git ls-files -z --cached --others --exclude-standard -- '*.md'
    if ($LASTEXITCODE -ne 0) {
        Write-Error 'git ls-files failed; not running inside a git checkout?'
        exit 2
    }

    $files = if ($gitOutput) { $gitOutput -split "`0" | Where-Object { $_ } } else { @() }
    if ($files.Count -eq 0) {
        Write-Output 'No markdown files found.'
        exit 0
    }

    if ($emitVerbose) {
        [System.Console]::Error.WriteLine("Formatting $($files.Count) markdown file(s).")
    }

    $tempList = New-TemporaryFile
    try {
        Set-Content -Path $tempList.FullName -Value $files -Encoding utf8

        $nodeScript = @'
import { readFileSync } from 'node:fs';
import pkg from 'markdown-table-formatter/lib/markdown-table-formatter.js';
const { MarkdownTableFormatter } = pkg;

const files = readFileSync(process.env.MTF_FILE_LIST, 'utf8')
    .split(/\r?\n/)
    .filter(Boolean);
const check = process.env.MTF_CHECK === '1';
const verbose = process.env.MTF_VERBOSE === '1';

const formatter = new MarkdownTableFormatter({ check });
const result = await formatter.run(files, { verbose });
for (const updated of result.updates) {
    console.log(`${check ? 'needs-format' : 'formatted'}: ${updated}`);
}
process.exit(result.status);
'@

        $env:MTF_FILE_LIST = $tempList.FullName
        $env:MTF_CHECK = $(if ($Check) { '1' } else { '0' })
        $env:MTF_VERBOSE = $(if ($emitVerbose) { '1' } else { '0' })

        & node --input-type=module -e $nodeScript
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item -Path $tempList.FullName -ErrorAction SilentlyContinue
        Remove-Item Env:MTF_FILE_LIST, Env:MTF_CHECK, Env:MTF_VERBOSE -ErrorAction SilentlyContinue
    }

    exit $exitCode
}
finally {
    Pop-Location
}
