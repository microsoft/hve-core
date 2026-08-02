# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
Lint script to detect bare 'pip install' calls.
The repository follows a 'uv-first' Python convention.
#>

param(
    [string]$TestDirectory = "."
)

$ErrorActionPreference = "Stop"

$script:ExcludeDirs = @(".git", "evals", ".venv", "venv", "env", "node_modules", "__pycache__")
$script:ExcludeFiles = @("THIRD-PARTY-NOTICES", "Invoke-PipInstallLint.ps1", "Invoke-PipInstallLint.Tests.ps1")
$script:Violations = @()
$script:ScannedFiles = @{}

function script:Test-ExcludedPath {
    param([string]$Path)
    $normalizedPath = $Path.Replace("\", "/").ToLowerInvariant()

    foreach ($dir in $script:ExcludeDirs) {
        if ($normalizedPath -match "(^|/)$([regex]::Escape($dir))(/|$)") { return $true }
    }
    foreach ($file in $script:ExcludeFiles) {
        if ($normalizedPath -match "(^|/)$([regex]::Escape($file))(/|$)") { return $true }
    }
    return $false
}

function script:Invoke-FileScan {
    param([string]$FilePath)
    
    $normalizedPath = $FilePath.Replace("\", "/")
    if ($script:ScannedFiles.ContainsKey($normalizedPath)) { return }
    $script:ScannedFiles[$normalizedPath] = $true

    if (script:Test-ExcludedPath -Path $FilePath) { return }

    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()
    if ($ext -notin @(".py", ".ps1", ".yml", ".yaml", ".md", "")) { return }

    try {
        $lines = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
        if (-not $lines) { return }
        
        $lineNumber = 1
        foreach ($line in $lines -split "`r?`n") {
            $strippedLine = $line.Trim()
            
            if ([string]::IsNullOrWhiteSpace($strippedLine)) { 
                $lineNumber++
                continue 
            }

            if ($line -match "#\s*pip-install-ok\b" -or $line -match "<!--\s*pip-install-ok\s*-->") {
                $lineNumber++
                continue
            }

            if ($line -match "\bpip3?\s+install\b" -and $line -notmatch "\buv\s+pip3?\s+install\b") {
                if ($strippedLine -notmatch "^(name:|- name:)") {
                    $script:Violations += "$FilePath`:$lineNumber`: $strippedLine"
                }
            }
            $lineNumber++
        }
    }
    catch {
        Write-Warning "Could not read $FilePath`: $_"
    }
}

function script:Invoke-Lint {
    param([string]$TargetDir = ".")
    
    $script:Violations = @()
    $script:ScannedFiles = @{}

    if ($TargetDir -eq ".") {
        foreach ($dir in @(".github/workflows", "scripts")) {
            if (Test-Path $dir) {
                Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { script:Invoke-FileScan -FilePath $_.FullName }
            }
        }
        Get-ChildItem -Path "." -Recurse -Include *.py, *.ps1, *.yml, *.yaml, *.md -File -ErrorAction SilentlyContinue | ForEach-Object {
            script:Invoke-FileScan -FilePath $_.FullName
        }
    } else {
        Get-ChildItem -Path $TargetDir -Recurse -Include *.py, *.ps1, *.yml, *.yaml, *.md -File -ErrorAction SilentlyContinue | ForEach-Object {
            script:Invoke-FileScan -FilePath $_.FullName
        }
    }

    if ($script:Violations.Count -gt 0) {
        Write-Error "ERROR: Found bare 'pip install' calls. Use 'uv pip install' instead."
        Write-Host "The repo follows a uv-first Python convention.`n" -ForegroundColor Yellow
        foreach ($v in ($script:Violations | Sort-Object -Unique)) {
            Write-Host "  - $v" -ForegroundColor Red
        }
        return $false
    } else {
        Write-Host "Success: No bare 'pip install' calls found." -ForegroundColor Green
        return $true
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $success = script:Invoke-Lint -TargetDir $TestDirectory
    if (-not $success) { exit 1 }
}
