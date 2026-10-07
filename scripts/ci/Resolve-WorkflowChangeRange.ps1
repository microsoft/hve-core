#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Resolves an immutable workflow change range or selects full validation.
.DESCRIPTION
    Derives the range base from commit structure for the triggering event and
    verifies it before any workflow lane trusts it:

    - pull_request: the base is the first parent of the checked-out test-merge
      commit, which must have exactly two parents with the second equal to the
      pull request head.
    - merge_group: the base and head come from the merge-group payload.
    - workflow_dispatch: the base is the merge base of the checked-out commit
      and origin/<default branch>.

    Every range requires a well-formed, available base that is an ancestor of
    the head and distinct from it, a head equal to the checked-out HEAD, and a
    diffable pair. Any unknown event or failed check returns full mode with
    empty commit IDs, so a base equal to the head never yields an empty range.
.PARAMETER EventName
    GitHub Actions event that triggered the calling workflow.
.PARAMETER BaseSha
    Candidate immutable base commit ID; used for merge_group events.
.PARAMETER HeadSha
    Candidate immutable head commit ID; must equal the checked-out HEAD.
.PARAMETER PullRequestHeadSha
    Pull request head commit ID; must be the second parent of the checked-out
    test-merge commit for pull_request events.
.PARAMETER DefaultBranch
    Repository default branch name; used for workflow_dispatch events.
.PARAMETER RepoRoot
    Repository directory containing the checked-out head commit.
.EXAMPLE
    ./scripts/ci/Resolve-WorkflowChangeRange.ps1 -EventName 'merge_group' -BaseSha $BaseSha -HeadSha $HeadSha
.EXAMPLE
    ./scripts/ci/Resolve-WorkflowChangeRange.ps1 -EventName 'pull_request' -HeadSha $MergeSha -PullRequestHeadSha $PrHeadSha
.NOTES
    Writes mode, base-sha, and head-sha as GitHub Actions step outputs.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$EventName = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$BaseSha = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$HeadSha = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$PullRequestHeadSha = '',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$DefaultBranch = '',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Join-Path $PSScriptRoot '../..')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function New-FullValidationResult {
    <#
    .SYNOPSIS
        Creates the fail-safe full-validation result.
    .OUTPUTS
        [pscustomobject] with empty immutable range values.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    return [pscustomobject][ordered]@{
        mode       = 'full'
        'base-sha' = ''
        'head-sha' = ''
    }
}

function Resolve-GitCommit {
    <#
    .SYNOPSIS
        Resolves an immutable candidate commit ID.
    .PARAMETER RepoRoot
        Repository directory containing the commit.
    .PARAMETER Candidate
        Candidate hexadecimal Git object ID.
    .OUTPUTS
        [string] containing the canonical commit ID, or no output when invalid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Candidate
    )

    if ($Candidate -notmatch '^(?:[0-9a-fA-F]{40}|[0-9a-fA-F]{64})$') {
        return
    }

    $ResolvedCommit = & git -C $RepoRoot rev-parse --verify --end-of-options "$Candidate`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ResolvedCommit)) {
        return
    }

    return $ResolvedCommit.Trim()
}

function Resolve-PullRequestBase {
    <#
    .SYNOPSIS
        Derives a pull request range base from the test-merge commit parents.
    .DESCRIPTION
        Returns the first parent of the merge commit only when the commit has
        exactly two parents and the second equals the pull request head. The
        payload base commit is not used because it can be stale.
    .PARAMETER RepoRoot
        Repository directory containing the commits.
    .PARAMETER MergeSha
        Canonical test-merge commit ID.
    .PARAMETER PullRequestHeadSha
        Candidate pull request head commit ID.
    .OUTPUTS
        [string] containing the first-parent commit ID, or no output when unproven.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$MergeSha,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$PullRequestHeadSha
    )

    $ResolvedPullRequestHead = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate $PullRequestHeadSha
    if ([string]::IsNullOrWhiteSpace($ResolvedPullRequestHead)) {
        return
    }

    $ParentLine = & git -C $RepoRoot rev-list --parents -n 1 --end-of-options $MergeSha 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ParentLine)) {
        return
    }

    $Parents = @(([string]$ParentLine).Trim() -split '\s+' | Select-Object -Skip 1)
    if ($Parents.Count -ne 2 -or $Parents[1] -ne $ResolvedPullRequestHead) {
        return
    }

    return $Parents[0]
}

function Resolve-DispatchBase {
    <#
    .SYNOPSIS
        Derives a manual-dispatch range base from the default branch.
    .PARAMETER RepoRoot
        Repository directory containing the commits.
    .PARAMETER HeadSha
        Canonical checked-out head commit ID.
    .PARAMETER DefaultBranch
        Repository default branch name.
    .OUTPUTS
        [string] containing the single merge base, or no output when unproven.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$HeadSha,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$DefaultBranch
    )

    if ($DefaultBranch -notmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*$') {
        return
    }

    & git -C $RepoRoot check-ref-format --branch $DefaultBranch *> $null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $DefaultBranchCommit = & git -C $RepoRoot rev-parse --verify --quiet --end-of-options "refs/remotes/origin/$DefaultBranch`^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($DefaultBranchCommit)) {
        return
    }

    $MergeBases = @(& git -C $RepoRoot merge-base --all $HeadSha $DefaultBranchCommit.Trim() 2>$null)
    if ($LASTEXITCODE -ne 0 -or $MergeBases.Count -ne 1) {
        return
    }

    return $MergeBases[0].Trim()
}

function Test-WorkflowGitAncestor {
    <#
    .SYNOPSIS
        Tests whether the base commit is an ancestor of the head commit.
    .PARAMETER RepoRoot
        Repository directory containing the commits.
    .PARAMETER BaseSha
        Canonical base commit ID.
    .PARAMETER HeadSha
        Canonical head commit ID.
    .OUTPUTS
        [bool] indicating whether Git proved the ancestry.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseSha,

        [Parameter(Mandatory = $true)]
        [string]$HeadSha
    )

    & git -C $RepoRoot merge-base --is-ancestor $BaseSha $HeadSha *> $null
    return $LASTEXITCODE -eq 0
}

function Test-WorkflowGitDiff {
    <#
    .SYNOPSIS
        Tests whether Git can compute the requested immutable range.
    .PARAMETER RepoRoot
        Repository directory containing the commits.
    .PARAMETER BaseSha
        Canonical base commit ID.
    .PARAMETER HeadSha
        Canonical head commit ID.
    .OUTPUTS
        [bool] indicating whether Git accepted the range.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseSha,

        [Parameter(Mandatory = $true)]
        [string]$HeadSha
    )

    & git -C $RepoRoot diff --name-only "$BaseSha..$HeadSha" -- *> $null
    return $LASTEXITCODE -eq 0
}

function Resolve-WorkflowChangeRange {
    <#
    .SYNOPSIS
        Resolves a verified immutable range or selects full validation.
    .PARAMETER EventName
        GitHub Actions event that triggered the calling workflow.
    .PARAMETER BaseSha
        Candidate immutable base commit ID; used for merge_group events.
    .PARAMETER HeadSha
        Candidate immutable head commit ID; must equal the checked-out HEAD.
    .PARAMETER PullRequestHeadSha
        Pull request head commit ID; used for pull_request events.
    .PARAMETER DefaultBranch
        Repository default branch name; used for workflow_dispatch events.
    .PARAMETER RepoRoot
        Repository directory containing the checked-out head commit.
    .OUTPUTS
        [pscustomobject] with mode, base-sha, and head-sha properties.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$EventName,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$BaseSha = '',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$HeadSha,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$PullRequestHeadSha = '',

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$DefaultBranch = '',

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $ResolvedHead = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate $HeadSha
    $CheckedOutHead = Resolve-GitCommit -RepoRoot $RepoRoot -Candidate ([string](& git -C $RepoRoot rev-parse HEAD 2>$null))

    if (
        [string]::IsNullOrWhiteSpace($ResolvedHead) -or
        [string]::IsNullOrWhiteSpace($CheckedOutHead) -or
        $CheckedOutHead -ne $ResolvedHead
    ) {
        return New-FullValidationResult
    }

    $ResolvedBase = switch -CaseSensitive ($EventName) {
        'pull_request' {
            Resolve-PullRequestBase -RepoRoot $RepoRoot -MergeSha $ResolvedHead -PullRequestHeadSha $PullRequestHeadSha
        }
        'merge_group' {
            Resolve-GitCommit -RepoRoot $RepoRoot -Candidate $BaseSha
        }
        'workflow_dispatch' {
            Resolve-DispatchBase -RepoRoot $RepoRoot -HeadSha $ResolvedHead -DefaultBranch $DefaultBranch
        }
        default {
            $null
        }
    }

    if (
        [string]::IsNullOrWhiteSpace($ResolvedBase) -or
        $ResolvedBase -ceq $ResolvedHead -or
        -not (Test-WorkflowGitAncestor -RepoRoot $RepoRoot -BaseSha $ResolvedBase -HeadSha $ResolvedHead) -or
        -not (Test-WorkflowGitDiff -RepoRoot $RepoRoot -BaseSha $ResolvedBase -HeadSha $ResolvedHead)
    ) {
        return New-FullValidationResult
    }

    return [pscustomobject][ordered]@{
        mode       = 'range'
        'base-sha' = $ResolvedBase
        'head-sha' = $ResolvedHead
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ResolveParams = @{
            EventName          = $EventName
            BaseSha            = $BaseSha
            HeadSha            = $HeadSha
            PullRequestHeadSha = $PullRequestHeadSha
            DefaultBranch      = $DefaultBranch
            RepoRoot           = $RepoRoot
        }
        $Result = Resolve-WorkflowChangeRange @ResolveParams

        Set-CIOutput -Name 'mode' -Value $Result.mode
        Set-CIOutput -Name 'base-sha' -Value $Result.'base-sha'
        Set-CIOutput -Name 'head-sha' -Value $Result.'head-sha'

        Write-Host "Workflow change-range event: $EventName; mode: $($Result.mode)"
        exit 0
    }
    catch {
        # A crash means the environment is broken, not that a range is unprovable, so fail instead of selecting full mode.
        Write-CIAnnotation -Level 'Error' -Message "Resolve-WorkflowChangeRange failed: $($_.Exception.Message)"
        Write-Error -ErrorAction Continue "Resolve-WorkflowChangeRange failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
