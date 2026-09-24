#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:PromptPath = Join-Path $script:RepoRoot '.github/prompts/hve-core/git-commit.prompt.md'
    $script:EvalSpecPath = Join-Path $script:RepoRoot 'evals/behavior-conformance/prompts.eval.yaml'
    Import-Module powershell-yaml -ErrorAction Stop

    function Invoke-FixtureGit {
        param(
            [Parameter(Mandatory)]
            [string]$Repository,

            [Parameter(Mandatory)]
            [string[]]$Arguments
        )

        $Output = @(& git -C $Repository @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "git $($Arguments -join ' ') failed: $($Output -join [Environment]::NewLine)"
        }
        return $Output
    }

    function Get-StagedPath {
        param([Parameter(Mandatory)][string]$Repository)

        return @(
            Invoke-FixtureGit -Repository $Repository -Arguments @('diff', '--cached', '--name-only') |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object
        )
    }

    function Get-GitCommitGrader {
        param([Parameter(Mandatory)][string]$Name)

        $Spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:EvalSpecPath -Raw)
        $Stimulus = @($Spec.stimuli | Where-Object { $_.name -eq 'prompt-git-commit-conformance' })
        return @($Stimulus.graders | Where-Object { $_.name -eq $Name })
    }

    function New-GitCommitFixture {
        param(
            [Parameter(Mandatory)]
            [string]$Name,

            [Parameter(Mandatory)]
            [ValidateSet('complete', 'incomplete', 'missing', 'empty')]
            [string]$IgnoreState
        )

        $Repository = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $Repository -Force | Out-Null
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('init', '--quiet', '--initial-branch=main')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('config', 'user.email', 'test@example.com')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('config', 'user.name', 'Test User')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('config', 'commit.gpgsign', 'false')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('config', 'core.autocrlf', 'false')

        $GlobalIgnore = Join-Path $TestDrive "$Name-global-ignore"
        Set-Content -LiteralPath $GlobalIgnore -Value '*.global-ignored' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('config', 'core.excludesFile', $GlobalIgnore)
        [System.IO.File]::WriteAllText((Join-Path $Repository '.git/info/exclude'), '')

        $GitIgnorePath = Join-Path $Repository '.gitignore'
        switch ($IgnoreState) {
            'complete' { Set-Content -LiteralPath $GitIgnorePath -Value 'ignored.marker' -NoNewline }
            'incomplete' { Set-Content -LiteralPath $GitIgnorePath -Value '*.cache' -NoNewline }
            'empty' { [System.IO.File]::WriteAllText($GitIgnorePath, '') }
        }

        foreach ($Path in @('intended.txt', 'unrelated.txt', 'prior.txt', 'partial.txt', 'old-name.txt')) {
            Set-Content -LiteralPath (Join-Path $Repository $Path) -Value "baseline-$Path" -NoNewline
        }

        $BaselinePaths = @('intended.txt', 'unrelated.txt', 'prior.txt', 'partial.txt', 'old-name.txt')
        if ($IgnoreState -ne 'missing') {
            $BaselinePaths += '.gitignore'
        }
        $null = Invoke-FixtureGit -Repository $Repository -Arguments (@('add', '--') + $BaselinePaths)
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('commit', '--quiet', '-m', 'baseline')
        return $Repository
    }
}

Describe 'Git commit prompt contract' -Tag 'Unit' {
    It 'Grades cancellation narration with installed Vally independently of sentence order' {
        $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:EvalSpecPath -Raw)
        $stimulus = $spec.stimuli | Where-Object { $_.name -eq 'prompt-git-commit-cancellation' }
        $grader = $stimulus.graders | Where-Object { $_.name -eq 'prompt-git-commit-cancel-reports-no-commit' }
        $grader.turn | Should -Be 2
        $grader.type | Should -Be 'output-matches'
        $probe = @'
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const { OutputMatchesGrader } = await import(pathToFileURL(process.argv[1]).href);
const input = JSON.parse(readFileSync(0, 'utf8').replace(/^\uFEFF/, ''));
const grader = new OutputMatchesGrader();
for (const control of input.controls) {
  const result = await grader.grade({ config: input.config, trajectory: { output: control.output } });
  if (result.status === 'error' || result.passed !== control.expected || result.score !== Number(control.expected)) {
    throw new Error('Cancellation narrative control failed');
  }
}
console.log(`PASS: ${input.controls.length} cancellation narrative controls`);
'@
        $payload = @{
            config = $grader.config
            controls = @(
                @{ output = 'I restored the staging delta and preserved the initial index. No commit was created.'; expected = $true }
                @{ output = "Restoration is complete. I didn't commit."; expected = $true }
                @{ output = 'No commit was created.'; expected = $false }
                @{ output = 'I restored the staging delta, then created a commit.'; expected = $false }
            )
        } | ConvertTo-Json -Depth 10 -Compress
        $graderPath = Join-Path $script:RepoRoot 'node_modules/@microsoft/vally/dist/graders/static/output-matches-grader.js'
        $result = $payload | & node --input-type=module --eval $probe $graderPath
        $LASTEXITCODE | Should -Be 0
        $result | Should -Be 'PASS: 4 cancellation narrative controls'
    }

    It 'Stages the selection contract while preserving the simulated inventory boundary' {
        $spec = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:EvalSpecPath -Raw)
        $stimulus = $spec.stimuli | Where-Object { $_.name -eq 'prompt-git-commit-conformance' }
        $files = @($stimulus.agent_environment.files)
        $files | Should -HaveCount 2
        $files.dest | Should -Contain '.github/prompts/hve-core/git-commit.prompt.md'
        $files.dest | Should -Contain '.github/instructions/hve-core/commit-message.instructions.md'
        foreach ($file in $files) {
            Test-Path -LiteralPath (Join-Path (Split-Path $script:EvalSpecPath -Parent) $file.src) | Should -BeTrue
        }
        $stimulus.prompt | Should -Match 'response-only simulation'
        $stimulus.prompt | Should -Match 'do not inspect real repository state, run Git, or mutate'
        $stimulus.prompt | Should -Match 'represented HEAD'
        $stimulus.graders | Should -HaveCount 7
    }

    It 'Requires selected-path staging and both confirmation boundaries' {
        $Prompt = Get-Content -LiteralPath $script:PromptPath -Raw

        $Prompt | Should -Match 'git status --porcelain=v1 -z --untracked-files=all'
        $Prompt | Should -Match 'git --literal-pathspecs add -- <safely quoted selected paths>'
        $Prompt | Should -Match 'whole paths intended for this commit'
        $Prompt | Should -Match 'exact staged path set'
        $Prompt | Should -Match 'never unstage prior user work'
        $Prompt | Should -Match 'only an `R` or `C` status record'
        $Prompt | Should -Match 'separate deletion and untracked addition as independent candidates'
        $Prompt | Should -Match 'status-reported rename or copy'
        $Prompt | Should -Match 'git --literal-pathspecs reset -- <safely quoted staging-delta paths>'
        $Prompt | Should -Match 'no push'
    }

    It 'Rejects executable legacy staging and no-confirmation branches' {
        $Prompt = Get-Content -LiteralPath $script:PromptPath -Raw
        $BroadStagingLines = @(
            $Prompt -split "`r?`n" |
                Where-Object { $_ -match '`git add -(?:A|u)`' }
        )

        $BroadStagingLines | Should -HaveCount 1
        $BroadStagingLines[0] | Should -Match 'Never use an unscoped'
        $Prompt | Should -Not -Match 'Pre-staging safety check'
        $Prompt | Should -Not -Match 'verify the repository has a `.gitignore` file'
        $Prompt | Should -Not -Match 'Never wait for confirmation'
        $Prompt | Should -Match 'Wait only for the two required user decisions'
    }

    It 'Requires selection before staging and rejects prior index mutation claims' {
        $BeforeMutation = Get-GitCommitGrader -Name 'prompt-git-commit-conformance-stops-before-mutation'
        $NoPriorMutation = Get-GitCommitGrader -Name 'prompt-git-commit-conformance-no-prior-index-mutation'

        $BeforeMutation | Should -HaveCount 1
        $NoPriorMutation | Should -HaveCount 1
        'Select the whole paths before I stage or modify the index.' | Should -Match $BeforeMutation.config.pattern
        'I staged docs/intended.md. Before I commit, select the whole paths.' | Should -Not -Match $BeforeMutation.config.pattern
        'I staged docs/intended.md and am waiting for your selection.' | Should -Match $NoPriorMutation.config.pattern
        'I have not staged or modified the index; choose the whole paths first.' | Should -Not -Match $NoPriorMutation.config.pattern
    }
}

Describe 'Selected-path Git semantics' -Tag 'Unit' {
    It 'Stages and commits only selected paths with a <IgnoreState> root ignore file' -ForEach @(
        @{ IgnoreState = 'complete' }
        @{ IgnoreState = 'incomplete' }
        @{ IgnoreState = 'missing' }
        @{ IgnoreState = 'empty' }
    ) {
        $Repository = New-GitCommitFixture -Name "selected-$IgnoreState" -IgnoreState $IgnoreState
        Set-Content -LiteralPath (Join-Path $Repository 'intended.txt') -Value 'selected modification' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'unrelated.txt') -Value 'unrelated modification' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'selected-new.txt') -Value 'selected marker' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'unselected-new.txt') -Value 'unselected marker' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'ignored.marker') -Value 'benign ignored marker' -NoNewline

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'intended.txt', 'selected-new.txt')
        (Get-StagedPath -Repository $Repository) -join ',' | Should -Be 'intended.txt,selected-new.txt'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('commit', '--quiet', '-m', 'selected paths')
        $CommittedPaths = @(
            Invoke-FixtureGit -Repository $Repository -Arguments @('diff-tree', '--no-commit-id', '--name-only', '-r', 'HEAD') |
                Sort-Object
        )
        $CommittedPaths -join ',' | Should -Be 'intended.txt,selected-new.txt'
        Test-Path -LiteralPath (Join-Path $Repository 'unselected-new.txt') | Should -BeTrue
    }

    It 'Restores only the staging delta and preserves the initial index' {
        $Repository = New-GitCommitFixture -Name 'restore-delta' -IgnoreState 'complete'
        Set-Content -LiteralPath (Join-Path $Repository 'prior.txt') -Value 'prior staged change' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'prior.txt')

        Set-Content -LiteralPath (Join-Path $Repository 'intended.txt') -Value 'selected tracked change' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'selected-new.txt') -Value 'selected untracked marker' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'intended.txt', 'selected-new.txt')
        (Get-StagedPath -Repository $Repository) -join ',' | Should -Be 'intended.txt,prior.txt,selected-new.txt'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'reset', '--', 'intended.txt', 'selected-new.txt')
        (Get-StagedPath -Repository $Repository) -join ',' | Should -Be 'prior.txt'
        Test-Path -LiteralPath (Join-Path $Repository 'selected-new.txt') | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $Repository 'intended.txt') -Raw) | Should -BeExactly 'selected tracked change'
    }

    It 'Surfaces partially staged paths before whole-path staging' {
        $Repository = New-GitCommitFixture -Name 'partial-stage' -IgnoreState 'complete'
        Set-Content -LiteralPath (Join-Path $Repository 'partial.txt') -Value 'staged version' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('add', '--', 'partial.txt')
        Set-Content -LiteralPath (Join-Path $Repository 'partial.txt') -Value 'staged plus unstaged version' -NoNewline

        $Status = Invoke-FixtureGit -Repository $Repository -Arguments @('status', '--porcelain=v1', '--', 'partial.txt')
        $Status -join "`n" | Should -Match '^MM partial\.txt$'
    }

    It 'Treats a bracketed selected filename literally during staging and restoration' {
        $Repository = New-GitCommitFixture -Name 'literal-brackets' -IgnoreState 'complete'
        Set-Content -LiteralPath (Join-Path $Repository '[ab].txt') -Value 'bracket baseline' -NoNewline
        Set-Content -LiteralPath (Join-Path $Repository 'a.txt') -Value 'matching baseline' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', '[ab].txt', 'a.txt')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('commit', '--quiet', '-m', 'literal baseline')

        Set-Content -LiteralPath (Join-Path $Repository 'a.txt') -Value 'prior staged matching change' -NoNewline
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'a.txt')
        Set-Content -LiteralPath (Join-Path $Repository '[ab].txt') -Value 'selected bracket change' -NoNewline

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', '[ab].txt')
        (Get-StagedPath -Repository $Repository) -join ',' | Should -Be '[ab].txt,a.txt'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'reset', '--', '[ab].txt')
        (Get-StagedPath -Repository $Repository) -join ',' | Should -Be 'a.txt'
        (Get-Content -LiteralPath (Join-Path $Repository '[ab].txt') -Raw) | Should -BeExactly 'selected bracket change'
        (Get-Content -LiteralPath (Join-Path $Repository 'a.txt') -Raw) | Should -BeExactly 'prior staged matching change'
    }

    It 'Stages, restores, and commits a rename as an atomic pair' {
        $Repository = New-GitCommitFixture -Name 'rename-pair' -IgnoreState 'complete'
        Move-Item -LiteralPath (Join-Path $Repository 'old-name.txt') -Destination (Join-Path $Repository 'new-name.txt')

        $UnstagedStatus = Invoke-FixtureGit -Repository $Repository -Arguments @('status', '--porcelain=v1', '--', 'old-name.txt', 'new-name.txt')
        $UnstagedStatus -join "`n" | Should -Match '(?m)^ D old-name\.txt$'
        $UnstagedStatus -join "`n" | Should -Match '(?m)^\?\? new-name\.txt$'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'old-name.txt', 'new-name.txt')
        $StagedRename = Invoke-FixtureGit -Repository $Repository -Arguments @('diff', '--cached', '--name-status', '-M')
        $StagedRename -join "`n" | Should -Match '^R\d+\s+old-name\.txt\s+new-name\.txt$'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'reset', '--', 'old-name.txt', 'new-name.txt')
        Get-StagedPath -Repository $Repository | Should -BeNullOrEmpty
        $UnstagedStatus = Invoke-FixtureGit -Repository $Repository -Arguments @('status', '--porcelain=v1', '--', 'old-name.txt', 'new-name.txt')
        $UnstagedStatus -join "`n" | Should -Match '(?m)^ D old-name\.txt$'
        $UnstagedStatus -join "`n" | Should -Match '(?m)^\?\? new-name\.txt$'

        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('--literal-pathspecs', 'add', '--', 'old-name.txt', 'new-name.txt')
        $null = Invoke-FixtureGit -Repository $Repository -Arguments @('commit', '--quiet', '-m', 'rename pair')
        $CommittedRename = Invoke-FixtureGit -Repository $Repository -Arguments @('diff-tree', '--no-commit-id', '--name-status', '-r', '-M', 'HEAD')
        $CommittedRename -join "`n" | Should -Match '^R\d+\s+old-name\.txt\s+new-name\.txt$'
    }
}
