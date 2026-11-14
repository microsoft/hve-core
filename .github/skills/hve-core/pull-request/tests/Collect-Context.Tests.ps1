#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeDiscovery {
    # The Bash tests run the real collect-context.sh, which needs bash and git.
    $script:BashAvailable = $false
    if (Get-Command bash -CommandType Application -ErrorAction SilentlyContinue) {
        $bashScript = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/collect-context.sh'
        & bash -c 'test -r "$1" && command -v git >/dev/null 2>&1' bash $bashScript 2>$null
        $script:BashAvailable = $LASTEXITCODE -eq 0
    }
}

BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Collect-Context.ps1')

    $script:PowerShellScript = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/Collect-Context.ps1'
    $script:BashScript = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/collect-context.sh'
    $script:HeaderKeys = @(
        'repository_root'
        'head_branch'
        'base_ref'
        'base_branch'
        'merge_base'
        'ahead_count'
        'behind_count'
        'upstream_ref'
        'upstream_ahead_count'
        'upstream_behind_count'
        'push_state'
        'branch_needs_push'
    )
    $script:SectionNames = @('commits', 'changed_files', 'diff_stat', 'worktree', 'templates')
    $script:ExpectedTemplates = @(
        '.github/PULL_REQUEST_TEMPLATE.md'
        '.github/PULL_REQUEST_TEMPLATE/bug.md'
        '.github/PULL_REQUEST_TEMPLATE/release.md'
        'pull_request_template.md'
        'PULL_REQUEST_TEMPLATE/feature.md'
        'docs/PULL_REQUEST_TEMPLATE.md'
        'docs/pull_request_template/docs.md'
    )

    function Invoke-TestGit {
        param(
            [Parameter(Mandatory = $false)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string[]]$ArgumentList
        )

        $gitArguments = if ($Path) { @('-C', $Path) + $ArgumentList } else { $ArgumentList }
        $records = @(& git @gitArguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "git $($gitArguments -join ' ') failed: $($records -join ' ')"
        }
        $output = $records | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
        return (@($output) -join "`n").Trim()
    }

    function Write-TestFile {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root,

            [Parameter(Mandatory = $true)]
            [string]$RelativePath
        )

        $filePath = Join-Path -Path $Root -ChildPath $RelativePath
        $null = New-Item -ItemType Directory -Path (Split-Path -Path $filePath -Parent) -Force
        Set-Content -LiteralPath $filePath -Value "Content of $RelativePath."
    }

    function Initialize-TestRepository {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$HooksPath,

            [Parameter(Mandatory = $false)]
            [switch]$Bare
        )

        $initArguments = @('init', '--quiet', '-b', 'main')
        $gitDirectory = Join-Path -Path $Path -ChildPath '.git'
        if ($Bare) {
            $initArguments += '--bare'
            $gitDirectory = $Path
        }
        $null = Invoke-TestGit -ArgumentList ($initArguments + $Path)

        # Local settings keep the user's global identity, signing, and hooks out of the fixture.
        $settings = [ordered]@{
            'user.name'      = 'PR Context Tests'
            'user.email'     = 'pr-context-tests@example.com'
            'commit.gpgsign' = 'false'
            'tag.gpgsign'    = 'false'
            'core.hooksPath' = $HooksPath
        }
        foreach ($setting in $settings.GetEnumerator()) {
            $null = Invoke-TestGit -ArgumentList @(
                "--git-dir=$gitDirectory", 'config', '--local', $setting.Key, $setting.Value
            )
        }
    }

    function Initialize-StackFixture {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root
        )

        $hooksPath = Join-Path -Path $Root -ChildPath 'hooks'
        $remotePath = Join-Path -Path $Root -ChildPath 'origin.git'
        $repoPath = Join-Path -Path $Root -ChildPath 'repo'
        $null = New-Item -ItemType Directory -Path $hooksPath -Force

        Initialize-TestRepository -Path $remotePath -HooksPath $hooksPath -Bare
        Initialize-TestRepository -Path $repoPath -HooksPath $hooksPath
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('remote', 'add', 'origin', $remotePath)

        foreach ($relativePath in @(
                'README.md'
                'docs/guide.md'
                '.github/PULL_REQUEST_TEMPLATE.md'
                '.github/PULL_REQUEST_TEMPLATE/release.md'
                '.github/PULL_REQUEST_TEMPLATE/bug.md'
                '.github/PULL_REQUEST_TEMPLATE/notes.txt'
                'pull_request_template.md'
                'PULL_REQUEST_TEMPLATE/feature.md'
                'docs/PULL_REQUEST_TEMPLATE.md'
                'docs/pull_request_template/docs.md'
            )) {
            Write-TestFile -Root $repoPath -RelativePath $relativePath
        }
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('add', '--all')
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('commit', '--quiet', '-m', 'Add readme and templates')

        # feature-b stacks on feature-a. side starts at main and later becomes the diverged branch.
        foreach ($branch in @(
                @{ Name = 'feature-a'; StartPoint = 'main'; File = 'a.txt'; Subject = 'Add feature a' }
                @{ Name = 'feature-b'; StartPoint = 'feature-a'; File = 'b.txt'; Subject = 'Add feature b' }
                @{ Name = 'side'; StartPoint = 'main'; File = 'side.txt'; Subject = 'Add side change' }
            )) {
            $null = Invoke-TestGit -Path $repoPath -ArgumentList @(
                'checkout', '--quiet', '--no-track', '-b', $branch.Name, $branch.StartPoint
            )
            Write-TestFile -Root $repoPath -RelativePath $branch.File
            $null = Invoke-TestGit -Path $repoPath -ArgumentList @('add', '--', $branch.File)
            $null = Invoke-TestGit -Path $repoPath -ArgumentList @('commit', '--quiet', '-m', $branch.Subject)
        }
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('checkout', '--quiet', 'main')

        foreach ($branch in @(
                @{ Name = 'local-main'; StartPoint = 'main' }
                @{ Name = 'push-ahead'; StartPoint = 'main' }
                @{ Name = 'push-behind'; StartPoint = 'feature-a' }
                @{ Name = 'push-diverged'; StartPoint = 'feature-a' }
            )) {
            $null = Invoke-TestGit -Path $repoPath -ArgumentList @(
                'branch', '--no-track', $branch.Name, $branch.StartPoint
            )
        }
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @(
            'push', '--quiet', '--set-upstream', 'origin',
            'main', 'feature-a', 'push-ahead', 'push-behind', 'push-diverged'
        )

        # Move pushed branches so each differs from its upstream in a known way.
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('update-ref', 'refs/heads/push-ahead', 'refs/heads/feature-a')
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('update-ref', 'refs/heads/push-behind', 'refs/heads/main')
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('update-ref', 'refs/heads/push-diverged', 'refs/heads/side')

        $unrelatedCommit = Invoke-TestGit -Path $repoPath -ArgumentList @(
            'commit-tree', 'main^{tree}', '-m', 'Start unrelated history'
        )
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('update-ref', 'refs/heads/unrelated', $unrelatedCommit)
        $null = Invoke-TestGit -Path $repoPath -ArgumentList @('update-ref', 'refs/remotes/upstream/main', 'refs/heads/main')

        return [pscustomobject]@{
            HooksPath = $hooksPath
            RepoPath  = $repoPath
        }
    }

    function ConvertFrom-PrContext {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            [string[]]$Text
        )

        $lines = @(($Text -join "`n") -split "`r?`n")
        $header = [ordered]@{}
        $headerLines = [System.Collections.Generic.List[string]]::new()
        $sectionLines = [ordered]@{}
        $section = $null
        foreach ($line in $lines) {
            if ($line -match '^\[(?<name>[a-z_]+)\]$') {
                $section = $Matches['name']
                $sectionLines[$section] = [System.Collections.Generic.List[string]]::new()
            }
            elseif ($section) {
                if ($line) {
                    $sectionLines[$section].Add($line)
                }
            }
            elseif ($line -match '^(?<key>[a-z_]+): (?<value>.*)$') {
                $header[$Matches['key']] = $Matches['value']
                $headerLines.Add($line)
            }
        }

        $sections = [ordered]@{}
        foreach ($name in $sectionLines.Keys) {
            $sections[$name] = $sectionLines[$name].ToArray()
        }

        return [pscustomobject]@{
            Marker      = $lines[0]
            Header      = $header
            HeaderLines = $headerLines.ToArray()
            Sections    = $sections
        }
    }

    function Get-CollectorContext {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$Base,

            [Parameter(Mandatory = $false)]
            [string]$Head = ''
        )

        Push-Location -LiteralPath $Path
        try {
            $text = Get-PullRequestContext -Base $Base -Head $Head
        }
        finally {
            Pop-Location
        }
        return ConvertFrom-PrContext -Text $text
    }

    function Invoke-ExternalCollector {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,

            [Parameter(Mandatory = $true)]
            [string]$FilePath,

            [Parameter(Mandatory = $true)]
            [AllowEmptyString()]
            [string[]]$ArgumentList
        )

        Push-Location -LiteralPath $Path
        try {
            $records = @(& $FilePath @ArgumentList 2>&1)
            $exitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output   = [string[]]@($records | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } |
                    ForEach-Object { [string]$_ })
            Error    = [string[]]@($records | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } |
                    ForEach-Object { $_.ToString() })
        }
    }

    $script:TempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "pr-context-tests-$([guid]::NewGuid().ToString('N'))"
    $null = New-Item -ItemType Directory -Path $script:TempRoot -Force
    $script:Fixture = Initialize-StackFixture -Root $script:TempRoot
    $script:RepoPath = $script:Fixture.RepoPath
}

AfterAll {
    if ($script:TempRoot) {
        Remove-Item -LiteralPath $script:TempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Get-PullRequestBaseName' -Tag 'Unit' {
    It 'Returns <Expected> for <BaseRef>' -ForEach @(
        @{ BaseRef = 'refs/remotes/origin/x'; Expected = 'x' }
        @{ BaseRef = 'origin/x'; Expected = 'x' }
        @{ BaseRef = 'refs/heads/x'; Expected = 'x' }
        @{ BaseRef = 'refs/remotes/upstream/x'; Expected = 'upstream/x' }
        @{ BaseRef = 'Origin/x'; Expected = 'Origin/x' }
        @{ BaseRef = 'REFS/HEADS/x'; Expected = 'REFS/HEADS/x' }
    ) {
        Get-PullRequestBaseName -BaseRef $BaseRef | Should -BeExactly $Expected
    }
}

Describe 'Get-PullRequestTemplate' -Tag 'Unit' {
    It 'Lists templates from .github, the root, and docs in that order' {
        Get-PullRequestTemplate -RepoRoot $script:RepoPath | Should -BeExactly $script:ExpectedTemplates
    }

    It 'Lists each template once regardless of letter case' {
        $templates = @(Get-PullRequestTemplate -RepoRoot $script:RepoPath)
        $templates | Group-Object | Where-Object { $_.Count -gt 1 } | Should -BeNullOrEmpty
        $templates | Should -HaveCount $script:ExpectedTemplates.Count
    }

    It 'Skips <RelativePath>, which is not a template' -ForEach @(
        @{ RelativePath = '.github/PULL_REQUEST_TEMPLATE/notes.txt' }
        @{ RelativePath = 'docs/guide.md' }
        @{ RelativePath = 'README.md' }
    ) {
        Test-Path -LiteralPath (Join-Path -Path $script:RepoPath -ChildPath $RelativePath) | Should -BeTrue
        Get-PullRequestTemplate -RepoRoot $script:RepoPath | Should -Not -Contain $RelativePath
    }

    It 'Returns nothing when no template exists' {
        @(Get-PullRequestTemplate -RepoRoot $TestDrive) | Should -HaveCount 0
    }
}

Describe 'Get-PullRequestContext' -Tag 'Unit' {
    Context 'when -Head names a stacked branch that is not checked out' {
        BeforeAll {
            $script:StackContext = Get-CollectorContext -Path $script:RepoPath -Base 'refs/heads/feature-a' -Head 'feature-b'
        }

        It 'Prints PR_CONTEXT_V1, the header fields, and the sections in order' {
            $script:StackContext.Marker | Should -BeExactly 'PR_CONTEXT_V1'
            $script:StackContext.Header.Keys | Should -BeExactly $script:HeaderKeys
            $script:StackContext.Sections.Keys | Should -BeExactly $script:SectionNames
        }

        It 'Reports <Key> as <Expected>' -ForEach @(
            @{ Key = 'head_branch'; Expected = 'feature-b' }
            @{ Key = 'base_ref'; Expected = 'refs/heads/feature-a' }
            @{ Key = 'base_branch'; Expected = 'feature-a' }
            @{ Key = 'ahead_count'; Expected = '1' }
            @{ Key = 'behind_count'; Expected = '0' }
            @{ Key = 'upstream_ref'; Expected = 'none' }
            @{ Key = 'upstream_ahead_count'; Expected = 'unknown' }
            @{ Key = 'upstream_behind_count'; Expected = 'unknown' }
            @{ Key = 'push_state'; Expected = 'missing' }
            @{ Key = 'branch_needs_push'; Expected = 'true' }
        ) {
            $script:StackContext.Header[$Key] | Should -BeExactly $Expected
        }

        It 'Reports the feature-a commit as the merge base' {
            $featureACommit = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('rev-parse', 'refs/heads/feature-a')
            $script:StackContext.Header['merge_base'] | Should -BeExactly $featureACommit
        }

        It 'Lists only the feature-b commit, file, and diff stat' {
            $script:StackContext.Sections['commits'] | Should -HaveCount 1
            $script:StackContext.Sections['commits'][0] | Should -Match '^[0-9a-f]{7,}\tAdd feature b$'
            $script:StackContext.Sections['changed_files'] | Should -BeExactly @("A`tb.txt")
            $script:StackContext.Sections['diff_stat'] -join "`n" | Should -Match 'b\.txt\s+\|\s+1 \+'
        }

        It 'Lists the templates in discovery order' {
            $script:StackContext.Sections['templates'] | Should -BeExactly $script:ExpectedTemplates
        }

        It 'Reports the status of the current checkout in [worktree] and leaves main checked out' {
            Add-Content -LiteralPath (Join-Path -Path $script:RepoPath -ChildPath 'README.md') -Value 'Local edit.'
            try {
                $context = Get-CollectorContext -Path $script:RepoPath -Base 'refs/heads/feature-a' -Head 'feature-b'
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', '--', 'README.md')
            }
            $context.Sections['worktree'] | Should -Contain ' M README.md'
            $context.Sections['changed_files'] | Should -BeExactly @("A`tb.txt")
            Invoke-TestGit -Path $script:RepoPath -ArgumentList @('branch', '--show-current') | Should -BeExactly 'main'
        }
    }

    Context 'when selecting the branch to describe' {
        It 'Uses the checked-out branch when -Head is omitted' {
            $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', 'feature-b')
            try {
                $context = Get-CollectorContext -Path $script:RepoPath -Base 'refs/heads/feature-a'
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', 'main')
            }
            $context.Header['head_branch'] | Should -BeExactly 'feature-b'
            $context.Header['ahead_count'] | Should -BeExactly '1'
        }

        It 'Accepts a refs/heads/ prefix in -Head' {
            $context = Get-CollectorContext -Path $script:RepoPath -Base 'refs/heads/feature-a' -Head 'refs/heads/feature-b'
            $context.Header['head_branch'] | Should -BeExactly 'feature-b'
            $context.Sections['commits'] | Should -HaveCount 1
        }

        It 'Describes the -Head branch while HEAD is detached' {
            $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', '--detach', 'main')
            try {
                $context = Get-CollectorContext -Path $script:RepoPath -Base 'refs/heads/feature-a' -Head 'feature-b'
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', 'main')
            }
            $context.Header['head_branch'] | Should -BeExactly 'feature-b'
        }

        It 'Requires -Head when HEAD is detached' {
            $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', '--detach', 'main')
            try {
                { Get-CollectorContext -Path $script:RepoPath -Base 'main' } |
                    Should -Throw -ExpectedMessage 'A named branch must be checked out, or pass -Head BRANCH.'
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', 'main')
            }
        }

        It 'Throws when -Head <HeadArgument> is not a local branch' -ForEach @(
            @{ HeadArgument = 'nope' }
            @{ HeadArgument = 'origin/feature-a' }
        ) {
            { Get-CollectorContext -Path $script:RepoPath -Base 'main' -Head $HeadArgument } |
                Should -Throw -ExpectedMessage "'$HeadArgument' is not a local branch."
        }
    }

    Context 'when resolving -Base' {
        It 'Resolves -Base <BaseArgument> to <ExpectedRef>' -ForEach @(
            @{ BaseArgument = 'auto'; ExpectedRef = 'origin/main'; ExpectedBranch = 'main'; ExpectedAhead = 2 }
            @{ BaseArgument = 'main'; ExpectedRef = 'origin/main'; ExpectedBranch = 'main'; ExpectedAhead = 2 }
            @{ BaseArgument = 'local-main'; ExpectedRef = 'local-main'; ExpectedBranch = 'local-main'; ExpectedAhead = 2 }
            @{ BaseArgument = 'origin/feature-a'; ExpectedRef = 'origin/feature-a'; ExpectedBranch = 'feature-a'; ExpectedAhead = 1 }
            @{ BaseArgument = 'refs/heads/feature-a'; ExpectedRef = 'refs/heads/feature-a'; ExpectedBranch = 'feature-a'; ExpectedAhead = 1 }
            @{ BaseArgument = 'refs/remotes/origin/main'; ExpectedRef = 'refs/remotes/origin/main'; ExpectedBranch = 'main'; ExpectedAhead = 2 }
            @{ BaseArgument = 'refs/remotes/upstream/main'; ExpectedRef = 'refs/remotes/upstream/main'; ExpectedBranch = 'upstream/main'; ExpectedAhead = 2 }
        ) {
            $context = Get-CollectorContext -Path $script:RepoPath -Base $BaseArgument -Head 'feature-b'
            $context.Header['base_ref'] | Should -BeExactly $ExpectedRef
            $context.Header['base_branch'] | Should -BeExactly $ExpectedBranch
            $context.Header['ahead_count'] | Should -BeExactly "$ExpectedAhead"
            $context.Sections['commits'] | Should -HaveCount $ExpectedAhead
        }

        It 'Lists both stacked commits, newest first, against -Base main' {
            $context = Get-CollectorContext -Path $script:RepoPath -Base 'main' -Head 'feature-b'
            $context.Sections['commits'] -replace '^[0-9a-f]+\t', '' | Should -BeExactly @('Add feature b', 'Add feature a')
        }

        It 'Uses origin/HEAD for -Base auto when it is set' {
            $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('remote', 'set-head', 'origin', 'feature-a')
            try {
                $context = Get-CollectorContext -Path $script:RepoPath -Base 'auto' -Head 'feature-b'
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('remote', 'set-head', 'origin', '--delete')
            }
            $context.Header['base_ref'] | Should -BeExactly 'origin/feature-a'
            $context.Header['base_branch'] | Should -BeExactly 'feature-a'
        }

        It 'Throws when the base ref is not available locally' {
            { Get-CollectorContext -Path $script:RepoPath -Base 'nope' -Head 'feature-b' } |
                Should -Throw -ExpectedMessage "Base ref 'nope' is unavailable locally. Fetch it or pass another ref."
        }

        It 'Throws when the branch shares no history with the base' {
            { Get-CollectorContext -Path $script:RepoPath -Base 'main' -Head 'unrelated' } |
                Should -Throw -ExpectedMessage "No merge base exists between 'unrelated' and 'origin/main'."
        }
    }

    Context 'when reporting push state' {
        It 'Reports <PushState> for <Branch>' -ForEach @(
            @{ Branch = 'feature-b'; UpstreamRef = 'none'; UpstreamAhead = 'unknown'; UpstreamBehind = 'unknown'; PushState = 'missing'; NeedsPush = 'true' }
            @{ Branch = 'feature-a'; UpstreamRef = 'origin/feature-a'; UpstreamAhead = '0'; UpstreamBehind = '0'; PushState = 'current'; NeedsPush = 'false' }
            @{ Branch = 'push-ahead'; UpstreamRef = 'origin/push-ahead'; UpstreamAhead = '1'; UpstreamBehind = '0'; PushState = 'ahead'; NeedsPush = 'true' }
            @{ Branch = 'push-behind'; UpstreamRef = 'origin/push-behind'; UpstreamAhead = '0'; UpstreamBehind = '1'; PushState = 'behind'; NeedsPush = 'false' }
            @{ Branch = 'push-diverged'; UpstreamRef = 'origin/push-diverged'; UpstreamAhead = '1'; UpstreamBehind = '1'; PushState = 'diverged'; NeedsPush = 'false' }
        ) {
            $header = (Get-CollectorContext -Path $script:RepoPath -Base 'main' -Head $Branch).Header
            $header['upstream_ref'] | Should -BeExactly $UpstreamRef
            $header['upstream_ahead_count'] | Should -BeExactly $UpstreamAhead
            $header['upstream_behind_count'] | Should -BeExactly $UpstreamBehind
            $header['push_state'] | Should -BeExactly $PushState
            $header['branch_needs_push'] | Should -BeExactly $NeedsPush
        }
    }

    Context 'when the repository has no origin remote' {
        BeforeAll {
            $script:LocalRepoPath = Join-Path -Path $script:TempRoot -ChildPath 'local-only'
            Initialize-TestRepository -Path $script:LocalRepoPath -HooksPath $script:Fixture.HooksPath
            Write-TestFile -Root $script:LocalRepoPath -RelativePath 'README.md'
            $null = Invoke-TestGit -Path $script:LocalRepoPath -ArgumentList @('add', '--all')
            $null = Invoke-TestGit -Path $script:LocalRepoPath -ArgumentList @('commit', '--quiet', '-m', 'Add readme')
        }

        It 'Uses the local main branch for -Base auto' {
            $context = Get-CollectorContext -Path $script:LocalRepoPath -Base 'auto'
            $context.Header['head_branch'] | Should -BeExactly 'main'
            $context.Header['base_ref'] | Should -BeExactly 'main'
            $context.Header['push_state'] | Should -BeExactly 'missing'
        }

        It 'Throws for -Base auto when neither origin/main nor main exists' {
            $null = Invoke-TestGit -Path $script:LocalRepoPath -ArgumentList @('branch', '-m', 'main', 'trunk')
            try {
                { Get-CollectorContext -Path $script:LocalRepoPath -Base 'auto' } |
                    Should -Throw -ExpectedMessage 'Unable to resolve the remote default branch. Pass -Base REF.'
            }
            finally {
                $null = Invoke-TestGit -Path $script:LocalRepoPath -ArgumentList @('branch', '-m', 'trunk', 'main')
            }
        }
    }

    Context 'when git or a repository is unavailable' {
        It 'Throws when git is not on PATH' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
            { Get-CollectorContext -Path $TestDrive -Base 'main' } |
                Should -Throw -ExpectedMessage 'Git is required but was not found on PATH.'
        }

        It 'Throws outside a git repository' {
            { Get-CollectorContext -Path $TestDrive -Base 'main' } |
                Should -Throw -ExpectedMessage 'Git command failed: git rev-parse --show-toplevel'
        }
    }
}

Describe 'Collect-Context.ps1 entry point' -Tag 'Unit' {
    BeforeAll {
        $script:PwshPath = (Get-Process -Id $PID).Path
    }

    It 'Prints the context and exits 0' {
        $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $script:PowerShellScript,
            '-Head', 'feature-b', '-Base', 'refs/heads/feature-a'
        )
        $result.ExitCode | Should -Be 0 -Because ($result.Error -join "`n")
        $context = ConvertFrom-PrContext -Text $result.Output
        $context.Marker | Should -BeExactly 'PR_CONTEXT_V1'
        $context.Header['head_branch'] | Should -BeExactly 'feature-b'
        $context.Header['base_branch'] | Should -BeExactly 'feature-a'
    }

    It 'Exits 1 and reports the error when -Head is not a local branch' {
        $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $script:PowerShellScript, '-Head', 'nope', '-Base', 'main'
        )
        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeNullOrEmpty
        $result.Error -join "`n" | Should -Match ([regex]::Escape("Collect-Context failed: 'nope' is not a local branch."))
    }

    It 'Exits 1 and reports the error when -Head is empty' {
        $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath $script:PwshPath -ArgumentList @(
            '-NoProfile', '-NonInteractive', '-File', $script:PowerShellScript, '-Head', '', '-Base', 'main'
        )
        $result.ExitCode | Should -Be 1
        $result.Output | Should -BeNullOrEmpty
        $result.Error -join "`n" | Should -Match ([regex]::Escape('Collect-Context failed: -Head requires a branch name.'))
    }
}

Describe 'collect-context.sh' -Tag 'Unit' -Skip:(-not $script:BashAvailable) {
    Context 'when compared with Collect-Context.ps1' {
        It 'Reports the same header, commits, changed files, and templates for <Label>' -ForEach @(
            @{ Label = '--head feature-b --base refs/heads/feature-a'; HeadArgument = 'feature-b'; BaseArgument = 'refs/heads/feature-a' }
            @{ Label = '--head feature-b --base main'; HeadArgument = 'feature-b'; BaseArgument = 'main' }
            @{ Label = '--head refs/heads/feature-b --base refs/remotes/upstream/main'; HeadArgument = 'refs/heads/feature-b'; BaseArgument = 'refs/remotes/upstream/main' }
            @{ Label = '--head push-diverged --base auto'; HeadArgument = 'push-diverged'; BaseArgument = 'auto' }
            @{ Label = '--head push-ahead --base auto'; HeadArgument = 'push-ahead'; BaseArgument = 'auto' }
            @{ Label = '--head push-behind --base auto'; HeadArgument = 'push-behind'; BaseArgument = 'auto' }
            @{ Label = '--base auto with main checked out'; HeadArgument = ''; BaseArgument = 'auto' }
        ) {
            $arguments = @($script:BashScript, '--base', $BaseArgument)
            if ($HeadArgument) {
                $arguments += @('--head', $HeadArgument)
            }
            $bash = Invoke-ExternalCollector -Path $script:RepoPath -FilePath 'bash' -ArgumentList $arguments
            $bash.ExitCode | Should -Be 0 -Because ($bash.Error -join "`n")
            $bashContext = ConvertFrom-PrContext -Text $bash.Output
            $powerShellContext = Get-CollectorContext -Path $script:RepoPath -Base $BaseArgument -Head $HeadArgument

            $bashContext.Marker | Should -BeExactly 'PR_CONTEXT_V1'
            $bashContext.Sections.Keys | Should -BeExactly $script:SectionNames
            $bashContext.HeaderLines | Should -BeExactly $powerShellContext.HeaderLines
            foreach ($section in @('commits', 'changed_files', 'templates')) {
                $bashContext.Sections[$section] -join "`n" |
                    Should -BeExactly ($powerShellContext.Sections[$section] -join "`n") -Because "[$section] must match"
            }
            $bashContext.Sections['templates'] | Should -BeExactly $script:ExpectedTemplates
        }
    }

    Context 'when the branch cannot be described' {
        It 'Exits 1 for --head <HeadArgument>' -ForEach @(
            @{ HeadArgument = 'nope' }
            @{ HeadArgument = 'origin/feature-a' }
        ) {
            $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath 'bash' -ArgumentList @(
                $script:BashScript, '--head', $HeadArgument, '--base', 'main'
            )
            $result.ExitCode | Should -Be 1
            $result.Output | Should -BeNullOrEmpty
            $result.Error | Should -Contain "Error: '$HeadArgument' is not a local branch."
        }

        It 'Exits 1 for an empty --head' {
            $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath 'bash' -ArgumentList @(
                $script:BashScript, '--head', '', '--base', 'main'
            )
            $result.ExitCode | Should -Be 1
            $result.Output | Should -BeNullOrEmpty
            $result.Error | Should -Contain 'Error: --head requires a branch name.'
        }

        It 'Exits 1 when HEAD is detached and --head is omitted' {
            $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', '--detach', 'main')
            try {
                $result = Invoke-ExternalCollector -Path $script:RepoPath -FilePath 'bash' -ArgumentList @(
                    $script:BashScript, '--base', 'main'
                )
            }
            finally {
                $null = Invoke-TestGit -Path $script:RepoPath -ArgumentList @('checkout', '--quiet', 'main')
            }
            $result.ExitCode | Should -Be 1
            $result.Error | Should -Contain 'Error: A named branch must be checked out, or pass --head BRANCH.'
        }
    }
}
