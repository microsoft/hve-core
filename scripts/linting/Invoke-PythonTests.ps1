#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Dynamically discovers and tests Python skills

.DESCRIPTION
    Finds all directories containing pyproject.toml files (excluding node_modules)
    and runs pytest on each one.

.EXAMPLE
    ./scripts/linting/Invoke-PythonTests.ps1
#>

$ErrorActionPreference = "Stop"

# Find all directories with pyproject.toml
$pythonSkills = Get-ChildItem -Path . -Filter "pyproject.toml" -Recurse -File |
    Where-Object { $_.FullName -notmatch "node_modules" } |
    ForEach-Object { $_.Directory.FullName }

if (-not $pythonSkills) {
    Write-Host "No Python skills found (no pyproject.toml files detected)" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($pythonSkills.Count) Python skill(s):" -ForegroundColor Cyan
$pythonSkills | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

$hasFailures = $false
$totalTests = 0
$passedTests = 0
$failedTests = 0

foreach ($skillPath in $pythonSkills) {
    Write-Host "`nRunning pytest in $skillPath..." -ForegroundColor Cyan
    
    Push-Location $skillPath
    try {
        # Check if tests directory exists
        $testsDir = Join-Path $skillPath "tests"
        if (-not (Test-Path $testsDir)) {
            Write-Host "⚠ No tests directory found, skipping" -ForegroundColor Yellow
            Pop-Location
            continue
        }
        
        # Check if pytest is available
        $pytestAvailable = Get-Command pytest -ErrorAction SilentlyContinue
        if (-not $pytestAvailable) {
            Write-Host "⚠ pytest not installed, attempting to install..." -ForegroundColor Yellow
            pip install pytest pytest-cov -q
        }
        
        $result = pytest tests/ -v --tb=short 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host "$result"
        
        if ($exitCode -ne 0) {
            $hasFailures = $true
            $failedTests++
        } else {
            $passedTests++
        }
        $totalTests++
        
    } catch {
        Write-Host "Error running pytest: $_" -ForegroundColor Red
        $hasFailures = $true
        $failedTests++
        $totalTests++
    } finally {
        Pop-Location
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "  Total: $totalTests" -ForegroundColor White
Write-Host "  Passed: $passedTests" -ForegroundColor Green
Write-Host "  Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan

if ($hasFailures) {
    Write-Host "❌ Testing completed with failures" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All tests passed" -ForegroundColor Green
    exit 0
}
