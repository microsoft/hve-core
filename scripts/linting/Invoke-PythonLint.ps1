#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PythonLint.ps1
#
# Purpose: Read-only Python lint runner. Discovers Python skills via
#          pyproject.toml and invokes `ruff check` against each. Does not
#          modify source files; intended for CI gating.
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
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
        [string]$OutputPath
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
            Write-Host "`nRunning ruff in $skillPath..." -ForegroundColor Cyan

            Push-Location $skillPath
            try {
                $ruffCmd = Resolve-RuffCommand -SkillPath $skillPath -GlobalRuffAvailable $globalRuffAvailable

                if (-not $ruffCmd) {
                    Write-Host '❌ ruff not available (no .venv and not installed globally)' -ForegroundColor Red
                    $results.success = $false
                    $results.errors += $skillPath
                    continue
                }

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
            } catch {
                Write-Host "Error running ruff: $_" -ForegroundColor Red
                $results.success = $false
                $results.errors += "$skillPath - error: $_"
            } finally {
                Pop-Location
            }
        }

        $resolvedPath = Write-PythonLintResults -Results $results -RepoRoot $RepoRoot -OutputPath $OutputPath -DefaultFileName 'python-lint-results.json'
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
    $result = Invoke-PythonLint -RepoRoot $RepoRoot -OutputPath $OutputPath
    
    if ($result.success) {
        Write-Host "`n✅ All Python skills passed linting" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Linting completed with errors" -ForegroundColor Red
        exit 1
    }
}

#endregion
