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
        $pythonSkills = Get-ChildItem -Path . -Filter 'pyproject.toml' -Recurse -File |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            ForEach-Object { $_.Directory.FullName }

        if (-not $pythonSkills) {
            Write-Host 'No Python skills found (no pyproject.toml files detected)' -ForegroundColor Yellow
            return @{ success = $true; skillsChecked = 0; errors = @() }
        }

        Write-Host "Found $($pythonSkills.Count) Python skill(s):" -ForegroundColor Cyan
        $pythonSkills | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        # Check if ruff is available (once, before loop)
        $ruffAvailable = Get-Command ruff -ErrorAction SilentlyContinue
        if (-not $ruffAvailable) {
            Write-Host '❌ ruff is not installed. Run "uv sync" in a skill directory or install with "uv pip install ruff".' -ForegroundColor Red
            return @{ success = $false; skillsChecked = 0; errors = @('ruff not installed') }
        }

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
                $output = ruff check . 2>&1
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

        # Write results to file if OutputPath specified
        if ($OutputPath) {
            $results | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
        }

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
