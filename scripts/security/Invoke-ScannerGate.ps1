#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Invoke-ScannerGate.ps1
#
# Purpose: Run one SARIF scanner and decide its result with the code-scanning
#          exception gate, the same way the owning CI workflow does.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Runs a SARIF scanner, then gates its findings on the exception register.

.DESCRIPTION
    CI runs the workflow validator, the tool-version check, and the dependency
    pinning scan to SARIF, then fails only on findings that
    security/code-scanning-exceptions.yml does not excuse. This script does the
    same locally so a branch whose findings are all excused passes, and a branch
    with a new finding or a stale exception fails.

    The scanner's own findings exit code is ignored. The scanner counts as failed
    when it exits with a code it never uses for findings, or when it writes no
    SARIF. The script exits with the gate's exit code, or 1 when the scanner failed.

.PARAMETER Scanner
    workflows, tool-version-consistency, or dependency-pinning.

.PARAMETER RepoRoot
    Repository root. Defaults to the git top-level directory.

.PARAMETER ExceptionsPath
    Exception register passed to the gate. Defaults to the gate's own default.

.EXAMPLE
    ./scripts/security/Invoke-ScannerGate.ps1 -Scanner workflows
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('workflows', 'tool-version-consistency', 'dependency-pinning')]
    [string]$Scanner,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$ExceptionsPath
)

$ErrorActionPreference = 'Stop'

function Get-ScannerDefinition {
    <#
    .SYNOPSIS
        Returns the SARIF path, command, and findings exit codes for one scanner.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('workflows', 'tool-version-consistency', 'dependency-pinning')]
        [string]$Scanner
    )

    switch ($Scanner) {
        'workflows' {
            # Exit 2 means validation could not run.
            return @{
                SarifPath = 'logs/workflow-validation.sarif'
                ExitCodes = @(0, 1)
                Command   = { param($sarif) node scripts/linting/workflow-validator/validate-workflows.mjs --sarif $sarif }
            }
        }
        'tool-version-consistency' {
            return @{
                SarifPath = 'logs/tool-version-consistency.sarif'
                ExitCodes = @(0, 1)
                Command   = { param($sarif) & ./scripts/security/Test-ToolVersionConsistency.ps1 -SarifPath $sarif }
            }
        }
        'dependency-pinning' {
            return @{
                SarifPath = 'logs/dependency-pinning-results.sarif'
                ExitCodes = @(0)
                Command   = { param($sarif) & ./scripts/security/Test-DependencyPinning.ps1 -Path . -Format sarif -OutputPath $sarif }
            }
        }
    }
}

function Invoke-ScannerGate {
    <#
    .SYNOPSIS
        Runs a scanner definition and the exception gate. Returns the exit code.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][hashtable]$Definition,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $false)][string]$ExceptionsPath
    )

    $gate = Join-Path $PSScriptRoot 'Test-CodeQLSarifThreshold.ps1'
    Push-Location -LiteralPath $RepoRoot
    try {
        $sarif = $Definition.SarifPath
        New-Item -ItemType Directory -Path (Split-Path -Parent $sarif) -Force | Out-Null
        Remove-Item -LiteralPath $sarif -ErrorAction Ignore

        $global:LASTEXITCODE = 0
        & $Definition.Command $sarif | Out-Host
        $scanExit = $LASTEXITCODE
        if ($scanExit -notin $Definition.ExitCodes) {
            Write-Error -ErrorAction Continue "$Name scan failed to run (exit $scanExit)."
            return 1
        }
        if (-not (Test-Path -LiteralPath $sarif -PathType Leaf)) {
            Write-Error -ErrorAction Continue "$Name scan produced no SARIF at $sarif."
            return 1
        }

        $gateArgs = @{ SarifPath = $sarif; Threshold = 'All' }
        if ($ExceptionsPath) { $gateArgs['ExceptionsPath'] = $ExceptionsPath }
        $global:LASTEXITCODE = 0
        & $gate @gateArgs | Out-Host
        return [int]$LASTEXITCODE
    }
    finally {
        Pop-Location
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $Scanner) { throw 'Scanner is required.' }
        if (-not $RepoRoot) {
            $RepoRoot = git rev-parse --show-toplevel 2>$null
            if (-not $RepoRoot) { $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
        }
        $code = Invoke-ScannerGate -Name $Scanner -Definition (Get-ScannerDefinition -Scanner $Scanner) -RepoRoot $RepoRoot -ExceptionsPath $ExceptionsPath
        exit $code
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-ScannerGate failed: $($_.Exception.Message)"
        exit 1
    }
}
