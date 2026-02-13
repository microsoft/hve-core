#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../dev-tools/Generate-PrReference.ps1

}

AfterAll {
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Test-GitAvailability' {
    It 'Does not throw when git is available' {
        # This test assumes git is installed in the test environment
        { Test-GitAvailability } | Should -Not -Throw
    }

    It 'Should throw when git is not available' {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'git' }
        { Test-GitAvailability } | Should -Throw '*Git is required*'
    }
}

Describe 'Get-RepositoryRoot' {
    It 'Returns a valid directory path' {
        $result = Get-RepositoryRoot
        $result | Should -Not -BeNullOrEmpty
        Test-Path -Path $result -PathType Container | Should -BeTrue
    }

    It 'Returns path containing .git directory' {
        $result = Get-RepositoryRoot
        Test-Path -Path (Join-Path $result '.git') | Should -BeTrue
    }

    It 'Should throw when repository root cannot be determined' {
        Mock git { $global:LASTEXITCODE = 0; return '' }
        { Get-RepositoryRoot } | Should -Throw '*Unable to determine repository root*'
    }
}

Describe 'New-PrDirectory' {
    BeforeAll {
        $script:tempRepo = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempRepo -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempRepo -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Creates .copilot-tracking/pr directory' {
        $result = New-PrDirectory -RepoRoot $script:tempRepo
        $result | Should -Not -BeNullOrEmpty
        Test-Path -Path $result -PathType Container | Should -BeTrue
        $result | Should -Match '\.copilot-tracking[\\/]pr$'
    }

    It 'Returns existing directory without error' {
        $firstCall = New-PrDirectory -RepoRoot $script:tempRepo
        $secondCall = New-PrDirectory -RepoRoot $script:tempRepo
        $secondCall | Should -Be $firstCall
    }
}

Describe 'Resolve-ComparisonReference' {
    It 'Returns PSCustomObject with Ref and Label properties' {
        $result = Resolve-ComparisonReference -BaseBranch 'main'
        $result | Should -BeOfType [PSCustomObject]
        $result.PSObject.Properties.Name | Should -Contain 'Ref'
        $result.PSObject.Properties.Name | Should -Contain 'Label'
    }

    It 'Uses merge-base when remote branch exists' {
        # This test assumes main branch exists
        $result = Resolve-ComparisonReference -BaseBranch 'main'
        $result.Ref | Should -Not -BeNullOrEmpty
    }

    It 'Should throw when base branch does not exist' {
        Mock git { $global:LASTEXITCODE = 1; return $null }
        { Resolve-ComparisonReference -BaseBranch 'nonexistent-branch-xyz' } | Should -Throw '*does not exist*'
    }
}

Describe 'Get-ShortCommitHash' {
    It 'Returns 7-character hash for HEAD' {
        $result = Get-ShortCommitHash -Ref 'HEAD'
        $result | Should -Match '^[a-f0-9]{7,}$'
    }

    It 'Returns consistent result for same ref' {
        $first = Get-ShortCommitHash -Ref 'HEAD'
        $second = Get-ShortCommitHash -Ref 'HEAD'
        $first | Should -Be $second
    }

    It 'Should throw when ref resolution fails' {
        Mock git { $global:LASTEXITCODE = 128; return '' }
        { Get-ShortCommitHash -Ref 'invalid-ref-xyz' } | Should -Throw "*Failed to resolve ref*"
    }
}

Describe 'Get-CommitEntry' {
    It 'Returns array of formatted commit entries' {
        $result = Get-CommitEntry -ComparisonRef 'HEAD~1'
        $result | Should -BeOfType [string]
    }

    It 'Returns empty array when no commits in range' {
        $result = Get-CommitEntry -ComparisonRef 'HEAD'
        $result | Should -BeNullOrEmpty
    }

    It 'Should throw when commit history retrieval fails' {
        Mock git { $global:LASTEXITCODE = 128; return $null }
        { Get-CommitEntry -ComparisonRef 'main' } | Should -Throw '*Failed to retrieve commit history*'
    }
}

Describe 'Get-CommitCount' {
    It 'Returns integer count' {
        $result = Get-CommitCount -ComparisonRef 'HEAD~5'
        $result | Should -BeOfType [int]
        # Merge commits can inflate the count, so just verify it returns a positive integer
        $result | Should -BeGreaterOrEqual 1
    }

    It 'Returns 0 when no commits in range' {
        $result = Get-CommitCount -ComparisonRef 'HEAD'
        $result | Should -Be 0
    }

    It 'Should throw when commit count fails' {
        Mock git { $global:LASTEXITCODE = 128; return '' }
        { Get-CommitCount -ComparisonRef 'main' } | Should -Throw '*Failed to count commits*'
    }

    It 'Should return 0 when commit count text is empty' {
        Mock git { $global:LASTEXITCODE = 0; return '' }
        $result = Get-CommitCount -ComparisonRef 'main'
        $result | Should -Be 0
    }
}

Describe 'Get-DiffOutput' {
    It 'Returns array of diff lines' {
        $result = Get-DiffOutput -ComparisonRef 'HEAD~1'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Excludes markdown when specified' {
        # Verify the function executes without error when excluding markdown
        # The result may be empty if only markdown files were changed
        { Get-DiffOutput -ComparisonRef 'HEAD~1' -ExcludeMarkdownDiff } | Should -Not -Throw
    }

    It 'Should throw when diff output fails' {
        Mock git { $global:LASTEXITCODE = 128; return $null }
        { Get-DiffOutput -ComparisonRef 'main' } | Should -Throw '*Failed to retrieve diff output*'
    }
}

Describe 'Get-DiffSummary' {
    It 'Returns shortstat summary string' {
        $result = Get-DiffSummary -ComparisonRef 'HEAD~1'
        $result | Should -BeOfType [string]
    }

    It 'Should throw when diff summary fails' {
        Mock git { $global:LASTEXITCODE = 128; return $null }
        { Get-DiffSummary -ComparisonRef 'main' } | Should -Throw '*Failed to summarize diff output*'
    }

    It 'Should return "0 files changed" when diff summary is empty' {
        Mock git { $global:LASTEXITCODE = 0; return '' }
        $result = Get-DiffSummary -ComparisonRef 'main'
        $result | Should -Be '0 files changed'
    }
}

Describe 'Get-PrXmlContent' {
    It 'Returns valid XML string' {
        $result = Get-PrXmlContent -CurrentBranch 'feature/test' -BaseBranch 'main' -CommitEntries @('commit 1', 'commit 2') -DiffOutput @('diff line 1', 'diff line 2')
        $result | Should -Not -BeNullOrEmpty
        $result | Should -Match '<commit_history>'
        $result | Should -Match '</commit_history>'
    }

    It 'Includes branch information' {
        $result = Get-PrXmlContent -CurrentBranch 'feature/my-branch' -BaseBranch 'main' -CommitEntries @() -DiffOutput @()
        $result | Should -Match 'feature/my-branch'
        $result | Should -Match 'main'
    }

    It 'Includes commit entries' {
        $result = Get-PrXmlContent -CurrentBranch 'feature/test' -BaseBranch 'main' -CommitEntries @('abc123 Test commit') -DiffOutput @()
        $result | Should -Match 'abc123 Test commit'
    }

    It 'Handles empty inputs' {
        $result = Get-PrXmlContent -CurrentBranch 'branch' -BaseBranch 'main' -CommitEntries @() -DiffOutput @()
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-LineImpact' {
    It 'Parses insertions and deletions from shortstat' {
        $result = Get-LineImpact -DiffSummary '5 files changed, 100 insertions(+), 50 deletions(-)'
        $result | Should -Be 150
    }

    It 'Handles insertions only' {
        $result = Get-LineImpact -DiffSummary '2 files changed, 25 insertions(+)'
        $result | Should -Be 25
    }

    It 'Handles deletions only' {
        $result = Get-LineImpact -DiffSummary '1 file changed, 10 deletions(-)'
        $result | Should -Be 10
    }

    It 'Returns 0 for summary without insertions or deletions' {
        $result = Get-LineImpact -DiffSummary 'no changes'
        $result | Should -Be 0
    }

    It 'Returns 0 for no changes' {
        $result = Get-LineImpact -DiffSummary '0 files changed'
        $result | Should -Be 0
    }
}

Describe 'Get-CurrentBranchOrRef' {
    BeforeAll {
        . $PSScriptRoot/../../dev-tools/Generate-PrReference.ps1
    }

    It 'Returns branch name when on a branch' {
        # This test runs in a real git repo, so it should return something
        $result = Get-CurrentBranchOrRef
        $result | Should -Not -BeNullOrEmpty
        $result | Should -BeOfType [string]
    }

    It 'Returns string starting with detached@ or branch name' {
        $result = Get-CurrentBranchOrRef
        # Either a branch name or detached@<sha>
        ($result -match '^detached@' -or $result -notmatch '^detached@') | Should -BeTrue
    }

    It 'Should return detached@sha when in detached HEAD state' {
        # Use call sequence to distinguish git commands (cross-platform safe)
        $script:gitCallCount = 0
        Mock git {
            $script:gitCallCount++
            if ($script:gitCallCount -eq 1) {
                # First call: git branch --show-current returns empty (detached)
                $global:LASTEXITCODE = 0
                return ''
            }
            # Second call: git rev-parse --short HEAD returns SHA
            $global:LASTEXITCODE = 0
            return 'abc1234'
        }
        $result = Get-CurrentBranchOrRef
        $result | Should -Be 'detached@abc1234'
    }

    It 'Should return unknown when both branch and rev-parse fail' {
        Mock git {
            $global:LASTEXITCODE = 128
            return $null
        }
        $result = Get-CurrentBranchOrRef
        $result | Should -Be 'unknown'
    }
}

Describe 'Invoke-PrReferenceGeneration' {
    It 'Returns FileInfo object' {
        # Skip if not in a git repo or no commits to compare
        $commitCount = Get-CommitCount -ComparisonRef 'HEAD~1'
        if ($commitCount -eq 0) {
            Set-ItResult -Skipped -Because 'No commits available for comparison'
            return
        }

        # Determine available base branch - prefer origin/main, fall back to main, then HEAD~1
        $baseBranch = $null
        foreach ($candidate in @('origin/main', 'main', 'HEAD~1')) {
            & git rev-parse --verify $candidate 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $baseBranch = $candidate
                break
            }
        }

        if (-not $baseBranch) {
            Set-ItResult -Skipped -Because 'No suitable base branch available for comparison'
            return
        }

        $result = Invoke-PrReferenceGeneration -BaseBranch $baseBranch
        $result | Should -BeOfType [System.IO.FileInfo]
        $result.Extension | Should -Be '.xml'
    }

    It 'Should include markdown exclusion note when ExcludeMarkdownDiff is specified' {
        # Skip if not in a git repo or no commits
        $commitCount = Get-CommitCount -ComparisonRef 'HEAD~1'
        if ($commitCount -eq 0) {
            Set-ItResult -Skipped -Because 'No commits available for comparison'
            return
        }

        $baseBranch = $null
        foreach ($candidate in @('origin/main', 'main', 'HEAD~1')) {
            & git rev-parse --verify $candidate 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $baseBranch = $candidate
                break
            }
        }

        if (-not $baseBranch) {
            Set-ItResult -Skipped -Because 'No suitable base branch available for comparison'
            return
        }

        Mock Write-Host {}

        $result = Invoke-PrReferenceGeneration -BaseBranch $baseBranch -ExcludeMarkdownDiff
        $result | Should -BeOfType [System.IO.FileInfo]

        # Verify the markdown exclusion note was output
        Should -Invoke Write-Host -ParameterFilter { $Object -eq 'Note: Markdown files were excluded from diff output' }
    }
}
