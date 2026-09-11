#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Invoke-PythonTests.ps1
#
# Purpose: Dynamically discovers and tests Python skills using pytest
# Author: HVE Core Team

#Requires -Version 7.4

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

function Invoke-UvEnvironmentSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Locked
    )

    if (-not $Locked) {
        $output = & uv sync --dev 2>&1
        return @{
            exitCode = $LASTEXITCODE
            output = $output
            useOfflineRun = $false
        }
    }

    $defaultIndex = $env:UV_DEFAULT_INDEX ?? 'https://pypi.org/simple'
    if ($defaultIndex.TrimEnd('/') -eq 'https://pypi.org/simple') {
        $output = & uv sync --locked --dev 2>&1
        return @{
            exitCode = $LASTEXITCODE
            output = $output
            useOfflineRun = $false
        }
    }

    $requirementsFile = New-TemporaryFile
    $originalDefaultIndex = $env:UV_DEFAULT_INDEX
    $originalIndexUrl = $env:UV_INDEX_URL
    try {
        Remove-Item Env:UV_DEFAULT_INDEX -ErrorAction SilentlyContinue
        Remove-Item Env:UV_INDEX_URL -ErrorAction SilentlyContinue
        $output = & uv export --locked --offline --no-emit-project --quiet --output-file $requirementsFile 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $env:UV_DEFAULT_INDEX = $originalDefaultIndex
        if ($null -eq $originalIndexUrl) {
            Remove-Item Env:UV_INDEX_URL -ErrorAction SilentlyContinue
        } else {
            $env:UV_INDEX_URL = $originalIndexUrl
        }
        Remove-Item $requirementsFile -Force -ErrorAction SilentlyContinue
    }

    return @{
        exitCode = $exitCode
        output = $output
        useOfflineRun = $true
    }
}

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

        # Prefer locked uv environments when available; pytest remains the fallback for unlocked projects.
        $uvCommand = Get-Command uv -ErrorAction SilentlyContinue
        $globalPytest = Get-Command pytest -ErrorAction SilentlyContinue

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
                
                $uvLockPath = Join-Path $skillPath 'uv.lock'
                $runner = 'pytest'
                $syncOutput = $null

                # use uv if the command is available, regardless of whether uv.lock exists
                if ($uvCommand) {
                    $runner = 'uv'
                    $hasLock = Test-Path $uvLockPath

                    if ($hasLock) {
                        Write-Host '  Using uv locked environment' -ForegroundColor Gray
                    } else {
                        Write-Host '  Using uv environment (syncing dev dependencies)' -ForegroundColor Gray
                    }

                    $syncResult = Invoke-UvEnvironmentSync -Locked $hasLock
                    $syncOutput = $syncResult.output
                    $syncExitCode = $syncResult.exitCode
                    Write-Host "$syncOutput"

                    if ($syncExitCode -ne 0) {
                        $result = @{
                            path = $skillPath
                            passed = $false
                            runner = $runner
                            phase = 'sync'
                            output = $syncOutput | Out-String
                        }

                        $results.details += $result
                        $results.skillsTested++
                        $results.success = $false
                        $results.failed++
                        $results.errors += $skillPath
                        Write-Host '❌ uv sync failed' -ForegroundColor Red
                        continue
                    }

                    if ($syncResult.useOfflineRun) {
                        $output = & uv run --frozen --offline pytest tests/ $Verbosity --tb=short 2>&1
                    } else {
                        $output = & uv run pytest tests/ $Verbosity --tb=short 2>&1
                    }
                    $exitCode = $LASTEXITCODE
                } else {
                    # Resolve pytest: prefer skill venv, fall back to global
                    $pytestCmd = $null
                    $venvPytest = Join-Path $skillPath '.venv/bin/pytest'
                    $venvPytestWin = Join-Path $skillPath '.venv/Scripts/pytest.exe'
                    if (Test-Path $venvPytest) {
                        $pytestCmd = $venvPytest
                        Write-Host '  Using venv pytest' -ForegroundColor Gray
                    } elseif (Test-Path $venvPytestWin) {
                        $pytestCmd = $venvPytestWin
                        Write-Host '  Using venv pytest' -ForegroundColor Gray
                    } elseif ($globalPytest) {
                        $pytestCmd = 'pytest'
                    }

                    if (-not $pytestCmd) {
                        # Updated error message to reflect that uv is the primary check
                        Write-Host '❌ pytest not available (uv not found, no .venv, and not installed globally)' -ForegroundColor Red
                        $results.success = $false
                        $results.failed++
                        $results.errors += $skillPath
                        continue
                    }

                    $output = & $pytestCmd tests/ $Verbosity --tb=short 2>&1
                    $exitCode = $LASTEXITCODE
                }
                
                $result = @{
                    path = $skillPath
                    passed = ($exitCode -eq 0)
                    runner = $runner
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
