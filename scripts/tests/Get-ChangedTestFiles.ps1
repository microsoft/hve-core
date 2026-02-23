#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Get-ChangedTestFiles.ps1
#
# Purpose: Detect changed PowerShell files and resolve corresponding Pester test paths
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseBranch,

    [Parameter(Mandatory = $false)]
    [string[]]$FileFilter = @('*.ps1', '*.psm1'),

    [Parameter(Mandatory = $false)]
    [string]$SkillsRoot = '.github/skills',

    [Parameter(Mandatory = $false)]
    [string]$TestRoot = 'scripts/tests'
)

$ErrorActionPreference = 'Stop'

# Import CI helpers for output writing
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force

#region Functions

function Get-ChangedTestFilesCore {
    <#
    .SYNOPSIS
        Detects changed PowerShell files and resolves corresponding Pester test paths.
    .DESCRIPTION
        Runs git diff against the specified base branch to find changed .ps1/.psm1 files,
        then maps each changed source file to its corresponding test file by searching
        test directories including skill test folders at depth 1 and 2.
    .PARAMETER BaseBranch
        The base branch to diff against (e.g., 'main').
    .PARAMETER FileFilter
        File extensions to include in the diff (default: *.ps1, *.psm1).
    .PARAMETER SkillsRoot
        Root directory for skill packages containing test folders.
    .PARAMETER TestRoot
        Root directory for script tests.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseBranch,

        [string[]]$FileFilter = @('*.ps1', '*.psm1'),

        [string]$SkillsRoot = '.github/skills',

        [string]$TestRoot = 'scripts/tests'
    )

    # Get changed files from git diff
    $diffOutput = git diff --name-only "origin/$BaseBranch...HEAD" -- @FileFilter 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "git diff failed with exit code $LASTEXITCODE"
        return [PSCustomObject]@{
            HasChanges   = $false
            TestPaths    = @()
            ChangedFiles = @()
        }
    }

    $changedFiles = @($diffOutput | Where-Object { $_ -and $_.Trim() })
    if ($changedFiles.Count -eq 0) {
        return [PSCustomObject]@{
            HasChanges   = $false
            TestPaths    = @()
            ChangedFiles = @()
        }
    }

    Write-Host "Changed PowerShell files:"
    $changedFiles | ForEach-Object { Write-Host "  - $_" }

    # Build test search directories
    $testDirs = @($TestRoot)
    if (Test-Path $SkillsRoot) {
        foreach ($depth in @('*', '*/*')) {
            $pattern = Join-Path $SkillsRoot $depth 'tests'
            Get-Item -Path $pattern -ErrorAction SilentlyContinue |
                Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.Parent.FullName 'scripts')) } |
                ForEach-Object { $testDirs += $_.FullName }
        }
    }

    # Map changed source files to test files
    $testPaths = @()
    foreach ($file in $changedFiles) {
        # Include directly changed test files
        if ($file -like '*.Tests.ps1') {
            $fullPath = Join-Path (Get-Location) $file
            if (Test-Path $fullPath) {
                $testPaths += $fullPath
            }
            continue
        }

        # Map source file to test file by name convention
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
        $testFileName = "$fileName.Tests.ps1"

        foreach ($dir in $testDirs) {
            $candidates = Get-ChildItem -Path $dir -Filter $testFileName -Recurse -ErrorAction SilentlyContinue
            foreach ($candidate in $candidates) {
                $testPaths += $candidate.FullName
            }
        }
    }

    # Deduplicate
    $testPaths = @($testPaths | Select-Object -Unique)

    if ($testPaths.Count -eq 0) {
        Write-Host "No matching test files for changed PowerShell files"
    }
    else {
        Write-Host "Found $($testPaths.Count) test file(s) to run:"
        $testPaths | ForEach-Object { Write-Host "  - $_" }
    }

    return [PSCustomObject]@{
        HasChanges   = ($testPaths.Count -gt 0)
        TestPaths    = $testPaths
        ChangedFiles = $changedFiles
    }
}

#endregion

# Script guard: only execute CI output when run directly, not when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    if (-not $BaseBranch) {
        throw 'BaseBranch parameter is required when running directly.'
    }
    $result = Get-ChangedTestFilesCore -BaseBranch $BaseBranch -FileFilter $FileFilter -SkillsRoot $SkillsRoot -TestRoot $TestRoot

    # Write CI environment variables using injection-safe helpers
    Set-CIEnv -Name 'HAS_CHANGES' -Value ([string]$result.HasChanges)
    Set-CIEnv -Name 'TEST_PATHS' -Value ($result.TestPaths -join ';')
}
