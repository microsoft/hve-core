#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PythonLint.ps1
#
# Purpose: Dynamically discovers and lints Python skills using ruff
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

#region Functions

function Invoke-PythonLint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    Push-Location $RepoRoot
    try {
        # Find all directories with pyproject.toml
        $pythonSkills = Get-ChildItem -Path . -Filter 'pyproject.toml' -Recurse -Force -File |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            ForEach-Object { $_.Directory.FullName }

        if (-not $pythonSkills) {
            Write-Host 'No Python skills found (no pyproject.toml files detected)' -ForegroundColor Yellow
            return @{ success = $true; skillsChecked = 0; errors = @() }
        }

        Write-Host "Found $($pythonSkills.Count) Python skill(s):" -ForegroundColor Cyan
        $pythonSkills | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        # Check if ruff is globally available (used as fallback when skill has no venv)
        $globalRuff = Get-Command ruff -ErrorAction SilentlyContinue

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
                # Resolve ruff: prefer skill venv, fall back to global
                $ruffCmd = $null
                $venvRuff = Join-Path $skillPath '.venv/bin/ruff'
                $venvRuffWin = Join-Path $skillPath '.venv/Scripts/ruff.exe'
                if (Test-Path $venvRuff) {
                    $ruffCmd = $venvRuff
                    Write-Host '  Using venv ruff' -ForegroundColor Gray
                } elseif (Test-Path $venvRuffWin) {
                    $ruffCmd = $venvRuffWin
                    Write-Host '  Using venv ruff' -ForegroundColor Gray
                } elseif ($globalRuff) {
                    $ruffCmd = 'ruff'
                }

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

        # Default to logs directory when no OutputPath specified
        if (-not $OutputPath) {
            $logsDir = Join-Path -Path $RepoRoot -ChildPath 'logs'
            if (-not (Test-Path $logsDir)) {
                New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
            }
            $OutputPath = Join-Path -Path $logsDir -ChildPath 'python-lint-results.json'
        }
        $results | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
        Write-Host "📊 Results written to: $OutputPath" -ForegroundColor Cyan

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
