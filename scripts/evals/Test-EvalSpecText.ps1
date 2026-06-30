#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Runs alex.js and retext-profanities against the AI-artifact markdown corpus.

.DESCRIPTION
    Walks the markdown corpus under `.github/{agents,prompts,instructions,skills}/**/*.md`
    and `docs/**/*.md`, strips YAML frontmatter from each file, and pipes the
    bodies through a Node shim that runs alex.js and retext-profanities. Writes
    a JSON report and exits 1 when any rule fires. The intent is corpus
    protection: keeping agents, instructions, prompts, skills, and docs free of
    insensitive or foul language. Eval stimulus YAML under `evals/` is
    intentionally out of scope.

.PARAMETER CorpusGlob
    Repository-relative globs to scan. Each glob is split on `**` into a base
    directory and a file pattern; the base is walked recursively for files
    matching the pattern. Defaults to the agent / prompt / instructions /
    skills / docs markdown corpus.

.PARAMETER ExcludePath
    Repository-relative path prefixes (forward-slash form) to skip. Any
    enumerated file whose relative path begins with one of these prefixes
    is excluded before linting. Defaults to skipping the refusal-taxonomy
    references folder, whose markdown is regex source-of-truth that
    deliberately quotes profanity tokens and is not intended as prose.

.PARAMETER RepoRoot
    Absolute path to the repository root. Inferred from git when omitted.

.PARAMETER OutputPath
    Output file path for the moderation report. Defaults to 'logs/eval-spec-text.json'.

.PARAMETER NodePath
    Path to the node executable. Defaults to 'node' on PATH.

.PARAMETER FailOnAlex
    Treat alex.js findings as errors (exit 1) instead of warnings. Off by
    default: alex.js surface tone/style findings as `::warning` annotations
    that do not flip the exit code, while every retext-profanities finding
    remains a hard error. Enable when running a strict local sweep or when
    a downstream gate wants alex parity with profanity.

.EXAMPLE
    pwsh -File scripts/evals/Test-EvalSpecText.ps1

.EXAMPLE
    pwsh -File scripts/evals/Test-EvalSpecText.ps1 -FailOnAlex
#>

#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$CorpusGlob = @(
        '.github/agents/**/*.md',
        '.github/prompts/**/*.md',
        '.github/instructions/**/*.md',
        '.github/skills/**/*.md',
        'docs/**/*.md'
    ),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePath = @(
        '.github/skills/hve-core/vally-tests/references/'
    ),

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/eval-spec-text.json',

    [Parameter(Mandatory = $false)]
    [string]$NodePath = 'node',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnAlex
)

$ErrorActionPreference = 'Stop'


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

function Remove-MarkdownFrontmatter {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Content)

    if ([string]::IsNullOrEmpty($Content)) { return '' }
    if ($Content -notmatch '^---\r?\n') { return $Content }

    $match = [regex]::Match($Content, '^---\r?\n.*?\r?\n---\r?\n', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return $Content }

    return $Content.Substring($match.Length)
}

function Get-CorpusManifest {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CorpusGlob,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePath
    )

    $normalizedExcludes = @()
    if ($null -ne $ExcludePath) {
        $normalizedExcludes = @(
            $ExcludePath |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_.Trim().Replace('\', '/').TrimStart('/') }
        )
    }

    $items = [System.Collections.Generic.List[hashtable]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($glob in $CorpusGlob) {
        if ([string]::IsNullOrWhiteSpace($glob)) { continue }

        $normalized = $glob.Trim().Replace('\', '/')
        $parts = $normalized -split '\*\*', 2
        $base = $parts[0].TrimEnd('/')
        $pattern = if ($parts.Count -eq 2) { $parts[1].TrimStart('/') } else { '' }
        if ([string]::IsNullOrEmpty($pattern)) { $pattern = '*' }

        $baseFull = if ([string]::IsNullOrEmpty($base)) {
            $RepoRoot
        }
        elseif ([System.IO.Path]::IsPathRooted($base)) {
            $base
        }
        else {
            Join-Path -Path $RepoRoot -ChildPath $base
        }

        if (-not (Test-Path -LiteralPath $baseFull -PathType Container)) { continue }

        $found = Get-ChildItem -LiteralPath $baseFull -Recurse -File -Filter $pattern -ErrorAction SilentlyContinue
        foreach ($file in $found) {
            if (-not $seen.Add($file.FullName)) { continue }

            $rel = ($file.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')

            # Vendored dependencies are never part of the authored corpus.
            if ($rel -match '(^|/)node_modules/') { continue }

            $skip = $false
            foreach ($excluded in $normalizedExcludes) {
                if ($excluded.EndsWith('/')) {
                    if ($rel.StartsWith($excluded, [System.StringComparison]::OrdinalIgnoreCase)) { $skip = $true; break }
                }
                elseif ([string]::Equals($rel, $excluded, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $skip = $true; break
                }
            }
            if ($skip) { continue }

            $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrWhiteSpace($content)) { continue }

            $body = Remove-MarkdownFrontmatter -Content $content
            if ([string]::IsNullOrWhiteSpace($body)) { continue }

            $items.Add(@{ spec = $rel; stimulus = 'body'; text = $body })
        }
    }

    return , $items
}

function Invoke-RetextRunner {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[hashtable]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$ShimPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$NodePath
    )

    if ($Items.Count -eq 0) {
        return @{ exitCode = 0; results = @() }
    }

    $manifestJson = $Items | ConvertTo-Json -Depth 5 -Compress
    if ($Items.Count -eq 1) {
        # ConvertTo-Json emits an object (not an array) for single items.
        $manifestJson = "[$manifestJson]"
    }

    $tempInput = New-TemporaryFile
    $tempOutput = New-TemporaryFile
    $tempError = New-TemporaryFile
    try {
        Set-Content -LiteralPath $tempInput.FullName -Value $manifestJson -Encoding UTF8 -NoNewline

        $previousLocation = Get-Location
        Set-Location -LiteralPath $RepoRoot
        try {
            $proc = Start-Process -FilePath $NodePath -ArgumentList @($ShimPath) `
                -RedirectStandardInput $tempInput.FullName `
                -RedirectStandardOutput $tempOutput.FullName `
                -RedirectStandardError $tempError.FullName `
                -NoNewWindow -Wait -PassThru
        }
        finally {
            Set-Location -LiteralPath $previousLocation
        }

        $rawOut = Get-Content -LiteralPath $tempOutput.FullName -Raw -ErrorAction SilentlyContinue
        $rawErr = Get-Content -LiteralPath $tempError.FullName -Raw -ErrorAction SilentlyContinue

        if ($proc.ExitCode -eq 2) {
            throw "retext-runner failed to start: $rawErr"
        }

        $results = @()
        if (-not [string]::IsNullOrWhiteSpace($rawOut)) {
            try {
                $parsed = $rawOut | ConvertFrom-Json -ErrorAction Stop
                if ($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains 'results') {
                    $results = $parsed.results
                }
            }
            catch {
                throw "retext-runner produced unparseable output: $($_.Exception.Message); stderr: $rawErr"
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($rawErr)) {
            Write-Host $rawErr
        }

        return @{ exitCode = $proc.ExitCode; results = $results }
    }
    finally {
        Remove-Item -LiteralPath $tempInput.FullName, $tempOutput.FullName, $tempError.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Get-MessageSeverity {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Message,

        [Parameter(Mandatory = $false)]
        [switch]$FailOnAlex
    )

    $source = if ($Message.PSObject.Properties.Name -contains 'source') { [string]$Message.source } else { '' }
    if ($source -eq 'retext-profanities') { return 'error' }
    if ($source -eq 'alex' -and -not $FailOnAlex) { return 'warning' }
    return 'error'
}

function Write-TextModerationAnnotations {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Results,

        [Parameter(Mandatory = $false)]
        [switch]$FailOnAlex
    )

    $errorCount = 0
    $warningCount = 0

    foreach ($entry in $Results) {
        $specPath = if ($entry.PSObject.Properties.Name -contains 'spec') { $entry.spec } else { '<unknown>' }
        $stimulusName = if ($entry.PSObject.Properties.Name -contains 'stimulus') { $entry.stimulus } else { '<unknown>' }
        foreach ($msg in $entry.messages) {
            $rule = if ($msg.PSObject.Properties.Name -contains 'rule') { $msg.rule } else { 'unknown' }
            $body = if ($msg.PSObject.Properties.Name -contains 'message') { $msg.message } else { '' }
            $line = if ($msg.PSObject.Properties.Name -contains 'line' -and $null -ne $msg.line) { $msg.line } else { 1 }
            $severity = Get-MessageSeverity -Message $msg -FailOnAlex:$FailOnAlex
            $annotation = "[$rule] ${stimulusName}: $body"
            if ($severity -eq 'error') {
                $errorCount++
                Write-Host "::error file=$specPath,line=$line::$annotation"
            }
            else {
                $warningCount++
                Write-Host "::warning file=$specPath,line=$line::$annotation"
            }
        }
    }

    return @{ errorCount = $errorCount; warningCount = $warningCount }
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot
    $shimPath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/retext-runner.mjs'
    if (-not (Test-Path -LiteralPath $shimPath -PathType Leaf)) {
        Write-Error "retext-runner shim not found at '$shimPath'"
        exit 2
    }

    $manifest = Get-CorpusManifest -CorpusGlob $CorpusGlob -RepoRoot $resolvedRepoRoot -ExcludePath $ExcludePath

    $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $resolvedRepoRoot -ChildPath $OutputPath
    }
    $outputDir = Split-Path -Path $resolvedOutput -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $runResult = if ($manifest.Count -eq 0) {
        @{ exitCode = 0; results = @() }
    }
    else {
        Invoke-RetextRunner -Items $manifest -ShimPath $shimPath -RepoRoot $resolvedRepoRoot -NodePath $NodePath
    }

    $errorMessageCount = 0
    $warningMessageCount = 0
    foreach ($entry in $runResult.results) {
        foreach ($msg in $entry.messages) {
            $severity = Get-MessageSeverity -Message $msg -FailOnAlex:$FailOnAlex
            if ($severity -eq 'error') { $errorMessageCount++ } else { $warningMessageCount++ }
        }
    }

    $report = @{
        scanned = $manifest.Count
        flagged = ($runResult.results | Measure-Object).Count
        errorCount = $errorMessageCount
        warningCount = $warningMessageCount
        failOnAlex = [bool]$FailOnAlex
        results = $runResult.results
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8

    Write-Host "Scanned $($report.scanned) corpus file(s); $($report.flagged) flagged ($errorMessageCount error, $warningMessageCount warning)."
    Write-Host "Report: $resolvedOutput"

    if ($runResult.exitCode -ne 0) {
        $null = Write-TextModerationAnnotations -Results $runResult.results -FailOnAlex:$FailOnAlex
        if ($errorMessageCount -gt 0) { exit 1 }
    }

    exit 0
}
