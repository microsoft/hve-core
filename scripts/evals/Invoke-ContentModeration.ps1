#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    PowerShell wrapper for moderate.py content moderation CLI.

.DESCRIPTION
    Builds JSON-lines input from a file list or inline record array, invokes
    moderate.py with configurable threshold and model, and surfaces structured
    error messages for flagged content. Writes output to logs/ and exits with
    code 1 when any record triggers a flag.

.PARAMETER FileList
    Array of file paths to moderate. Mutually exclusive with -Records.

.PARAMETER Records
    Array of hashtables with 'id' and 'text' keys. Mutually exclusive with
    -FileList.

.PARAMETER Scope
    Scope identifier for output filename (moderation-<scope>.json).

.PARAMETER Threshold
    Toxicity threshold (0.0-1.0). Defaults to 0.5.

.PARAMETER Model
    Detoxify model variant: original, unbiased, multilingual. Defaults to
    unbiased.

.PARAMETER OutFile
    Output path for moderation results. Defaults to logs/moderation-<Scope>.json.

.PARAMETER RepoRoot
    Repository root directory. Defaults to git repo root or script directory.

.EXAMPLE
    ./Invoke-ContentModeration.ps1 -FileList @('doc1.md', 'doc2.md') -Scope 'corpus'

.EXAMPLE
    $records = @(@{ id = 'rec1'; text = 'Test content' })
    ./Invoke-ContentModeration.ps1 -Records $records -Scope 'input-artifact-1'

.NOTES
    Runs via: npm run eval:moderate

    The HVE_MODERATION_PYTHON environment variable overrides the interpreter
    used to run moderate.py. When unset, the uv-managed moderation venv is
    preferred, falling back to `python` on PATH.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$FileList,

    [Parameter(Mandatory = $false)]
    [AllowEmptyCollection()]
    [hashtable[]]$Records,

    [Parameter(Mandatory = $true)]
    [string]$Scope,

    [Parameter(Mandatory = $false)]
    [double]$Threshold = 0.5,

    [Parameter(Mandatory = $false)]
    [ValidateSet('original', 'unbiased', 'multilingual')]
    [string]$Model = 'unbiased',

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = $(
        $detectedRoot = git rev-parse --show-toplevel 2>$null
        if ($detectedRoot) { $detectedRoot } else { $PSScriptRoot }
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ModerationRunner.psm1') -Force

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    # Validate mutually exclusive parameters
    $hasFileList = $null -ne $FileList -and $FileList.Count -gt 0
    $recordsBound = $PSBoundParameters.ContainsKey('Records')
    $hasRecords = $null -ne $Records -and $Records.Count -gt 0

    # Use [Console]::Error.WriteLine + exit instead of Write-Error to bypass
    # $ErrorActionPreference = 'Stop' (which would terminate with exit 1 before
    # reaching the explicit exit code).
    if ($hasFileList -and $recordsBound) {
        [Console]::Error.WriteLine("-FileList and -Records are mutually exclusive")
        exit 2
    }

    if (-not $hasFileList -and -not $recordsBound) {
        [Console]::Error.WriteLine("Either -FileList or -Records is required")
        exit 2
    }

    # Build records from FileList if provided
    if ($hasFileList) {
        Write-Verbose "Building records from $($FileList.Count) files"
        $Records = ConvertTo-ModerationRecords -FileList $FileList -RepoRoot $RepoRoot
    }

    if (-not $hasRecords -and -not $hasFileList) {
        # Records explicitly bound as empty — write empty output and exit 0
        Write-Warning "No records to moderate for scope: $Scope"
        if (-not $OutFile) {
            $OutFile = Join-Path $RepoRoot "logs/moderation-$Scope.json"
        }
        $emptyOutput = @{
            records = @()
            summary = @{ total = 0; flaggedCount = 0 }
        }
        $OutFile | Split-Path -Parent | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
        $emptyOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $OutFile -Encoding utf8NoBOM
        exit 0
    }

    if ($Records.Count -eq 0) {
        Write-Warning "No records to moderate for scope: $Scope"
        # Write empty output file
        if (-not $OutFile) {
            $OutFile = Join-Path $RepoRoot "logs/moderation-$Scope.json"
        }
        $emptyOutput = @{
            records = @()
            summary = @{ total = 0; flaggedCount = 0 }
        }
        $OutFile | Split-Path -Parent | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
        $emptyOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $OutFile -Encoding utf8NoBOM
        exit 0
    }

    # Create temp input file
    $tempInput = $null
    try {
        $tempInput = New-ModerationInputFile -Records $Records
        Write-Verbose "Created input file: $tempInput"

        # Resolve output path
        if (-not $OutFile) {
            $OutFile = Join-Path $RepoRoot "logs/moderation-$Scope.json"
        }
        $OutFile = [System.IO.Path]::GetFullPath($OutFile, $RepoRoot)
        $outDir = Split-Path $OutFile -Parent
        if (-not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        }

        # Invoke moderate.py
        $moderatePy = Join-Path $PSScriptRoot 'moderation/moderate.py'
        if (-not (Test-Path $moderatePy)) {
            [Console]::Error.WriteLine("moderate.py not found at $moderatePy")
            exit 2
        }

        Write-Verbose "Invoking moderate.py: threshold=$Threshold model=$Model"

        # Prefer the uv-managed moderation virtual environment (created by
        # `uv sync` in scripts/evals/moderation), which has detoxify and torch
        # installed. An explicit HVE_MODERATION_PYTHON override takes precedence
        # (used by tests to inject a stub interpreter); otherwise fall back to
        # `python` on PATH when the venv is absent.
        $moderationDir = Join-Path $PSScriptRoot 'moderation'
        $venvPython = if ($IsWindows) {
            Join-Path $moderationDir '.venv/Scripts/python.exe'
        }
        else {
            Join-Path $moderationDir '.venv/bin/python'
        }

        if ($env:HVE_MODERATION_PYTHON) {
            Write-Verbose "Using interpreter override HVE_MODERATION_PYTHON: $($env:HVE_MODERATION_PYTHON)"
            & $env:HVE_MODERATION_PYTHON $moderatePy --input $tempInput --threshold $Threshold --model $Model --output $OutFile
        }
        elseif (Test-Path -LiteralPath $venvPython) {
            Write-Verbose "Using moderation venv interpreter: $venvPython"
            & $venvPython $moderatePy --input $tempInput --threshold $Threshold --model $Model --output $OutFile
        }
        else {
            $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCmd) {
                [Console]::Error.WriteLine("Moderation venv not found at $venvPython and python not found in PATH; run 'uv sync' in scripts/evals/moderation or install Python 3.11+")
                exit 2
            }
            Write-Verbose "Moderation venv not found; falling back to python on PATH"
            & python $moderatePy --input $tempInput --threshold $Threshold --model $Model --output $OutFile
        }

        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("moderate.py exited with code $LASTEXITCODE")
            # Check if output exists and surface errors
            if (Test-Path $OutFile) {
                $flagged = Test-ModerationOutput -OutputPath $OutFile
                if ($flagged) {
                    [Console]::Error.WriteLine("Content moderation failed for scope: $Scope")
                    exit 1
                }
            }
            exit $LASTEXITCODE
        }

        # Surface any flags
        $flagged = Test-ModerationOutput -OutputPath $OutFile
        if ($flagged) {
            [Console]::Error.WriteLine("Content moderation failed for scope: $Scope")
            exit 1
        }

        Write-Host "Content moderation passed for scope: $Scope ($($Records.Count) records)"
        exit 0
    }
    finally {
        # Clean up temp file
        if ($tempInput -and (Test-Path $tempInput)) {
            Remove-Item $tempInput -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion Main Execution
