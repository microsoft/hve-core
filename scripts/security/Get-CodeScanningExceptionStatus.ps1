#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Get-CodeScanningExceptionStatus.ps1
#
# Purpose: Report the status of each tracked code-scanning exception so the weekly
#          issue workflow can keep its linked issue current.
# Author: HVE Core Team

#Requires -Version 7.4

<#
.SYNOPSIS
    Reports each tracked code-scanning exception with its expiry and alert state.

.DESCRIPTION
    Reads security/code-scanning-exceptions.yml and, for each entry, reports the
    rule, path, linked issue, owner, expiry, days left, and whether an open
    code-scanning alert for that rule and path still exists on the branch.

    The weekly code-scanning issue workflow uses this output to update one status
    comment on each exception's issue, and to file a new issue when the linked
    issue is closed while the alert is still open. Validation of the entries is
    owned by Test-CodeQLSarifThreshold.ps1; entries without a rule, path, or issue
    number are skipped here with a warning.

    Writes a JSON array to standard output. An empty exceptions list produces [].

.PARAMETER Owner
    GitHub organization or user name.

.PARAMETER Repo
    Repository name without the owner.

.PARAMETER Branch
    Branch whose open alerts are checked. Defaults to 'main'.

.PARAMETER ExceptionsPath
    Tracked exceptions file. Defaults to security/code-scanning-exceptions.yml at
    the repository root.

.PARAMETER CheckDate
    Date used for the days-left calculation. Defaults to the current UTC date.

.EXAMPLE
    ./scripts/security/Get-CodeScanningExceptionStatus.ps1 -Owner microsoft -Repo hve-core
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[a-zA-Z0-9._/-]+$')]
    [string]$Branch = 'main',

    [Parameter(Mandatory = $false)]
    [string]$ExceptionsPath,

    [Parameter(Mandatory = $false)]
    [datetime]$CheckDate = [datetime]::UtcNow.Date
)

$ErrorActionPreference = 'Stop'

function Get-CodeScanningExceptionStatus {
    <#
    .SYNOPSIS
        Builds a status record for each tracked exception.
    .OUTPUTS
        PSCustomObject[] with Rule, Path, Issue, Owner, Reason, Expires, DaysLeft,
        AlertOpen, and AlertUrl.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExceptionsPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$OpenAlerts,

        [Parameter(Mandatory = $true)]
        [datetime]$CheckDate
    )

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    $document = Get-Content -Raw -LiteralPath $ExceptionsPath | ConvertFrom-Yaml
    $entries = @()
    if ($document -is [System.Collections.IDictionary] -and $null -ne $document['exceptions']) {
        $entries = @($document['exceptions'])
    }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $entries) {
        if ($entry -isnot [System.Collections.IDictionary]) { continue }
        $issue = 0
        if (-not $entry['rule'] -or -not $entry['path'] -or -not [int]::TryParse("$($entry['issue'])", [ref]$issue) -or $issue -le 0) {
            Write-Warning "Skipping exception without a rule, path, or issue number: $($entry['rule']) $($entry['path'])"
            continue
        }

        $expires = $null
        $daysLeft = $null
        $rawExpires = $entry['expires']
        if ($rawExpires -is [datetime]) {
            $expires = $rawExpires.Date
        }
        elseif ($null -ne $rawExpires) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParseExact("$rawExpires", 'yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                $expires = $parsed.Date
            }
        }
        if ($null -ne $expires) {
            $daysLeft = [int]($expires - $CheckDate.Date).TotalDays
        }

        $rule = [string]$entry['rule']
        $path = [string]$entry['path']
        $alert = $OpenAlerts | Where-Object {
            $_.rule.id -ceq $rule -and $_.most_recent_instance.location.path -ceq $path
        } | Select-Object -First 1

        $records.Add([pscustomobject]@{
                Rule      = $rule
                Path      = $path
                Issue     = $issue
                Owner     = [string]$entry['owner']
                Reason    = [string]$entry['reason']
                Expires   = if ($null -ne $expires) { $expires.ToString('yyyy-MM-dd') } else { [string]$rawExpires }
                DaysLeft  = $daysLeft
                AlertOpen = [bool]$alert
                AlertUrl  = if ($alert) { [string]$alert.html_url } else { '' }
            })
    }

    return , $records.ToArray()
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $Owner -or -not $Repo) {
            throw 'Owner and Repo are required.'
        }
        if (-not $ExceptionsPath) {
            $repoRoot = git rev-parse --show-toplevel 2>$null
            if (-not $repoRoot) { $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent }
            $ExceptionsPath = Join-Path $repoRoot 'security/code-scanning-exceptions.yml'
        }
        if (-not (Test-Path -LiteralPath $ExceptionsPath -PathType Leaf)) {
            ConvertTo-Json -InputObject @() -Depth 3
            exit 0
        }

        $env:GH_PAGER = ''
        $raw = gh api "repos/$Owner/$Repo/code-scanning/alerts?state=open&ref=refs/heads/$Branch&per_page=100" --paginate --jq '.[]'
        if ($LASTEXITCODE -ne 0) {
            throw "gh api call failed (exit $LASTEXITCODE): $raw"
        }
        $alerts = @($raw | ConvertFrom-Json)
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath $ExceptionsPath -OpenAlerts $alerts -CheckDate $CheckDate
        # The array wrapper keeps the output a JSON array for every result size.
        ConvertTo-Json -InputObject @($status) -Depth 3
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Get-CodeScanningExceptionStatus failed: $($_.Exception.Message)"
        exit 1
    }
}
