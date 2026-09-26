#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../evals/Modules/EvalChangeSet.psm1') -Force
    $script:Generator = Join-Path $PSScriptRoot '../../evals/Get-EvalChangeSet.ps1'
    $script:Repo = Join-Path $TestDrive 'repo'
    $null = New-Item -ItemType Directory -Path $script:Repo

    function Invoke-FixtureGit {
        param([string[]]$Arguments)
        (Invoke-EvalGit -RepoRoot $script:Repo -Arguments $Arguments).Trim()
    }
    function Set-FixtureFile {
        param([string]$Path, [string]$Content)
        $FullPath = Join-Path $script:Repo $Path
        $null = New-Item -ItemType Directory -Path (Split-Path $FullPath -Parent) -Force
        Set-Content -LiteralPath $FullPath -Value $Content -Encoding utf8NoBOM
    }
    function Save-FixtureCommit {
        param([string]$Message)
        $null = Invoke-FixtureGit @('add', '-A')
        $null = Invoke-FixtureGit @('commit', '--quiet', '-m', $Message)
        Invoke-FixtureGit @('rev-parse', 'HEAD')
    }

    $null = Invoke-FixtureGit @('init', '--quiet', '--initial-branch=main')
    $null = Invoke-FixtureGit @('config', 'user.email', 'test@example.com')
    $null = Invoke-FixtureGit @('config', 'user.name', 'Test')
    $null = Invoke-FixtureGit @('config', 'commit.gpgsign', 'false')
    $null = Invoke-FixtureGit @('config', 'core.autocrlf', 'false')
    Set-FixtureFile 'CONTRIBUTING.md' 'base'
    Set-FixtureFile 'TRANSPARENCY-NOTE.md' 'base'
    Set-FixtureFile 'evals/shared.yaml' 'base-spec'
    Set-FixtureFile 'package.json' "{`n`"description`":`"old`",`n`"devDependencies`":{`"vally`":`"1.0`",`"tool`":`"1.0`"}`n}"
    Set-FixtureFile 'package-lock.json' '{"version":"1.0"}'
    $script:Base = Save-FixtureCommit 'base'
    $null = Invoke-FixtureGit @('checkout', '-b', 'docs')
    Set-FixtureFile 'CONTRIBUTING.md' 'PR contribution'
    Set-FixtureFile 'TRANSPARENCY-NOTE.md' 'PR transparency'
    $script:DocsHead = Save-FixtureCommit 'docs only'
    $null = Invoke-FixtureGit @('checkout', 'main')
    Set-FixtureFile '.github/agents/core/upstream.agent.md' 'upstream agent'
    Set-FixtureFile '.github/skills/core/upstream/SKILL.md' 'upstream skill'
    Set-FixtureFile 'evals/shared.yaml' 'upstream-spec'
    $script:MainHead = Save-FixtureCommit 'main AI advances'
    $null = Invoke-FixtureGit @('merge', '--no-ff', '--no-edit', 'docs')
    $script:MergeHead = Invoke-FixtureGit @('rev-parse', 'HEAD')
}

AfterAll {
    Get-ChildItem -LiteralPath $script:Repo -Recurse -Force -File | ForEach-Object { $_.IsReadOnly = $false }
    Remove-Module EvalChangeSet -Force -ErrorAction SilentlyContinue
}

Describe 'Immutable eval change selection' -Tag 'Unit' {
    It 'excludes advanced-main AI changes in a docs-only PR merge checkout' {
        (Invoke-FixtureGit @('rev-parse', 'HEAD')) | Should -Be $script:MergeHead
        $Incorrect = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:MergeHead
        Test-EvalChangeSetRelevance -ChangeSet $Incorrect -RepoRoot $script:Repo | Should -BeTrue

        $Correct = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:DocsHead
        $Correct.changes.path | Should -Be @('CONTRIBUTING.md', 'TRANSPARENCY-NOTE.md')
        Test-EvalChangeSetRelevance -ChangeSet $Correct -RepoRoot $script:Repo | Should -BeFalse
        $Correct.comparisonBase | Should -Be $script:Base
        $Correct.headRef | Should -Be $script:DocsHead
    }

    It 'freezes an advanced base tip and records its actual merge base' {
        $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:MainHead -HeadRef $script:DocsHead
        $Set.baseRef | Should -Be $script:MainHead
        $Set.comparisonBase | Should -Be $script:Base
        $Set.changes.path | Should -Be @('CONTRIBUTING.md', 'TRANSPARENCY-NOTE.md')
    }

    It 'emits identical evidence for repeated explicit comparisons' {
        $Parameters = @{ RepoRoot = $script:Repo; BaseRef = $script:MainHead; HeadRef = $script:DocsHead }
        (New-EvalChangeSet @Parameters | ConvertTo-Json -Depth 6) |
            Should -BeExactly (New-EvalChangeSet @Parameters | ConvertTo-Json -Depth 6)
    }

    It 'writes a successful empty JSON array through the generator entry point' {
        $OutputPath = Join-Path $TestDrive 'empty.json'
        & pwsh -NoProfile -File $script:Generator -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:Base -OutFile $OutputPath
        $LASTEXITCODE | Should -Be 0
        $Set = Read-EvalChangeSet -Path $OutputPath
        $Set.changes | Should -HaveCount 0
        Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeFalse
    }

    It 'reports invalid revisions explicitly without writing a manifest' {
        $OutputPath = Join-Path $TestDrive 'invalid.json'
        $Output = & pwsh -NoProfile -File $script:Generator -RepoRoot $script:Repo -BaseRef missing-ref -HeadRef $script:DocsHead -OutFile $OutputPath 2>&1
        $LASTEXITCODE | Should -Be 2
        "$Output" | Should -Match 'git rev-parse.+failed \(exit .+\).+fatal'
        Test-Path $OutputPath | Should -BeFalse
    }

    It 'keeps genuine AI and eval changes eligible: <Path>' -ForEach @(
        @{ Path = '.github/agents/core/new.agent.md' }
        @{ Path = '.github/prompts/core/new.prompt.md' }
        @{ Path = '.github/instructions/core/new.instructions.md' }
        @{ Path = '.github/skills/core/new/SKILL.md' }
        @{ Path = '.github/skills/core/new/references/guide.md' }
        @{ Path = 'evals/new.yaml' }
        @{ Path = 'scripts/evals/helper.ps1' }
    ) {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile $Path 'PR AI change'
            $Head = Save-FixtureCommit 'genuine AI change'
            $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead)
            $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:MainHead -HeadRef $Head
            $Set.changes.path | Should -Be $Path
            Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeTrue
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }

    It 'keeps comparisonBase and records consistent when both tips change the same spec' {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile 'evals/shared.yaml' 'PR-spec'
            $Head = Save-FixtureCommit 'PR shared spec'
            $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead)
            $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:MainHead -HeadRef $Head
            $Set.comparisonBase | Should -Be $script:Base
            $Set.changes | Should -HaveCount 1
            $Set.changes[0].status | Should -Be 'M'
            $Set.changes[0].path | Should -Be 'evals/shared.yaml'
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }

    It 'preserves package content scoping: <Name>' -ForEach @(
        @{ Name = 'unrelated'; File = 'package.json'; Content = "{`n`"description`":`"new`",`n`"devDependencies`":{`"vally`":`"1.0`",`"tool`":`"1.0`"}`n}"; Expected = $false }
        @{ Name = 'ordinary lockfile'; File = 'package-lock.json'; Content = '{"version":"2.0"}'; Expected = $false }
        @{ Name = 'vally dependency'; File = 'package.json'; Content = '{"devDependencies":{"vally":"2.0"}}'; Expected = $true }
        @{ Name = 'eval script'; File = 'package.json'; Content = '{"scripts":{"ci:eval:run":"changed"}}'; Expected = $true }
    ) {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile $File $Content
            $Head = Save-FixtureCommit 'package change'
            $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:MainHead -HeadRef $Head
            Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -Be $Expected
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }

    It 'does not suppress package patch failures' {
        $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:DocsHead
        $Set.changes = @(@{ status = 'M'; path = 'package.json'; previousPath = $null })
        $Set.headRef = 'a' * 40
        { Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo } | Should -Throw '*git diff*failed*'
    }

    It 'detects a rename out of AI artifact space' {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:MainHead)
        try {
            $null = Invoke-FixtureGit @('mv', '.github/agents/core/upstream.agent.md', 'archived.md')
            $Head = Save-FixtureCommit 'archive agent'
            $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:MainHead -HeadRef $Head
            $Set.changes[0].previousPath | Should -Be '.github/agents/core/upstream.agent.md'
            $Set.changes[0].status | Should -Be 'R'
            Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeTrue
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }
}

Describe 'Eligibility trigger logging' -Tag 'Unit' {
    It 'names the first triggering path and returns a single boolean' {
        $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:DocsHead
        $Set.changes = @(
            @{ status = 'M'; path = 'CONTRIBUTING.md'; previousPath = $null }
            @{ status = 'A'; path = '.github/agents/core/new.agent.md'; previousPath = $null }
        )
        $Result = @(Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo -InformationVariable Messages 6>$null)
        $Result | Should -HaveCount 1
        $Result[0] | Should -BeOfType [bool]
        $Result[0] | Should -BeTrue
        "$Messages" | Should -BeExactly 'Eval-relevant change: .github/agents/core/new.agent.md'
    }

    It 'names the package file whose content matched' {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile 'package.json' '{"devDependencies":{"vally":"2.0"}}'
            $Head = Save-FixtureCommit 'vally bump'
            $Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $Head
            $Result = @(Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo -InformationVariable Messages 6>$null)
            $Result | Should -HaveCount 1
            $Result[0] | Should -BeTrue
            "$Messages" | Should -BeExactly 'Eval-relevant package change: package.json'
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }
}

Describe 'Merge-parent base derivation' -Tag 'Unit' {
    It 'derives a docs-only selection from a stale-base merge checkout through the entry point' {
        $OutputPath = Join-Path $TestDrive 'merge-mode.json'
        $Output = & pwsh -NoProfile -File $script:Generator -RepoRoot $script:Repo -MergeRef $script:MergeHead -HeadRef $script:DocsHead -OutFile $OutputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        "$Output" | Should -Match "Derived base $($script:MainHead) from merge ref $($script:MergeHead) first parent"
        $Set = Read-EvalChangeSet -Path $OutputPath
        $Set.baseRef | Should -Be $script:MainHead
        $Set.comparisonBase | Should -Be $script:Base
        $Set.changes.path | Should -Be @('CONTRIBUTING.md', 'TRANSPARENCY-NOTE.md')
        Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeFalse
    }

    It 'excludes AI changes already merged into the branch and newer main AI changes' {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile 'CONTRIBUTING.md' 'branch docs'
            $null = Save-FixtureCommit 'branch docs'
            $null = Invoke-FixtureGit @('merge', '--no-ff', '--no-edit', $script:MainHead)
            $BranchHead = Invoke-FixtureGit @('rev-parse', 'HEAD')
            $null = Invoke-FixtureGit @('checkout', '--detach', $script:MainHead)
            Set-FixtureFile '.github/prompts/core/later.prompt.md' 'later main prompt'
            $LaterMain = Save-FixtureCommit 'later main AI'
            $null = Invoke-FixtureGit @('merge', '--no-ff', '--no-edit', $BranchHead)
            $Merge = Invoke-FixtureGit @('rev-parse', 'HEAD')

            $Set = New-EvalChangeSet -RepoRoot $script:Repo -MergeRef $Merge -HeadRef $BranchHead
            $Set.baseRef | Should -Be $LaterMain
            $Set.comparisonBase | Should -Be $script:MainHead
            $Set.changes.path | Should -Be @('CONTRIBUTING.md')
            Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeFalse
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }

    It 'keeps a genuine AI change eligible in merge mode' {
        $null = Invoke-FixtureGit @('checkout', '--detach', $script:Base)
        try {
            Set-FixtureFile '.github/agents/core/pr.agent.md' 'PR agent'
            $Head = Save-FixtureCommit 'PR agent'
            $null = Invoke-FixtureGit @('checkout', '--detach', $script:MainHead)
            $null = Invoke-FixtureGit @('merge', '--no-ff', '--no-edit', $Head)
            $Merge = Invoke-FixtureGit @('rev-parse', 'HEAD')

            $Set = New-EvalChangeSet -RepoRoot $script:Repo -MergeRef $Merge -HeadRef $Head
            $Set.changes.path | Should -Be '.github/agents/core/pr.agent.md'
            Test-EvalChangeSetRelevance -ChangeSet $Set -RepoRoot $script:Repo | Should -BeTrue
        }
        finally { $null = Invoke-FixtureGit @('checkout', '--detach', $script:MergeHead) }
    }

    It 'rejects a merge ref that is not a two-parent merge' {
        { New-EvalChangeSet -RepoRoot $script:Repo -MergeRef $script:DocsHead -HeadRef $script:DocsHead } |
            Should -Throw "*$($script:DocsHead) must have exactly two parents; found 1*"
    }

    It 'rejects a merge ref whose second parent is not the head' {
        { New-EvalChangeSet -RepoRoot $script:Repo -MergeRef $script:MergeHead -HeadRef $script:Base } |
            Should -Throw "*second parent $($script:DocsHead) does not match head $($script:Base)*"
    }

    It 'rejects supplying both merge and base refs to the entry point' {
        $OutputPath = Join-Path $TestDrive 'ambiguous.json'
        $Output = & pwsh -NoProfile -File $script:Generator -RepoRoot $script:Repo -MergeRef $script:MergeHead -BaseRef $script:Base -HeadRef $script:DocsHead -OutFile $OutputPath 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        "$Output" | Should -Match 'Parameter set cannot be resolved'
        Test-Path $OutputPath | Should -BeFalse
    }
}

Describe 'Canonical manifest validation' -Tag 'Unit' {
    BeforeEach {
        $script:Set = New-EvalChangeSet -RepoRoot $script:Repo -BaseRef $script:Base -HeadRef $script:DocsHead
    }

    It 'rejects malformed input: <Name>' -ForEach @(
        @{ Name = 'schema'; Mutate = { $script:Set.schemaVersion = '9.0' } }
        @{ Name = 'revision'; Mutate = { $script:Set.headRef = 'HEAD' } }
        @{ Name = 'comparison baseline'; Mutate = { $script:Set.Remove('comparisonBase') } }
        @{ Name = 'null changes'; Mutate = { $script:Set.changes = $null } }
        @{ Name = 'unknown status'; Mutate = { $script:Set.changes[0].status = 'U' } }
        @{ Name = 'traversal'; Mutate = { $script:Set.changes[0].path = '../outside' } }
        @{ Name = 'rooted path'; Mutate = { $script:Set.changes[0].path = '/outside' } }
        @{ Name = 'duplicate'; Mutate = { $script:Set.changes += $script:Set.changes[0] } }
        @{ Name = 'rename source'; Mutate = { $script:Set.changes[0].status = 'R' } }
    ) {
        & $Mutate
        { Assert-EvalChangeSet -ChangeSet $script:Set } | Should -Throw
    }

    It 'fails on a missing manifest' {
        { Read-EvalChangeSet -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw
    }

    It 'parses null-terminated renamed paths containing whitespace without loss' {
        Import-Module (Join-Path $PSScriptRoot '../../evals/Modules/ArtifactDetection.psm1') -Force
        $Records = ConvertFrom-GitDiffNameStatus -Lines @("R100`0old`tname.md`0new`nname.md`0") -NullTerminated
        $Records[0].previousPath | Should -BeExactly "old`tname.md"
        $Records[0].path | Should -BeExactly "new`nname.md"
    }
}
