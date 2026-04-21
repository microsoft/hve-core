#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

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
    - GroupedJson: Same as Json; alias retained for backward compatibility.

.EXAMPLE
    ./Get-CodeScanningAlerts.ps1 -Owner microsoft -Repo edge-ai

.EXAMPLE
    ./Get-CodeScanningAlerts.ps1 -Owner microsoft -Repo edge-ai -Branch develop -OutputFormat Json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9._/-]+$', ErrorMessage = 'Owner must contain only alphanumeric characters, dots, hyphens, underscores, or slashes.')]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$', ErrorMessage = 'Repo must contain only alphanumeric characters, dots, hyphens, or underscores.')]
    [string]$Repo,

    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._/-]+$', ErrorMessage = 'Branch must contain only alphanumeric characters, dots, hyphens, underscores, or slashes.')]
    [string]$Branch = 'main',

    [Parameter()]
    [ValidateSet('Table', 'Json', 'GroupedJson')]
    [string]$OutputFormat = 'Table'
)

if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    $env:GH_PAGER = ''

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "gh CLI not found. Install it from https://cli.github.com and re-run this script."
    }

    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh CLI is not authenticated. Run 'gh auth login' and ensure the 'security_events' scope is granted, then re-run this script."
    }

    $Url = "repos/$Owner/$Repo/code-scanning/alerts?state=open&ref=refs/heads/$Branch&per_page=100"
    $Raw = gh api $Url --paginate --jq '.[]'

    if ($LASTEXITCODE -ne 0) {
        if ($Raw -match '403|Resource not accessible by integration') {
            Write-Error "gh api call failed: missing required scope. Run 'gh auth refresh -s security_events' and re-run this script."
        }
        Write-Error "gh api call failed (exit $LASTEXITCODE): $Raw"
    }

    $Alerts = @($Raw | ConvertFrom-Json)

    $Grouped = $Alerts |
        Group-Object { $_.rule.description } |
        ForEach-Object {
            [PSCustomObject]@{
                RuleDescription  = $_.Name
                RuleId           = $_.Group[0].rule.id
                Tool             = $_.Group[0].tool.name
                SecuritySeverity = $_.Group[0].rule.security_severity_level
                Count            = $_.Count
                SamplePaths      = @($_.Group | ForEach-Object { $_.most_recent_instance.location.path } | Sort-Object -Unique)
            }
        } |
        Sort-Object -Property Count -Descending

    switch ($OutputFormat) {
        'Table' {
            $Grouped | Format-Table -AutoSize -Property Count, SecuritySeverity, RuleId, RuleDescription
        }
        { $_ -in 'Json', 'GroupedJson' } {
            $Grouped | ConvertTo-Json -Depth 5
        }
    }

    exit 0
}
