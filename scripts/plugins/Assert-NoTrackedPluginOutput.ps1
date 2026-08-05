#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Rejects tracked plugin output and symbolic links.
.DESCRIPTION
    Inspects the current Git index and fails when any path under plugins/ is
    tracked or any index entry uses symbolic-link mode 120000.
.PARAMETER RepoRoot
    Repository root whose index is inspected.
.EXAMPLE
    ./Assert-NoTrackedPluginOutput.ps1
.NOTES
    Runs via: npm run lint:plugin-output
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null) ?? $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

#region Functions

function Assert-NoTrackedPluginOutput {
    <#
    .SYNOPSIS
        Verifies that the current index contains no plugin output or links.
    .PARAMETER RepoRoot
        Repository root whose index is inspected.
    .OUTPUTS
        [hashtable] Counts for the inspected and rejected index entries.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $indexOutput = @(& git -C $RepoRoot -c core.quotePath=false ls-files --cached --stage --full-name 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the Git index in '$RepoRoot': $($indexOutput -join ' ')"
    }

    $trackedPluginPaths = [System.Collections.Generic.List[string]]::new()
    $symbolicLinkPaths = [System.Collections.Generic.List[string]]::new()
    $entryCount = 0

    foreach ($line in $indexOutput) {
        if ([string]::IsNullOrWhiteSpace([string]$line)) {
            continue
        }

        if ([string]$line -notmatch '^(?<Mode>\d{6})\s+[0-9a-f]+\s+\d+\t(?<Path>.+)$') {
            throw "Unable to parse Git index entry: $line"
        }

        $entryCount++
        $path = $Matches.Path -replace '\\', '/'
        if ($path -eq 'plugins' -or $path.StartsWith('plugins/', [System.StringComparison]::Ordinal)) {
            $trackedPluginPaths.Add($path)
        }
        if ($Matches.Mode -eq '120000') {
            $symbolicLinkPaths.Add($path)
        }
    }

    $violations = [System.Collections.Generic.List[string]]::new()
    if ($trackedPluginPaths.Count -gt 0) {
        $violations.Add("Tracked plugin output is forbidden: $($trackedPluginPaths -join ', ')")
    }
    if ($symbolicLinkPaths.Count -gt 0) {
        $violations.Add("Symbolic-link mode 120000 is forbidden: $($symbolicLinkPaths -join ', ')")
    }
    if ($violations.Count -gt 0) {
        throw ($violations -join ' ')
    }

    return @{
        EntryCount              = $entryCount
        TrackedPluginPathCount  = $trackedPluginPaths.Count
        SymbolicLinkPathCount   = $symbolicLinkPaths.Count
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Assert-NoTrackedPluginOutput -RepoRoot $RepoRoot
        Write-Host "Git index contains no tracked plugin output or symbolic links ($($result.EntryCount) entries inspected)." -ForegroundColor Green
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Plugin output guard failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution