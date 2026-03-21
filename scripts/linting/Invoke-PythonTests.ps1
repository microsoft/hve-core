#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Invoke-PythonTests.ps1
#
# Purpose: Dynamically discovers and tests Python skills using pytest
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$Verbosity = '-v'
)

$ErrorActionPreference = 'Stop'

#region Functions

function Invoke-PythonTests {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string]$Verbosity = '-v'
    )

    Push-Location $RepoRoot
    try {
        # Find all directories with pyproject.toml
        $pythonSkills = Get-ChildItem -Path . -Filter 'pyproject.toml' -Recurse -Force -File |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            ForEach-Object { $_.Directory.FullName }

        if (-not $pythonSkills) {
            Write-Host 'No Python skills found (no pyproject.toml files detected)' -ForegroundColor Yellow
            return @{ success = $true; skillsTested = 0; passed = 0; failed = 0; errors = @() }
        }

        Write-Host "Found $($pythonSkills.Count) Python skill(s):" -ForegroundColor Cyan
        $pythonSkills | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

        # Check if pytest is available (once, before loop - mirrors ruff check in lint script)
        $pytestAvailable = Get-Command pytest -ErrorAction SilentlyContinue
        if (-not $pytestAvailable) {
            Write-Host '❌ pytest is not installed. Run "uv sync" in a skill directory or install with "uv pip install pytest pytest-cov".' -ForegroundColor Red
            return @{ success = $false; skillsTested = 0; passed = 0; failed = 0; errors = @('pytest not installed') }
        }

        $results = @{
            success = $true
            skillsTested = 0
            passed = 0
            failed = 0
            errors = @()
            details = @()
        }

        foreach ($skillPath in $pythonSkills) {
            Write-Host "`nRunning pytest in $skillPath..." -ForegroundColor Cyan
            
            Push-Location $skillPath
            try {
                # Check if tests directory exists
                $testsDir = Join-Path $skillPath 'tests'
                if (-not (Test-Path $testsDir)) {
                    Write-Host '⚠ No tests directory found, skipping' -ForegroundColor Yellow
                    continue
                }
                
                $output = pytest tests/ $Verbosity --tb=short 2>&1
                $exitCode = $LASTEXITCODE
                
                $result = @{
                    path = $skillPath
                    passed = ($exitCode -eq 0)
                    output = $output | Out-String
                }
                
                $results.details += $result
                $results.skillsTested++
                
                Write-Host "$output"
                
                if ($exitCode -ne 0) {
                    Write-Host '❌ Tests failed' -ForegroundColor Red
                    $results.success = $false
                    $results.failed++
                    $results.errors += $skillPath
                } else {
                    Write-Host '✓ All tests passed' -ForegroundColor Green
                    $results.passed++
                }
            } catch {
                Write-Host "Error running pytest: $_" -ForegroundColor Red
                $results.success = $false
                $results.failed++
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
            $OutputPath = Join-Path -Path $logsDir -ChildPath 'python-test-results.json'
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
    $result = Invoke-PythonTests -RepoRoot $RepoRoot -OutputPath $OutputPath -Verbosity $Verbosity
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host 'Test Summary:' -ForegroundColor Cyan
    Write-Host "  Total: $($result.skillsTested)" -ForegroundColor White
    Write-Host "  Passed: $($result.passed)" -ForegroundColor Green
    Write-Host "  Failed: $($result.failed)" -ForegroundColor $(if ($result.failed -gt 0) { 'Red' } else { 'Green' })
    Write-Host '========================================' -ForegroundColor Cyan
    
    if ($result.success) {
        Write-Host '✅ All tests passed' -ForegroundColor Green
        exit 0
    } else {
        Write-Host '❌ Testing completed with failures' -ForegroundColor Red
        exit 1
    }
}

#endregion Main Execution
