#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Classifies devcontainer file changes and generates a markdown summary.

.DESCRIPTION
    Analyzes git diff output to identify changed devcontainer infrastructure files,
    classifies each by category and pre-build impact, and produces a markdown summary
    table. In CI, writes to GITHUB_STEP_SUMMARY; locally, writes to stdout.

.PARAMETER CommitSha
    The commit SHA to diff against. Defaults to HEAD when not specified.

.PARAMETER BranchName
    The branch name for display in the summary header.

.PARAMETER EventName
    The GitHub event name that triggered the workflow. Defaults to 'local'.

.PARAMETER BeforeSha
    The before-push SHA for computing the diff range.

.PARAMETER RepoRoot
    Root directory of the repository. Defaults to git toplevel or script directory.

.EXAMPLE
    ./Write-DevcontainerChangeLog.ps1
    Generate a local devcontainer change summary for the current HEAD.

.EXAMPLE
    ./Write-DevcontainerChangeLog.ps1 -CommitSha "abc123" -BeforeSha "def456" -BranchName "main" -EventName "push"
    Generate a change summary for a specific commit range in CI.

.NOTES
    Runs via: npm run devcontainer:changelog (when configured)
    Replaces inline bash in .github/workflows/devcontainer-change-log.yml
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CommitSha,

    [Parameter(Mandatory = $false)]
    [string]$BranchName,

    [Parameter(Mandatory = $false)]
    [string]$EventName = 'local',

    [Parameter(Mandatory = $false)]
    [string]$BeforeSha,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (git rev-parse --show-toplevel 2>$null)
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) { $RepoRoot = $PSScriptRoot }

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Get-DevcontainerFileClassification {
    <#
    .SYNOPSIS
        Classifies a devcontainer file path by category and impact.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    switch -Wildcard ($FilePath) {
        '.devcontainer/scripts/on-create.sh' { return @{ Category = 'Lifecycle Scripts'; Impact = 'High' } }
        '.devcontainer/scripts/post-create.sh' { return @{ Category = 'Lifecycle Scripts'; Impact = 'Low' } }
        { $_ -like '.devcontainer/Dockerfile*' -or $_ -like '.devcontainer/*.dockerfile' } { return @{ Category = 'Base Image'; Impact = 'High' } }
        '.devcontainer/features/*' { return @{ Category = 'Features'; Impact = 'Medium' } }
        '.devcontainer/devcontainer.json' { return @{ Category = 'Config'; Impact = 'High' } }
        '.devcontainer/devcontainer-lock.json' { return @{ Category = 'Lockfile'; Impact = 'Medium' } }
        '.github/workflows/copilot-setup-steps.yml' { return @{ Category = 'Setup Steps'; Impact = 'Medium' } }
        '.devcontainer/*' { return @{ Category = 'Config'; Impact = 'Medium' } }
        default { return @{ Category = 'Other'; Impact = 'Unknown' } }
    }
}

function New-DevcontainerChangeSummary {
    <#
    .SYNOPSIS
        Builds a markdown change summary for devcontainer infrastructure files.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CommitSha,

        [Parameter(Mandatory = $false)]
        [string]$BranchName,

        [Parameter(Mandatory = $false)]
        [string]$EventName = 'local',

        [Parameter(Mandatory = $false)]
        [string]$BeforeSha,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot
    )

    if ([string]::IsNullOrWhiteSpace($CommitSha)) {
        $CommitSha = git -C $RepoRoot rev-parse HEAD 2>$null
    }
    if ([string]::IsNullOrWhiteSpace($BranchName)) {
        $BranchName = git -C $RepoRoot rev-parse --abbrev-ref HEAD 2>$null
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('## Devcontainer Infrastructure Changes')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Property | Value |')
    [void]$sb.AppendLine('|----------|-------|')
    [void]$sb.AppendLine("| Commit | ``$CommitSha`` |")
    [void]$sb.AppendLine("| Branch | ``$BranchName`` |")
    [void]$sb.AppendLine("| Trigger | ``$EventName`` |")
    [void]$sb.AppendLine('')

    if ($EventName -eq 'workflow_dispatch') {
        [void]$sb.AppendLine('_Triggered via workflow_dispatch. No push range available for automatic diff._')
        return $sb.ToString()
    }

    if ($BeforeSha -eq '0000000000000000000000000000000000000000') {
        [void]$sb.AppendLine('_Initial push to branch -- no prior commit range available._')
        return $sb.ToString()
    }

    if ([string]::IsNullOrWhiteSpace($BeforeSha)) {
        # Local run without a before SHA -- diff HEAD~1 as a reasonable default
        $BeforeSha = git -C $RepoRoot rev-parse 'HEAD~1' 2>$null
        if ($LASTEXITCODE -ne 0) {
            [void]$sb.AppendLine('_No prior commit available for diff (initial commit?)._')
            return $sb.ToString()
        }
    }

    $changed = git -C $RepoRoot diff --name-only $BeforeSha $CommitSha -- '.devcontainer/' '.github/workflows/copilot-setup-steps.yml' 2>&1
    if ($LASTEXITCODE -ne 0) {
        [void]$sb.AppendLine("_Could not compute diff: ``$BeforeSha`` may not be reachable (force push?)._")
        return $sb.ToString()
    }

    $files = ($changed -split "`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if (-not $files -or $files.Count -eq 0) {
        [void]$sb.AppendLine('_No devcontainer infrastructure files changed in this push._')
        return $sb.ToString()
    }

    [void]$sb.AppendLine('| File | Category | Pre-build Impact |')
    [void]$sb.AppendLine('|------|----------|-----------------|')
    foreach ($file in $files) {
        $classification = Get-DevcontainerFileClassification -FilePath $file
        [void]$sb.AppendLine("| ``$file`` | $($classification.Category) | $($classification.Impact) |")
    }

    return $sb.ToString()
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $markdown = New-DevcontainerChangeSummary -CommitSha $CommitSha -BranchName $BranchName -EventName $EventName -BeforeSha $BeforeSha -RepoRoot $RepoRoot

        if ($env:GITHUB_STEP_SUMMARY) {
            $markdown | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Append -Encoding UTF8
        }
        else {
            Write-Output $markdown
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Write-DevcontainerChangeLog failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
