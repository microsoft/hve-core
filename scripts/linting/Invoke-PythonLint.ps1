#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PythonLint.ps1
#
# Purpose: Python lint runner. Discovers Python skills via pyproject.toml and
#          invokes ruff against each. Defaults to read-only `ruff check` for CI
#          gating. With `-Fix`, applies `ruff check --fix` followed by
#          `ruff format` (mutates source; intended for local developer use).
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Fix
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PythonLintHelpers.psm1') -Force

#region Functions

function Invoke-PythonLint {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [switch]$Fix
    )

    Push-Location $RepoRoot
    try {
        $pythonSkills = Get-PythonSkill -RepoRoot $RepoRoot

        if (-not $pythonSkills) {
            Write-Host 'No Python skills found (no pyproject.toml files detected)' -ForegroundColor Yellow
            return @{ success = $true; skillsChecked = 0; errors = @() }
        }

        Write-Host "Found $($pythonSkills.Count) Python skill(s):" -ForegroundColor Cyan
        $pythonSkills | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        $globalRuffAvailable = [bool](Get-Command ruff -ErrorAction SilentlyContinue)

        $results = @{
            success = $true
            skillsChecked = 0
            errors = @()
            details = @()
        }

        foreach ($skillPath in $pythonSkills) {
            if ($Fix) {
                Write-Host "`nRunning ruff --fix and ruff format in $skillPath..." -ForegroundColor Cyan
            } else {
                Write-Host "`nRunning ruff in $skillPath..." -ForegroundColor Cyan
            }

            Push-Location $skillPath
            try {
                $ruffCmd = Resolve-RuffCommand -SkillPath $skillPath -GlobalRuffAvailable $globalRuffAvailable

                if (-not $ruffCmd) {
                    Write-Host '❌ ruff not available (no .venv and not installed globally)' -ForegroundColor Red
                    $results.success = $false
                    $results.errors += $skillPath
                    continue
                }

                if ($Fix) {
                    # Step 1: autofix lint rules
                    $fixOutput = & $ruffCmd check . --fix 2>&1
                    $fixExit = $LASTEXITCODE

                    # Step 2: apply formatter (issue #886 acceptance criterion)
                    $formatOutput = & $ruffCmd format . 2>&1
                    $formatExit = $LASTEXITCODE

                    $combinedOutput = (@($fixOutput) + @($formatOutput)) | Out-String
                    $passed = ($fixExit -eq 0 -and $formatExit -eq 0)

                    $result = @{
                        path = $skillPath
                        passed = $passed
                        output = $combinedOutput
                        fixExitCode = $fixExit
                        formatExitCode = $formatExit
                    }

                    $results.details += $result
                    $results.skillsChecked++

                    if (-not $passed) {
                        Write-Host "$combinedOutput" -ForegroundColor Red
                        if ($fixExit -ne 0) {
                            Write-Host '❌ Unfixable linting issues remain' -ForegroundColor Red
                        }
                        if ($formatExit -ne 0) {
                            Write-Host '❌ ruff format failed' -ForegroundColor Red
                        }
                        $results.success = $false
                        $results.errors += $skillPath
                    } else {
                        if ($combinedOutput.Trim()) {
                            Write-Host "$combinedOutput"
                        }
                        Write-Host '✓ Autofix and format complete' -ForegroundColor Green
                    }
                } else {
                    $output = & $ruffCmd check . 2>&1
                    $exitCode = $LASTEXITCODE

                    $result = @{
                        path = $skillPath
                        passed = ($exitCode -eq 0)
                        output = $output | Out-String
                    }

                    $results.details += $result
                    $results.skillsChecked++

                    if ($exitCode -ne 0) {
                        Write-Host "$output" -ForegroundColor Red
                        Write-Host '❌ Linting issues found' -ForegroundColor Red
                        $results.success = $false
                        $results.errors += $skillPath
                    } else {
                        if ($output) {
                            Write-Host "$output"
                        }
                        Write-Host '✓ No linting issues' -ForegroundColor Green
                    }
                }
            } catch {
                Write-Host "Error running ruff: $_" -ForegroundColor Red
                $results.success = $false
                $results.errors += "$skillPath - error: $_"
            } finally {
                Pop-Location
            }
        }

        $defaultFile = if ($Fix) { 'python-lint-fix-results.json' } else { 'python-lint-results.json' }
        $resolvedPath = Write-PythonLintResults -Results $results -RepoRoot $RepoRoot -OutputPath $OutputPath -DefaultFileName $defaultFile
        Write-Host "📊 Results written to: $resolvedPath" -ForegroundColor Cyan

        return $results
    } finally {
        Pop-Location
    }
}

#endregion

#region Main Execution

# Don't run main logic if dot-sourced for testing
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-PythonLint -RepoRoot $RepoRoot -OutputPath $OutputPath -Fix:$Fix

        if ($result.success) {
            if ($Fix) {
                Write-Host "`n✅ Python lint autofix completed successfully" -ForegroundColor Green
            } else {
                Write-Host "`n✅ All Python skills passed linting" -ForegroundColor Green
            }
            exit 0
        } else {
            if ($Fix) {
                Write-Host "`n❌ Python lint autofix completed with unfixable errors" -ForegroundColor Red
            } else {
                Write-Host "`n❌ Linting completed with errors" -ForegroundColor Red
            }
            exit 1
        }
    }
    catch {
        Write-CIAnnotation -Level 'Error' -Message $_.Exception.Message
        Write-Error -ErrorAction Continue "Invoke-PythonLint failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion
