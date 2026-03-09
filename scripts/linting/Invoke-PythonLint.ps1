#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Dynamically discovers and lints Python skills using ruff

.DESCRIPTION
    Finds all directories containing pyproject.toml files (excluding node_modules)
    and runs ruff linting on each one.

.EXAMPLE
    ./scripts/linting/Invoke-PythonLint.ps1
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

$hasErrors = $false

# Check if ruff is available
$ruffAvailable = Get-Command ruff -ErrorAction SilentlyContinue
if (-not $ruffAvailable) {
    Write-Host "⚠ ruff not installed, attempting to install..." -ForegroundColor Yellow
    pip install ruff -q
}

foreach ($skillPath in $pythonSkills) {
    Write-Host "`nRunning ruff in $skillPath..." -ForegroundColor Cyan
    
    Push-Location $skillPath
    try {
        $result = ruff check . 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($result) {
            Write-Host "$result"
        }
        
        if ($exitCode -ne 0) {
            Write-Host "❌ Linting issues found" -ForegroundColor Red
            $hasErrors = $true
        } else {
            Write-Host "✓ No linting issues" -ForegroundColor Green
        }
    } catch {
        Write-Host "Error running ruff: $_" -ForegroundColor Red
        $hasErrors = $true
    } finally {
        Pop-Location
    }
}

if ($hasErrors) {
    Write-Host "`n❌ Linting completed with errors" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All Python skills passed linting" -ForegroundColor Green
    exit 0
}
