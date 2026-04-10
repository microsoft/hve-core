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
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter()]
    [string]$Branch = 'main',

    [Parameter()]
    [ValidateSet('Table', 'Json', 'GroupedJson')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'
$env:GH_PAGER = ''

$url = "repos/$Owner/$Repo/code-scanning/alerts?state=open&ref=refs/heads/$Branch&per_page=100"
$raw = gh api $url --paginate 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "gh api call failed (exit $LASTEXITCODE): $raw"
}

$alerts = $raw | ConvertFrom-Json

$grouped = $alerts |
    Group-Object { $_.rule.description } |
    ForEach-Object {
        [PSCustomObject]@{
            RuleDescription  = $_.Name
            RuleId           = $_.Group[0].rule.id
            Tool             = $_.Group[0].tool.name
            SecuritySeverity = $_.Group[0].rule.security_severity_level
            Count            = $_.Count
            SamplePaths      = ($_.Group | ForEach-Object { $_.most_recent_instance.location.path } | Sort-Object -Unique)
        }
    } |
    Sort-Object -Property Count -Descending

switch ($OutputFormat) {
    'Table' {
        $grouped | Format-Table -AutoSize -Property Count, SecuritySeverity, RuleId, RuleDescription
    }
    { $_ -in 'Json', 'GroupedJson' } {
        $grouped | ConvertTo-Json -Depth 5
    }
}
