#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Runs pip-audit against Python project dependencies for vulnerability scanning.

.DESCRIPTION
    Discovers Python projects containing pyproject.toml files, exports locked dependencies
    via uv export, and runs pip-audit to check for known vulnerabilities. Results are written
    as JSON to the logs directory.

.PARAMETER Path
    Root path to scan for Python projects. Defaults to repository root.

.PARAMETER OutputPath
    Directory for JSON results. Defaults to 'logs' under repository root.

.PARAMETER FailOnVulnerability
    Exit with error code if vulnerabilities are found. Default is false.

.PARAMETER ExcludePaths
    Comma-separated list of path patterns to exclude from scanning.

.EXAMPLE
    ./Invoke-PipAudit.ps1
    Scan all Python projects and report results.

.EXAMPLE
    ./Invoke-PipAudit.ps1 -FailOnVulnerability
    Scan and fail if any vulnerabilities are found.

.EXAMPLE
    ./Invoke-PipAudit.ps1 -Path ".github/skills/experimental/powerpoint"
    Scan a specific Python project directory.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),

    [Parameter()]
    [string]$OutputPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'logs'),

    [Parameter()]
    [switch]$FailOnVulnerability,

    [Parameter()]
    [string[]]$ExcludePaths = @()
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

function Find-PythonProjects {
    <#
    .SYNOPSIS
        Discovers Python projects containing pyproject.toml files.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SearchPath,

        [Parameter()]
        [string[]]$Exclude = @()
    )

    @(Get-ChildItem -Path $SearchPath -Recurse -Force -Filter pyproject.toml |
        Where-Object { $_.FullName -notmatch 'node_modules' } |
        ForEach-Object { $_.DirectoryName } |
        Where-Object {
            $dir = $_
            $excluded = $false
            foreach ($pattern in $Exclude) {
                if ($dir -like "*$pattern*") { $excluded = $true; break }
            }
            -not $excluded
        } |
        Sort-Object)
}

function Invoke-PipAuditForProject {
    <#
    .SYNOPSIS
        Runs pip-audit against a single Python project directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $name = (Resolve-Path -Relative $ProjectPath) -replace '[\\/]', '-' -replace '^\.', '' -replace '^-', ''
    $requirementsFile = Join-Path ([System.IO.Path]::GetTempPath()) "requirements-$name.txt"
    $resultsFile = Join-Path $OutputPath "pip-audit-$name.json"

    Write-Host "Auditing: $ProjectPath"

    # Export locked dependencies
    Push-Location $ProjectPath
    try {
        uv export --format requirements-txt --no-hashes > $requirementsFile
    } finally {
        Pop-Location
    }

    # Run pip-audit; finally block ensures temp file cleanup on terminating errors
    try {
        uvx pip-audit@2.10.0 `
            -r $requirementsFile `
            --no-deps `
            --format json `
            -o $resultsFile `
            --desc on `
            --aliases on `
            --progress-spinner off `
            --strict

        $exitCode = $LASTEXITCODE
    } finally {
        if (Test-Path $requirementsFile) { Remove-Item $requirementsFile }
    }

    if ($exitCode -ne 0) {
        Write-Host "::warning::Vulnerabilities found in $ProjectPath"
        return $true  # has vulnerabilities
    }

    Write-Host "No vulnerabilities found in $ProjectPath"
    return $false
}

function Start-PipAudit {
    <#
    .SYNOPSIS
        Orchestrates pip-audit scanning across discovered Python projects.
    .OUTPUTS
        System.Int32 - 0 for success, 1 when vulnerabilities found and FailOnVulnerability is set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SearchPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [switch]$FailOnVulnerability,

        [Parameter()]
        [string[]]$ExcludePaths = @()
    )

    $projects = @(Find-PythonProjects -SearchPath $SearchPath -Exclude $ExcludePaths)

    if ($projects.Count -eq 0) {
        Write-Host 'No Python projects found'
        return 0
    }

    Write-Host "Found $($projects.Count) Python project(s)"

    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

    $hasVulnerabilities = $false

    foreach ($project in $projects) {
        if (Invoke-PipAuditForProject -ProjectPath $project -OutputPath $OutputPath) {
            $hasVulnerabilities = $true
        }
    }

    Write-Host "Results written to $OutputPath"

    if ($hasVulnerabilities -and $FailOnVulnerability) {
        Write-Host '::error::pip-audit found vulnerabilities in one or more Python projects'
        return 1
    }

    return 0
}

# Dot-source guard: skip main execution when dot-sourced for testing
if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-PipAudit -SearchPath $Path -OutputPath $OutputPath -FailOnVulnerability:$FailOnVulnerability -ExcludePaths $ExcludePaths
    if ($result -ne 0) { exit $result }
}
