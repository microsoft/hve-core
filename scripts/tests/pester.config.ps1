#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# pester.config.ps1
#
# Purpose: Pester 5.x configuration for HVE-Core PowerShell testing
# Author: HVE Core Team
#

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [string[]]$TestPath = @("$PSScriptRoot")
)

# Dynamically discover skill test directories when using the default TestPath.
# Skills live at .github/skills/<skill>/ or .github/skills/<collection>/<skill>/
# so we probe two fixed depths.
if (-not $PSBoundParameters.ContainsKey('TestPath')) {
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $repoRoot = Split-Path $scriptRoot -Parent
    $skillsPath = Join-Path $repoRoot '.github' 'skills'
    if (Test-Path $skillsPath) {
        $skillTestDirs = @()
        foreach ($depth in @('*', '*/*')) {
            $pattern = Join-Path $skillsPath $depth 'tests'
            $skillTestDirs += @(Get-Item -Path $pattern -ErrorAction SilentlyContinue |
                Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.Parent.FullName 'scripts')) })
        }
        if ($skillTestDirs) {
            $TestPath = @($TestPath) + @($skillTestDirs.FullName)
        }
    }
}

$configuration = New-PesterConfiguration

# Run configuration
$configuration.Run.Path = @($TestPath)
$configuration.Run.Exit = $CI.IsPresent
$configuration.Run.PassThru = $true
$configuration.Run.TestExtension = '.Tests.ps1'

# Filter configuration
$configuration.Filter.ExcludeTag = @('Integration', 'Slow')

# Output configuration
$configuration.Output.Verbosity = if ($CI.IsPresent) { 'Normal' } else { 'Detailed' }
$configuration.Output.CIFormat = if ($CI.IsPresent) { 'GithubActions' } else { 'Auto' }
$configuration.Output.CILogLevel = 'Error'

# Test result configuration (NUnit XML for CI artifact upload)
$configuration.TestResult.Enabled = $CI.IsPresent
$configuration.TestResult.OutputFormat = 'NUnitXml'
$configuration.TestResult.OutputPath = Join-Path $PSScriptRoot '../../logs/pester-results.xml'
$configuration.TestResult.TestSuiteName = 'HVE-Core-PowerShell-Tests'

# Code coverage configuration
if ($CodeCoverage.IsPresent) {
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $PSScriptRoot '../../logs/coverage.xml'

    # Resolve coverage paths explicitly - Join-Path with wildcards returns literal paths without file system expansion in Pester configuration
    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $coverageDirs = @('linting', 'security', 'lib', 'extension', 'plugins', 'collections')

    $coveragePaths = $coverageDirs | ForEach-Object {
        Get-ChildItem -Path (Join-Path $scriptRoot $_) -Include '*.ps1', '*.psm1' -Recurse -File -ErrorAction SilentlyContinue
    } | Where-Object {
        $_.FullName -notmatch '\.Tests\.ps1$'
    } | Select-Object -ExpandProperty FullName

    # Resolve skill script coverage paths from repo root.
    # Skills live at .github/skills/<skill>/ or .github/skills/<collection>/<skill>/
    # so probe two fixed depths, matching test directory discovery above.
    $repoRoot = Split-Path $scriptRoot -Parent
    $skillsPath = Join-Path $repoRoot '.github/skills'
    if (Test-Path $skillsPath) {
        $skillRoots = @()
        foreach ($depth in @('*', '*/*')) {
            $pattern = Join-Path $skillsPath $depth 'scripts'
            $skillRoots += @(Get-Item -Path $pattern -ErrorAction SilentlyContinue |
                Where-Object { $_.PSIsContainer } |
                ForEach-Object { $_.Parent })
        }

        $skillCoveragePaths = $skillRoots | ForEach-Object {
            $skillRoot = $_.FullName
            $skillScripts = Join-Path $skillRoot 'scripts'
            $paths = @()

            $paths += Get-ChildItem -Path $skillRoot -Include '*.ps1', '*.psm1' -File -ErrorAction SilentlyContinue

            if (Test-Path $skillScripts) {
                $paths += Get-ChildItem -Path $skillScripts -Include '*.ps1', '*.psm1' -Recurse -File -ErrorAction SilentlyContinue
            }

            $paths
        } | Where-Object { $_.FullName -notmatch '\.Tests\.ps1$' } |
            Select-Object -ExpandProperty FullName
        if ($skillCoveragePaths) {
            $coveragePaths = @($coveragePaths) + @($skillCoveragePaths)
        }
    }

    if ($coveragePaths.Count -gt 0) {
        $configuration.CodeCoverage.Path = $coveragePaths
    }

    $configuration.CodeCoverage.ExcludeTests = $true
    $configuration.CodeCoverage.CoveragePercentTarget = 80
}

# Should configuration
$configuration.Should.ErrorAction = 'Stop'

return $configuration
