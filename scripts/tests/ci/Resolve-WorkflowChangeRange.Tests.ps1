#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    function Invoke-TestGit {
        <#
        .SYNOPSIS
            Runs Git in a temporary test repository.
        .PARAMETER RepoRoot
            Temporary Git repository root.
        .PARAMETER ArgumentList
            Arguments passed to Git.
        .OUTPUTS
            [string[]] containing Git standard output.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot,

            [Parameter(Mandatory = $true)]
            [string[]]$ArgumentList
        )

        $Output = & git -C $RepoRoot @ArgumentList 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Git command failed: git -C $RepoRoot $($ArgumentList -join ' ')`n$($Output -join "`n")"
        }

        return $Output
    }

    function New-TestRepository {
        <#
        .SYNOPSIS
            Creates an initialized temporary Git repository on a main branch.
        .PARAMETER RepoRoot
            Directory to initialize as a Git repository.
        .OUTPUTS
            [string] containing the repository root.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot
        )

        New-Item -ItemType Directory -Path $RepoRoot -Force | Out-Null
        Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('init', '--quiet', '--initial-branch=main') | Out-Null
        Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('config', 'user.name', 'Merge Queue Tests') | Out-Null
        Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('config', 'user.email', 'merge-queue-tests@example.invalid') | Out-Null

        return $RepoRoot
    }

    function New-TestCommit {
        <#
        .SYNOPSIS
            Adds one file and creates a commit in a temporary repository.
        .PARAMETER RepoRoot
            Temporary Git repository root.
        .PARAMETER FileName
            Repository-relative file name to write.
        .PARAMETER Content
            File content for the commit.
        .PARAMETER Message
            Commit message.
        .OUTPUTS
            [string] containing the new commit ID.
        #>
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot,

            [Parameter(Mandatory = $true)]
            [string]$FileName,

            [Parameter(Mandatory = $true)]
            [string]$Content,

            [Parameter(Mandatory = $true)]
            [string]$Message
        )

        $FilePath = Join-Path $RepoRoot $FileName
        Set-Content -Path $FilePath -Value $Content -Encoding utf8NoBOM
        Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('add', '--', $FileName) | Out-Null
        Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('commit', '--quiet', '--message', $Message) | Out-Null

        return (Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('rev-parse', 'HEAD')).Trim()
    }

    function Get-TestRangeFile {
        <#
        .SYNOPSIS
            Lists files changed by a resolved range.
        .PARAMETER RepoRoot
            Temporary Git repository root.
        .PARAMETER Result
            Resolver result containing base-sha and head-sha.
        .OUTPUTS
            [string[]] containing changed repository-relative paths.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot,

            [Parameter(Mandatory = $true)]
            [pscustomobject]$Result
        )

        return @(Invoke-TestGit -RepoRoot $RepoRoot -ArgumentList @('diff', '--name-only', "$($Result.'base-sha')..$($Result.'head-sha')", '--'))
    }

    $script:ResolverPath = Join-Path $PSScriptRoot '../../ci/Resolve-WorkflowChangeRange.ps1'
    . $script:ResolverPath
}

Describe 'Resolve-WorkflowChangeRange' -Tag 'Unit' {
    BeforeEach {
        $script:RepoRoot = New-TestRepository -RepoRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString()))
        $script:RootSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'root.txt' -Content 'root' -Message 'Add root'
        $script:BaseSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'inherited.txt' -Content 'target base' -Message 'Add target-base content'
        $script:FirstQueuedSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'queued-one.txt' -Content 'first queued change' -Message 'Add first queued change'
        $script:HeadSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'queued-two.txt' -Content 'second queued change' -Message 'Add second queued change'
    }

    Context 'when a merge group head contains multiple queued commits' {
        It 'Selects a range containing queued content but not inherited base content' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $script:BaseSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot
            $ChangedFiles = Get-TestRangeFile -RepoRoot $script:RepoRoot -Result $Result

            $Result.mode | Should -BeExactly 'range'
            $Result.'base-sha' | Should -BeExactly $script:BaseSha
            $Result.'head-sha' | Should -BeExactly $script:HeadSha
            $ChangedFiles | Should -Contain 'queued-one.txt'
            $ChangedFiles | Should -Contain 'queued-two.txt'
            $ChangedFiles | Should -Not -Contain 'inherited.txt'
        }
    }

    Context 'when immutable range inputs cannot be trusted' {
        It 'Selects full mode when a commit is missing' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha '' -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
            $Result.'base-sha' | Should -BeNullOrEmpty
            $Result.'head-sha' | Should -BeNullOrEmpty
        }

        It 'Selects full mode when a commit ID is malformed' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha 'not-a-commit-id' -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when a commit ID is neither 40 nor 64 hex characters' {
            $RefShapedId = 'a' * 41
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('branch', $RefShapedId, $script:BaseSha) | Out-Null

            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $RefShapedId -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when a commit is unavailable' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha ('a' * 40) -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when the checked-out head differs from the requested head' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $script:BaseSha -HeadSha $script:FirstQueuedSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when the repository has no checked-out head' {
            $EmptyRepoRoot = New-TestRepository -RepoRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString()))
            $script:Result = $null

            { $script:Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha ('a' * 40) -HeadSha ('b' * 40) -RepoRoot $EmptyRepoRoot } | Should -Not -Throw
            $script:Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when Git cannot diff the resolved commits' {
            Mock Test-WorkflowGitDiff { return $false }

            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $script:BaseSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when the base is not an ancestor of the head' {
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('checkout', '--quiet', '-b', 'side', $script:RootSha) | Out-Null
            $SideSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'side.txt' -Content 'side' -Message 'Add side change'
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('checkout', '--quiet', 'main') | Out-Null

            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $SideSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode for an event without a range rule' {
            $Result = Resolve-WorkflowChangeRange -EventName 'push' -BaseSha $script:BaseSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when the base equals the head' {
            $Result = Resolve-WorkflowChangeRange -EventName 'merge_group' -BaseSha $script:HeadSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
            $Result.'base-sha' | Should -BeNullOrEmpty
            $Result.'head-sha' | Should -BeNullOrEmpty
        }
    }

    Context 'when a pull request test-merge commit is checked out' {
        BeforeEach {
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('checkout', '--quiet', '-b', 'feature', $script:BaseSha) | Out-Null
            $script:PullRequestHeadSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'feature.txt' -Content 'feature' -Message 'Add feature change'
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('checkout', '--quiet', 'main') | Out-Null
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('merge', '--quiet', '--no-ff', '--no-edit', 'feature') | Out-Null
            $script:MergeSha = (Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('rev-parse', 'HEAD')).Trim()
        }

        It 'Uses the first merge parent instead of a stale payload base' {
            $Result = Resolve-WorkflowChangeRange -EventName 'pull_request' -BaseSha $script:BaseSha -HeadSha $script:MergeSha -PullRequestHeadSha $script:PullRequestHeadSha -RepoRoot $script:RepoRoot
            $ChangedFiles = Get-TestRangeFile -RepoRoot $script:RepoRoot -Result $Result

            $Result.mode | Should -BeExactly 'range'
            $Result.'base-sha' | Should -BeExactly $script:HeadSha
            $Result.'head-sha' | Should -BeExactly $script:MergeSha
            $ChangedFiles | Should -BeExactly @('feature.txt')
        }

        It 'Selects full mode when the second merge parent is not the pull request head' {
            $Result = Resolve-WorkflowChangeRange -EventName 'pull_request' -HeadSha $script:MergeSha -PullRequestHeadSha $script:BaseSha -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }
    }

    Context 'when a workflow is dispatched manually' {
        BeforeEach {
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('update-ref', 'refs/remotes/origin/main', $script:BaseSha) | Out-Null
        }

        It 'Uses the merge base with the default branch' {
            $Result = Resolve-WorkflowChangeRange -EventName 'workflow_dispatch' -HeadSha $script:HeadSha -DefaultBranch 'main' -RepoRoot $script:RepoRoot
            $ChangedFiles = Get-TestRangeFile -RepoRoot $script:RepoRoot -Result $Result

            $Result.mode | Should -BeExactly 'range'
            $Result.'base-sha' | Should -BeExactly $script:BaseSha
            $Result.'head-sha' | Should -BeExactly $script:HeadSha
            $ChangedFiles | Should -Contain 'queued-one.txt'
            $ChangedFiles | Should -Not -Contain 'inherited.txt'
        }

        It 'Selects full mode when the default branch is not available' {
            $Result = Resolve-WorkflowChangeRange -EventName 'workflow_dispatch' -HeadSha $script:HeadSha -DefaultBranch 'missing' -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
        }

        It 'Selects full mode when the checked-out head is the default branch tip' {
            Invoke-TestGit -RepoRoot $script:RepoRoot -ArgumentList @('update-ref', 'refs/remotes/origin/main', $script:HeadSha) | Out-Null

            $Result = Resolve-WorkflowChangeRange -EventName 'workflow_dispatch' -HeadSha $script:HeadSha -DefaultBranch 'main' -RepoRoot $script:RepoRoot

            $Result.mode | Should -BeExactly 'full'
            $Result.'base-sha' | Should -BeNullOrEmpty
            $Result.'head-sha' | Should -BeNullOrEmpty
        }
    }
}

Describe 'Resolve-WorkflowChangeRange script outputs' -Tag 'Unit' {
    BeforeEach {
        $script:RepoRoot = New-TestRepository -RepoRoot (Join-Path $TestDrive ([guid]::NewGuid().ToString()))
        $script:BaseSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'base.txt' -Content 'base' -Message 'Add base'
        $script:HeadSha = New-TestCommit -RepoRoot $script:RepoRoot -FileName 'head.txt' -Content 'head' -Message 'Add head'
    }

    It 'Emits full mode with explicit empty SHA outputs' {
        $OutputPath = Join-Path $TestDrive 'github-output.txt'
        $PreviousGitHubActions = $env:GITHUB_ACTIONS
        $PreviousGitHubOutput = $env:GITHUB_OUTPUT

        try {
            $env:GITHUB_ACTIONS = 'true'
            $env:GITHUB_OUTPUT = $OutputPath

            & pwsh -NoProfile -File $script:ResolverPath -EventName 'merge_group' -BaseSha 'invalid' -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot | Out-Null

            $LASTEXITCODE | Should -Be 0
            $Outputs = Get-Content -Path $OutputPath
            $Outputs | Should -Contain 'mode=full'
            $Outputs | Should -Contain 'base-sha='
            $Outputs | Should -Contain 'head-sha='
        }
        finally {
            $env:GITHUB_ACTIONS = $PreviousGitHubActions
            $env:GITHUB_OUTPUT = $PreviousGitHubOutput
        }
    }

    It 'Fails with an error annotation when outputs cannot be written' {
        $UnwritableOutputPath = Join-Path $TestDrive 'github-output-directory'
        New-Item -ItemType Directory -Path $UnwritableOutputPath -Force | Out-Null
        $PreviousGitHubActions = $env:GITHUB_ACTIONS
        $PreviousGitHubOutput = $env:GITHUB_OUTPUT

        try {
            $env:GITHUB_ACTIONS = 'true'
            $env:GITHUB_OUTPUT = $UnwritableOutputPath

            $Output = & pwsh -NoProfile -File $script:ResolverPath -EventName 'merge_group' -BaseSha $script:BaseSha -HeadSha $script:HeadSha -RepoRoot $script:RepoRoot *>&1
            $ExitCode = $LASTEXITCODE
            $ErrorAnnotations = @($Output | ForEach-Object { [string]$_ } | Where-Object { $_ -like '::error::Resolve-WorkflowChangeRange failed:*' })

            $ExitCode | Should -Not -Be 0
            $ErrorAnnotations | Should -Not -BeNullOrEmpty
        }
        finally {
            $env:GITHUB_ACTIONS = $PreviousGitHubActions
            $env:GITHUB_OUTPUT = $PreviousGitHubOutput
        }
    }
}
