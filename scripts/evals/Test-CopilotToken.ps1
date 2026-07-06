#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Pre-flight probe for the COPILOT_GITHUB_TOKEN secret used by vally evals.

.DESCRIPTION
    Validates that `COPILOT_GITHUB_TOKEN` is present and well-formed before
    `vally eval` runs in CI. Classic personal access tokens (prefix `ghp_`)
    are rejected because the `@github/copilot` CLI does not accept them; the
    accepted forms are `ghs_` (GitHub App installation tokens) and
    `github_pat_` (fine-grained PATs).

    With `-SmokeTest`, the probe additionally invokes `vally --version` to
    confirm the CLI is reachable with the token in scope. When `vally` is not
    installed locally, the smoke test is reported as a clean skip rather than
    a failure so the script remains usable for contributors working outside
    CI.

    Exit codes:
      0 = token present and well-formed (and CLI reachable when -SmokeTest is set or skipped cleanly).
      1 = token missing, classic PAT detected, or smoke test failed.

.PARAMETER SmokeTest
    Also invoke `vally --version` to confirm the CLI is reachable. A missing
    `vally` executable is reported as a skip, not a failure.

.PARAMETER RepoRoot
    Repository root. Defaults to git's top-level or this script's parent directory.

.EXAMPLE
    ./Test-CopilotToken.ps1
    Validate the token without invoking the CLI.

.EXAMPLE
    pwsh scripts/evals/Test-CopilotToken.ps1 -SmokeTest
    Validate the token and also run `vally --version`.

.NOTES
    Reference: docs/contributing/evals-ci.md
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SmokeTest,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

if (-not $PSBoundParameters.ContainsKey('RepoRoot') -or [string]::IsNullOrWhiteSpace($RepoRoot)) {
    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $RepoRoot = $gitRoot
    } else {
        $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    }
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepoRoot 'scripts/lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Get-CopilotTokenProbeResult {
    <#
    .SYNOPSIS
        Validate the COPILOT_GITHUB_TOKEN env var and optionally probe the vally CLI.
    .DESCRIPTION
        Returns a hashtable with Status (pass|fail), Reason describing the
        outcome, and SmokeResult capturing CLI invocation state
        (not-run|skipped|<version-string>|error).
    .PARAMETER RunSmokeTest
        When set, attempt to invoke `vally --version`. A missing `vally`
        executable is reported as a skip.
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$RunSmokeTest
    )

    $token = $env:COPILOT_GITHUB_TOKEN
    $tokenSource = 'COPILOT_GITHUB_TOKEN'

    if ([string]::IsNullOrWhiteSpace($token)) {
        $gh = Get-Command -Name 'gh' -ErrorAction SilentlyContinue
        if ($gh) {
            try {
                $ghToken = & gh auth token 2>$null
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($ghToken)) {
                    $token = ($ghToken | Out-String).Trim()
                    $tokenSource = 'gh auth token'
                }
            }
            catch {
                Write-Verbose "gh auth token invocation failed: $($_.Exception.Message)"
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($token)) {
        return @{
            Status      = 'fail'
            Reason      = 'COPILOT_GITHUB_TOKEN not set and gh auth token unavailable'
            SmokeResult = 'not-run'
        }
    }

    if ($token.StartsWith('ghp_')) {
        return @{
            Status      = 'fail'
            Reason      = 'classic PAT not supported by @github/copilot CLI'
            SmokeResult = 'not-run'
        }
    }

    if (-not $RunSmokeTest) {
        return @{
            Status      = 'pass'
            Reason      = "token present and well-formed (source: $tokenSource)"
            SmokeResult = 'not-run'
        }
    }

    $vally = Get-Command -Name 'vally' -ErrorAction SilentlyContinue
    if (-not $vally) {
        return @{
            Status      = 'pass'
            Reason      = "token present and well-formed (source: $tokenSource); vally CLI not installed, smoke test skipped"
            SmokeResult = 'skipped'
        }
    }

    try {
        $output = & vally --version 2>&1
        $exit = $LASTEXITCODE
        $captured = ($output | Out-String).Trim()

        if ($exit -ne 0) {
            return @{
                Status      = 'fail'
                Reason      = "vally --version exited $exit"
                SmokeResult = $captured
            }
        }

        return @{
            Status      = 'pass'
            Reason      = "token present and vally CLI reachable (source: $tokenSource)"
            SmokeResult = $captured
        }
    }
    catch {
        return @{
            Status      = 'fail'
            Reason      = "vally --version invocation failed: $($_.Exception.Message)"
            SmokeResult = 'error'
        }
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Get-CopilotTokenProbeResult -RunSmokeTest:$SmokeTest

        if ($result.Status -eq 'pass') {
            Write-Host "PASS COPILOT_GITHUB_TOKEN probe: $($result.Reason)" -ForegroundColor Green
            if ($result.SmokeResult -and $result.SmokeResult -notin @('not-run', 'skipped')) {
                Write-Host "     vally --version: $($result.SmokeResult)" -ForegroundColor DarkGray
            }
            exit 0
        }

        Write-CIAnnotation -Level 'Error' -Message $result.Reason
        Write-Host "FAIL COPILOT_GITHUB_TOKEN probe: $($result.Reason)" -ForegroundColor Red
        exit 1
    }
    catch {
        Write-CIAnnotation -Level 'Error' -Message "Test-CopilotToken probe encountered an error: $($_.Exception.Message)"
        Write-Error -ErrorAction Continue "Test-CopilotToken failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
