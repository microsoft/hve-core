#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Collects local branch context for a pull request.
.DESCRIPTION
    Reports branch, divergence, commits, changed files, diff statistics, worktree state, and pull
    request templates without fetching or changing git state. Describes the checked-out branch
    unless -Head names another local branch. The worktree section always reports the current
    checkout.
.PARAMETER Base
    Base branch or ref (default: the remote default branch). A plain name resolves to origin/NAME
    before NAME. Use refs/heads/NAME for a local branch.
.PARAMETER Head
    Local branch to describe (default: the checked-out branch).
.EXAMPLE
    ./Collect-Context.ps1 -Base origin/main
.EXAMPLE
    ./Collect-Context.ps1 -Head feature-b -Base refs/heads/feature-a
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Base = 'auto',

    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$Head = ''
)

$ErrorActionPreference = 'Stop'

#region Functions

function Invoke-GitText {
    <#
    .SYNOPSIS
        Runs git and returns its text output.
    .PARAMETER ArgumentList
        Arguments passed to git.
    .PARAMETER AllowFailure
        Returns an empty string instead of throwing when git exits unsuccessfully.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $false)]
        [switch]$AllowFailure
    )

    $Output = (& git @ArgumentList 2>$null) -join [Environment]::NewLine
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return ''
        }
        throw "Git command failed: git $($ArgumentList -join ' ')"
    }
    return $Output.TrimEnd()
}

function Test-GitRef {
    <#
    .SYNOPSIS
        Tests whether a local git commit ref exists.
    .PARAMETER Ref
        Ref to verify.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Ref
    )

    & git rev-parse --verify "$Ref`^{commit}" *> $null
    return $LASTEXITCODE -eq 0
}

function Resolve-DefaultBase {
    <#
    .SYNOPSIS
        Resolves the local remote default branch.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $SymbolicRef = Invoke-GitText -ArgumentList @(
        'symbolic-ref', '--quiet', 'refs/remotes/origin/HEAD'
    ) -AllowFailure
    if ($SymbolicRef) {
        return $SymbolicRef -replace '^refs/remotes/', ''
    }
    if (Test-GitRef -Ref 'origin/main') {
        return 'origin/main'
    }
    if (Test-GitRef -Ref 'main') {
        return 'main'
    }
    throw 'Unable to resolve the remote default branch. Pass -Base REF.'
}

function Resolve-BaseRef {
    <#
    .SYNOPSIS
        Resolves a requested base to a local git ref.
    .PARAMETER RequestedRef
        Branch name or git ref requested by the caller.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RequestedRef
    )

    $Candidates = @($RequestedRef)
    if ($RequestedRef -notmatch '[/\\]' -and $RequestedRef -notlike 'refs/*') {
        $Candidates = @("origin/$RequestedRef", $RequestedRef)
    }
    foreach ($Candidate in $Candidates) {
        if (Test-GitRef -Ref $Candidate) {
            return $Candidate
        }
    }
    throw "Base ref '$RequestedRef' is unavailable locally. Fetch it or pass another ref."
}

function Resolve-HeadBranch {
    <#
    .SYNOPSIS
        Resolves the local branch to describe.
    .PARAMETER Head
        Requested branch name. An empty value selects the checked-out branch.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Head = ''
    )

    $Branch = if ($Head) {
        $Head -creplace '^refs/heads/', ''
    }
    else {
        Invoke-GitText -ArgumentList @('branch', '--show-current')
    }
    if (-not $Branch) {
        throw 'A named branch must be checked out, or pass -Head BRANCH.'
    }
    & git show-ref --verify --quiet "refs/heads/$Branch" *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "'$Branch' is not a local branch."
    }
    return $Branch
}

function Get-PullRequestBaseName {
    <#
    .SYNOPSIS
        Converts a resolved base ref to a pull request base branch name.
    .PARAMETER BaseRef
        Resolved local base ref.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseRef
    )

    if ($BaseRef.StartsWith('refs/heads/', [System.StringComparison]::Ordinal)) {
        return $BaseRef.Substring('refs/heads/'.Length)
    }
    return $BaseRef -creplace '^refs/remotes/', '' -creplace '^origin/', ''
}

function Get-PullRequestTemplate {
    <#
    .SYNOPSIS
        Finds pull request templates in the locations GitHub reads.
    .DESCRIPTION
        Checks .github/, the repository root, and docs/, in that order. Each location reports its
        pull_request_template.md file before the Markdown files in its PULL_REQUEST_TEMPLATE/
        folder. Names match without regard to case, so a case-insensitive file system still lists
        each template once.
    .PARAMETER RepoRoot
        Absolute repository root.
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $Results = [System.Collections.Generic.List[string]]::new()
    foreach ($Location in @('.github', '', 'docs')) {
        $Directory = if ($Location) { Join-Path $RepoRoot $Location } else { $RepoRoot }
        if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
            continue
        }
        $Entries = @(Get-ChildItem -LiteralPath $Directory | Sort-Object Name)
        $Files = @($Entries | Where-Object {
                -not $_.PSIsContainer -and $_.Name -eq 'pull_request_template.md'
            })
        $Folders = @($Entries | Where-Object {
                $_.PSIsContainer -and $_.Name -eq 'pull_request_template'
            })
        $Templates = @($Files) + @($Folders | ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File |
                    Where-Object { $_.Extension -eq '.md' } |
                    Sort-Object Name
            })
        foreach ($Template in $Templates) {
            $RelativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $Template.FullName)
            $null = $Results.Add($RelativePath.Replace('\', '/'))
        }
    }
    return $Results.ToArray()
}

function Get-PullRequestContext {
    <#
    .SYNOPSIS
        Collects and prints local pull request context.
    .PARAMETER Base
        Requested base branch or ref.
    .PARAMETER Head
        Local branch to describe. An empty value selects the checked-out branch.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Base,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Head = ''
    )

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required but was not found on PATH.'
    }

    $RepoRoot = Invoke-GitText -ArgumentList @('rev-parse', '--show-toplevel')
    $HeadBranch = Resolve-HeadBranch -Head $Head
    $HeadRef = "refs/heads/$HeadBranch"
    $RequestedBase = if ($Base -eq 'auto') { Resolve-DefaultBase } else { $Base }
    $BaseRef = Resolve-BaseRef -RequestedRef $RequestedBase
    $MergeBase = Invoke-GitText -ArgumentList @('merge-base', $HeadRef, $BaseRef) -AllowFailure
    if (-not $MergeBase) {
        throw "No merge base exists between '$HeadBranch' and '$BaseRef'."
    }

    $Divergence = (Invoke-GitText -ArgumentList @(
        'rev-list', '--left-right', '--count', "$BaseRef...$HeadRef"
    )) -split '\s+'
    $UpstreamRef = Invoke-GitText -ArgumentList @(
        'rev-parse', '--abbrev-ref', '--symbolic-full-name', "$HeadBranch@{upstream}"
    ) -AllowFailure
    $UpstreamAheadCount = 'unknown'
    $UpstreamBehindCount = 'unknown'
    $PushState = 'missing'
    if ($UpstreamRef) {
        $UpstreamDivergence = (Invoke-GitText -ArgumentList @(
            'rev-list', '--left-right', '--count', "$UpstreamRef...$HeadRef"
        )) -split '\s+'
        $UpstreamBehindCount = [int]$UpstreamDivergence[0]
        $UpstreamAheadCount = [int]$UpstreamDivergence[1]
        $PushState = if ($UpstreamBehindCount -gt 0 -and $UpstreamAheadCount -gt 0) {
            'diverged'
        }
        elseif ($UpstreamBehindCount -gt 0) {
            'behind'
        }
        elseif ($UpstreamAheadCount -gt 0) {
            'ahead'
        }
        else {
            'current'
        }
    }
    $BranchNeedsPush = ($PushState -in @('ahead', 'missing')).ToString().ToLowerInvariant()

    @(
        'PR_CONTEXT_V1'
        "repository_root: $RepoRoot"
        "head_branch: $HeadBranch"
        "base_ref: $BaseRef"
        "base_branch: $(Get-PullRequestBaseName -BaseRef $BaseRef)"
        "merge_base: $MergeBase"
        "ahead_count: $($Divergence[1])"
        "behind_count: $($Divergence[0])"
        "upstream_ref: $(if ($UpstreamRef) { $UpstreamRef } else { 'none' })"
        "upstream_ahead_count: $UpstreamAheadCount"
        "upstream_behind_count: $UpstreamBehindCount"
        "push_state: $PushState"
        "branch_needs_push: $BranchNeedsPush"
        ''
        '[commits]'
        Invoke-GitText -ArgumentList @('log', '--format=%h%x09%s', "$MergeBase..$HeadRef")
        ''
        '[changed_files]'
        Invoke-GitText -ArgumentList @('diff', '--name-status', '-M', "$MergeBase..$HeadRef")
        ''
        '[diff_stat]'
        Invoke-GitText -ArgumentList @('diff', '--stat', "$MergeBase..$HeadRef")
        ''
        '[worktree]'
        Invoke-GitText -ArgumentList @('status', '--short')
        ''
        '[templates]'
        Get-PullRequestTemplate -RepoRoot $RepoRoot
    ) -join [Environment]::NewLine
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Get-PullRequestContext -Base $Base -Head $Head
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Collect-Context failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
