#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Test-PSModulePins.ps1
#
# Purpose: Enforce that all PowerShell module version pins across the repository
#          match the canonical versions declared in scripts/security/ps-module-versions.json.
# Author: HVE Core Team

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates PowerShell module version pins against the canonical pin config.

.DESCRIPTION
    Scans tracked repository files for module pins of the form:
      Install-Module -Name <Module> -RequiredVersion <version>
      Import-Module  -Name <Module> -RequiredVersion <version>
      #Requires -Modules @{ ModuleName='<Module>'; RequiredVersion='<version>' }

    For each managed module in scripts/security/ps-module-versions.json, every
    pinned version found in tracked files must match the canonical version.

    Writes JSON results to logs/ps-module-pins-results.json. Exits non-zero on
    violations.

.PARAMETER ConfigPath
    Path to the canonical pin config. Defaults to scripts/security/ps-module-versions.json.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'

#region Main Function
function Invoke-PSModulePinScan {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $repoRoot 'scripts/security/ps-module-versions.json'
    }
    if (-not (Test-Path $ConfigPath)) {
        throw "Pin config not found: $ConfigPath"
    }

    $pinConfig = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    $canonical = @{}
    foreach ($prop in $pinConfig.modules.PSObject.Properties) {
        $canonical[$prop.Name] = $prop.Value.version
    }

    # Files containing intentional non-canonical version literals (test fixtures, the
    # config itself, this validator). Paths are relative to repo root and use forward
    # slashes.
    $allowedFiles = @(
        'scripts/security/ps-module-versions.json',
        'scripts/security/Test-PSModulePins.ps1',
        'scripts/tests/security/Test-PSModulePins.Tests.ps1',
        'scripts/tests/security/Test-SHAStaleness.Tests.ps1'
    )

    $logsDir = Join-Path $repoRoot 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    }
    $resultsPath = Join-Path $logsDir 'ps-module-pins-results.json'

    # Build a single regex alternation of managed module names (escaped).
    $moduleAlt = ($canonical.Keys | ForEach-Object { [regex]::Escape($_) }) -join '|'

    # Patterns:
    #   1. Install/Import/Update-Module -Name <Mod> ... -RequiredVersion <ver>
    #   2. #Requires-style hashtable: ModuleName='<Mod>' ... RequiredVersion='<ver>'
    $patterns = @(
        "(?<verb>Install-Module|Import-Module|Update-Module)\s+(?:-Name\s+)?['""]?(?<module>$moduleAlt)['""]?[^\r\n#]*?-RequiredVersion\s+['""]?(?<version>\d+\.\d+\.\d+)['""]?",
        "ModuleName\s*=\s*['""](?<module>$moduleAlt)['""]\s*;\s*RequiredVersion\s*=\s*['""](?<version>\d+\.\d+\.\d+)['""]"
    )

    # Enumerate tracked files only (avoid logs/, node_modules/, .git/, build outputs).
    Push-Location $repoRoot
    try {
        $trackedFiles = git ls-files | Where-Object {
            $_ -match '\.(ps1|psm1|psd1|yml|yaml|sh|md)$'
        }
    } finally {
        Pop-Location
    }

    $violations = [System.Collections.Generic.List[object]]::new()
    $matchesFound = 0

    foreach ($relPath in $trackedFiles) {
        if ($allowedFiles -contains $relPath) { continue }

        $full = Join-Path $repoRoot $relPath
        if (-not (Test-Path -LiteralPath $full)) { continue }

        $lines = @(Get-Content -LiteralPath $full)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            foreach ($pattern in $patterns) {
                $rxMatches = [regex]::Matches($line, $pattern)
                foreach ($m in $rxMatches) {
                    $matchesFound++
                    $module = $m.Groups['module'].Value
                    $version = $m.Groups['version'].Value
                    $expected = $canonical[$module]
                    if ($version -ne $expected) {
                        $violations.Add([pscustomobject]@{
                            file     = $relPath
                            line     = $i + 1
                            module   = $module
                            found    = $version
                            expected = $expected
                            snippet  = $line.Trim()
                        }) | Out-Null
                    }
                }
            }
        }
    }

    $result = [pscustomobject]@{
        configPath       = (Resolve-Path -LiteralPath $ConfigPath).Path
        canonical        = $canonical
        filesScanned     = $trackedFiles.Count
        pinsFound        = $matchesFound
        violationCount   = $violations.Count
        violations       = $violations
        allowedFiles     = $allowedFiles
    }

    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultsPath -Encoding utf8

    if ($violations.Count -gt 0) {
        Write-Host "PowerShell module pin violations:" -ForegroundColor Red
        foreach ($v in $violations) {
            Write-Host ("  {0}:{1}  {2} expected {3}, found {4}" -f $v.file, $v.line, $v.module, $v.expected, $v.found) -ForegroundColor Red
            Write-Host ("    > {0}" -f $v.snippet) -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "Canonical versions defined in: $ConfigPath" -ForegroundColor Yellow
        Write-Host "Results written to: $resultsPath" -ForegroundColor Yellow
        return 1
    }

    Write-Host ("OK: {0} module pin(s) across {1} file(s) match canonical versions in {2}" -f $matchesFound, $trackedFiles.Count, (Split-Path -Leaf $ConfigPath)) -ForegroundColor Green
    Write-Host "Results: $resultsPath"
    return 0
}
#endregion

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $exitCode = Invoke-PSModulePinScan @PSBoundParameters
        exit $exitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Test-PSModulePins failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion
