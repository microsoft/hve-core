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
    Reports each tracked code-scanning exception with its expiry, alert, and upstream state.

.DESCRIPTION
    Reads security/code-scanning-exceptions.yml and, for each entry, reports the
    tool, rule, path, pinned count, kind, upstream report, linked issue, owner,
    expiry, days left, how many open code-scanning alerts for that tool, rule, and
    path exist on the branch, and whether the upstream report is still open.

    The weekly code-scanning issue workflow uses this output to update one status
    comment on each exception's issue, to flag an exception whose upstream report
    has closed, and to file a new issue when the linked issue is closed while the
    alert is still open. Validation of the entries is owned by
    Test-CodeQLSarifThreshold.ps1; entries without a tool, rule, path, or issue
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

function Read-ExceptionEntry {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExceptionsPath
    )

    if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
        Import-Module powershell-yaml -ErrorAction Stop
    }
    $document = Get-Content -Raw -LiteralPath $ExceptionsPath | ConvertFrom-Yaml
    if ($document -is [System.Collections.IDictionary] -and $null -ne $document['exceptions']) {
        return , @($document['exceptions'])
    }
    return , @()
}

function Get-GitHubIssueApiPath {
    <#
    .SYNOPSIS
        Converts a GitHub issue or pull request URL to its REST API path, or returns $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Url
    )

    if ($Url -match '^https://github\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/(?:issues|pull)/(\d+)/?$') {
        return "repos/$($Matches[1])/$($Matches[2])/issues/$($Matches[3])"
    }
    return $null
}

function Get-CodeScanningExceptionStatus {
    <#
    .SYNOPSIS
        Builds a status record for each tracked exception.
    .OUTPUTS
        PSCustomObject[] with Tool, Rule, Path, Count, Kind, Upstream, UpstreamState,
        Issue, Owner, Reason, Expires, DaysLeft, AlertOpen, OpenAlertCount, and AlertUrl.
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
        [datetime]$CheckDate,

        # Upstream URL to state ('open', 'closed', or 'unknown'). Missing URLs report 'unknown'.
        [Parameter(Mandatory = $false)]
        [hashtable]$UpstreamStates = @{}
    )

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in (Read-ExceptionEntry -ExceptionsPath $ExceptionsPath)) {
        if ($entry -isnot [System.Collections.IDictionary]) { continue }
        $issue = 0
        if (-not $entry['tool'] -or -not $entry['rule'] -or -not $entry['path'] -or -not [int]::TryParse("$($entry['issue'])", [ref]$issue) -or $issue -le 0) {
            Write-Warning "Skipping exception without a tool, rule, path, or issue number: $($entry['tool']) $($entry['rule']) $($entry['path'])"
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

        $tool = [string]$entry['tool']
        $rule = [string]$entry['rule']
        $path = [string]$entry['path']
        $alerts = @($OpenAlerts | Where-Object {
                $_.tool.name -ceq $tool -and $_.rule.id -ceq $rule -and $_.most_recent_instance.location.path -ceq $path
            })
        $count = 0
        [void][int]::TryParse("$($entry['count'])", [ref]$count)
        $upstream = [string]$entry['upstream']
        $upstreamState = if ($UpstreamStates.ContainsKey($upstream)) { [string]$UpstreamStates[$upstream] } else { 'unknown' }

        $records.Add([pscustomobject]@{
                Tool           = $tool
                Rule           = $rule
                Path           = $path
                Count          = $count
                Kind           = [string]$entry['kind']
                Upstream       = $upstream
                UpstreamState  = $upstreamState
                Issue          = $issue
                Owner          = [string]$entry['owner']
                Reason         = [string]$entry['reason']
                Expires        = if ($null -ne $expires) { $expires.ToString('yyyy-MM-dd') } else { [string]$rawExpires }
                DaysLeft       = $daysLeft
                AlertOpen      = $alerts.Count -gt 0
                OpenAlertCount = $alerts.Count
                AlertUrl       = if ($alerts.Count -gt 0) { [string]$alerts[0].html_url } else { '' }
            })
    }

    return , $records.ToArray()
}

function Get-UpstreamState {
    <#
    .SYNOPSIS
        Looks up the state of each GitHub issue or pull request URL with the gh CLI.
    .OUTPUTS
        Hashtable of URL to 'open', 'closed', or 'unknown'.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Url
    )

    $states = @{}
    foreach ($item in ($Url | Where-Object { $_ } | Sort-Object -Unique)) {
        $apiPath = Get-GitHubIssueApiPath -Url $item
        $state = 'unknown'
        if ($apiPath) {
            $raw = gh api $apiPath --jq '.state' 2>$null
            if ($LASTEXITCODE -eq 0 -and "$raw".Trim() -in @('open', 'closed')) { $state = "$raw".Trim() }
        }
        $states[$item] = $state
    }
    return $states
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
        $upstreamUrls = @(Read-ExceptionEntry -ExceptionsPath $ExceptionsPath | Where-Object { $_ -is [System.Collections.IDictionary] } | ForEach-Object { [string]$_['upstream'] })
        $upstreamStates = Get-UpstreamState -Url $upstreamUrls
        $status = Get-CodeScanningExceptionStatus -ExceptionsPath $ExceptionsPath -OpenAlerts $alerts -CheckDate $CheckDate -UpstreamStates $upstreamStates
        # The array wrapper keeps the output a JSON array for every result size.
        ConvertTo-Json -InputObject @($status) -Depth 3
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Get-CodeScanningExceptionStatus failed: $($_.Exception.Message)"
        exit 1
    }
}
