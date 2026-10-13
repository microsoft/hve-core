#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Retrieves open code scanning alerts from a GitHub repository, grouped by rule.

.DESCRIPTION
    Uses the gh CLI to fetch open code scanning alerts for a repository and branch,
    suppressing the pager for non-interactive output. Results are grouped by rule
    description and sorted by occurrence count descending.

    Requires gh CLI authenticated with security_events scope (or public_repo for public repos).

.PARAMETER Owner
    GitHub organization or user name (e.g., 'microsoft').

.PARAMETER Repo
    Repository name without the owner (e.g., 'edge-ai').

.PARAMETER Branch
    Branch name to scope alerts to. Defaults to 'main'.

.PARAMETER OutputFormat
    Output format: Table (default), Json, or GroupedJson.
    - Table: Human-readable summary table.
    - Json: Full grouped alert objects as JSON array.
    - GroupedJson: Alias for Json; produces the same output.

.PARAMETER IncludeDismissedStillDetected
    Also report alerts that were dismissed but are still detected on the branch,
    meaning their most recent instance on the branch is not fixed. These groups
    are appended after the open-alert groups and carry
    Kind = 'dismissed-still-detected' and the DismissedReason of their first alert.
    Open-alert groups are unchanged. A dismissal never resolves an alert, so these
    alerts need to be reopened and resolved.

.EXAMPLE
    ./Get-CodeScanningAlerts.ps1 -Owner microsoft -Repo edge-ai

.EXAMPLE
    ./Get-CodeScanningAlerts.ps1 -Owner microsoft -Repo edge-ai -Branch develop -OutputFormat Json

.EXAMPLE
    ./Get-CodeScanningAlerts.ps1 -Owner microsoft -Repo edge-ai -OutputFormat Json -IncludeDismissedStillDetected
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$', ErrorMessage = 'Owner must contain only alphanumeric characters, dots, hyphens, or underscores.')]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$', ErrorMessage = 'Repo must contain only alphanumeric characters, dots, hyphens, or underscores.')]
    [string]$Repo,

    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._/-]+$', ErrorMessage = 'Branch must contain only alphanumeric characters, dots, hyphens, underscores, or slashes.')]
    [string]$Branch = 'main',

    [Parameter()]
    [ValidateSet('Table', 'Json', 'GroupedJson')]
    [string]$OutputFormat = 'Table',

    [Parameter()]
    [switch]$IncludeDismissedStillDetected
)

$ErrorActionPreference = 'Stop'

function Get-AlertPage {
    param([Parameter(Mandatory = $true)][string]$Url)

    $raw = gh api $Url --paginate --jq '.[]'

    if ($LASTEXITCODE -ne 0) {
        if ($raw -match '403|Resource not accessible by integration') {
            Write-Error "gh api call failed: missing required scope. Run 'gh auth refresh -s security_events' and re-run this script."
        }
        Write-Error "gh api call failed (exit $LASTEXITCODE): $raw"
    }

    return , @($raw | ConvertFrom-Json)
}

function ConvertTo-AlertGroup {
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Alerts)

    $Alerts |
        Group-Object { $_.rule.description } |
        ForEach-Object {
            $paths = @(
                $_.Group |
                ForEach-Object { $_.most_recent_instance.location.path } |
                Where-Object { $_ -and $_ -ne 'no file associated with this alert' } |
                Sort-Object -Unique
            )
            [PSCustomObject]@{
                RuleDescription    = $_.Name
                RuleId             = $_.Group[0].rule.id
                Tool               = $_.Group[0].tool.name
                SecuritySeverity   = $_.Group[0].rule.security_severity_level
                Severity           = $_.Group[0].rule.severity
                Count              = $_.Count
                AffectedPaths      = $paths
                HasFilePaths       = ($paths.Count -gt 0)
                AlertUrl           = $_.Group[0].html_url
                FindingDescription = $_.Group[0].most_recent_instance.message.text
            }
        } |
        Sort-Object -Property Count -Descending
}

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    $env:GH_PAGER = ''

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "gh CLI not found. Install it from https://cli.github.com and re-run this script."
    }

    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh CLI is not authenticated. Run 'gh auth login' and ensure the 'security_events' scope is granted, then re-run this script."
    }

    $Url = "repos/$Owner/$Repo/code-scanning/alerts?state=open&ref=refs/heads/$Branch&per_page=100"
    $Alerts = Get-AlertPage -Url $Url
    $Grouped = @(ConvertTo-AlertGroup -Alerts $Alerts)

    if ($IncludeDismissedStillDetected) {
        # The ref filter scopes most_recent_instance to the branch. A dismissed alert
        # whose instance there is not 'fixed' is still being detected.
        $DismissedUrl = "repos/$Owner/$Repo/code-scanning/alerts?state=dismissed&ref=refs/heads/$Branch&per_page=100"
        $Dismissed = Get-AlertPage -Url $DismissedUrl
        $StillDetected = @($Dismissed | Where-Object { $_.most_recent_instance.state -ne 'fixed' })
        foreach ($group in @(ConvertTo-AlertGroup -Alerts $StillDetected)) {
            $first = $StillDetected | Where-Object { $_.rule.id -eq $group.RuleId } | Select-Object -First 1
            $group | Add-Member -NotePropertyName Kind -NotePropertyValue 'dismissed-still-detected'
            $group | Add-Member -NotePropertyName DismissedReason -NotePropertyValue $first.dismissed_reason
            $Grouped += $group
        }
    }

    switch ($OutputFormat) {
        'Table' {
            $columns = @('Count', 'SecuritySeverity', 'RuleId', 'RuleDescription')
            if ($IncludeDismissedStillDetected) { $columns += 'Kind' }
            $Grouped | Format-Table -AutoSize -Property $columns
        }
        { $_ -in 'Json', 'GroupedJson' } {
            # The array wrapper keeps the output a JSON array for every result size.
            # Piping to ConvertTo-Json emits a bare object for a single group and nothing at all for none.
            ConvertTo-Json -InputObject @($Grouped) -Depth 5
        }
    }

    exit 0
}

#endregion Main Execution
