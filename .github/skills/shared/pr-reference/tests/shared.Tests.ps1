#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../scripts/shared.psm1') -Force
}

Describe 'Get-RepositoryRoot' {
    Context 'Default (fallback) mode' {
        It 'Returns a valid directory when in a git repository' {
            $result = Get-RepositoryRoot
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $result -PathType Container | Should -BeTrue
        }

        It 'Returns path containing .git directory' {
            $result = Get-RepositoryRoot
            Test-Path -Path (Join-Path $result '.git') | Should -BeTrue
        }

        It 'Falls back to current directory when git fails' {
            Mock git { $global:LASTEXITCODE = 128; return $null } -ModuleName shared
            $result = Get-RepositoryRoot
            $result | Should -Be $PWD.Path
        }

        It 'Falls back to current directory when git returns empty' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            $result = Get-RepositoryRoot
            $result | Should -Be $PWD.Path
        }
    }

    Context 'Strict mode' {
        It 'Returns a valid directory when in a git repository' {
            $result = Get-RepositoryRoot -Strict
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $result -PathType Container | Should -BeTrue
        }

        It 'Throws when repository root cannot be determined' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            { Get-RepositoryRoot -Strict } | Should -Throw '*Unable to determine repository root*'
        }
    }
}

Describe 'Resolve-DefaultBranch' {
    Context 'Successful resolution' {
        It 'Returns a branch reference' {
            $result = Resolve-DefaultBranch
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }

        It 'Returns origin-prefixed branch name' {
            $result = Resolve-DefaultBranch
            $result | Should -Match '^origin/'
        }
    }

    Context 'Fallback behavior' {
        It 'Falls back to origin/main when symbolic-ref fails' {
            Mock git { $global:LASTEXITCODE = 1; return $null } -ModuleName shared
            $result = Resolve-DefaultBranch
            $result | Should -Be 'origin/main'
        }

        It 'Falls back to origin/main when symbolic-ref returns empty' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            $result = Resolve-DefaultBranch
            $result | Should -Be 'origin/main'
        }
    }
}

Describe 'Build-PathspecExclusions' {
    Context 'Extension exclusions' {
        It 'Returns pathspec for single extension' {
            $result = Build-PathspecExclusions -Extensions @('yml')
            $result | Should -Contain ':!*.yml'
        }

        It 'Returns pathspecs for multiple extensions' {
            $result = Build-PathspecExclusions -Extensions @('yml', 'json', 'png')
            $result.Count | Should -Be 3
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!*.json'
            $result | Should -Contain ':!*.png'
        }

        It 'Strips leading dots from extensions' {
            $result = Build-PathspecExclusions -Extensions @('.yml', '.json')
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!*.json'
        }

        It 'Returns empty array for empty extensions input' {
            $result = Build-PathspecExclusions -Extensions @()
            $result.Count | Should -Be 0
        }

        It 'Skips empty extension strings' {
            $result = Build-PathspecExclusions -Extensions @('yml', '', 'json')
            $result.Count | Should -Be 2
        }
    }

    Context 'Path exclusions' {
        It 'Returns pathspec for single path' {
            $result = Build-PathspecExclusions -Paths @('docs/')
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns pathspecs for multiple paths' {
            $result = Build-PathspecExclusions -Paths @('docs/', '.github/skills/')
            $result.Count | Should -Be 2
            $result | Should -Contain ':!docs/**'
            $result | Should -Contain ':!.github/skills/**'
        }

        It 'Strips trailing slashes from paths' {
            $result = Build-PathspecExclusions -Paths @('docs/')
            $result | Should -Contain ':!docs/**'
        }

        It 'Handles paths without trailing slash' {
            $result = Build-PathspecExclusions -Paths @('docs')
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns empty array for empty paths input' {
            $result = Build-PathspecExclusions -Paths @()
            $result.Count | Should -Be 0
        }

        It 'Skips empty path strings' {
            $result = Build-PathspecExclusions -Paths @('docs/', '', '.github/')
            $result.Count | Should -Be 2
        }
    }

    Context 'Combined exclusions' {
        It 'Returns pathspecs for both extensions and paths' {
            $result = Build-PathspecExclusions -Extensions @('yml') -Paths @('docs/')
            $result.Count | Should -Be 2
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns empty array when both inputs are empty' {
            $result = Build-PathspecExclusions -Extensions @() -Paths @()
            $result.Count | Should -Be 0
        }
    }

    Context 'Default parameters' {
        It 'Returns empty array when called without parameters' {
            $result = Build-PathspecExclusions
            $result.Count | Should -Be 0
        }
    }
}

Describe 'Resolve-UnquotedGitPath' {
    It 'Returns unquoted path unchanged when no quotes or escapes' {
        $result = Resolve-UnquotedGitPath -Path 'src/file.ts'
        $result | Should -Be 'src/file.ts'
    }

    It 'Strips surrounding quotes' {
        $result = Resolve-UnquotedGitPath -Path '"src/file.ts"'
        $result | Should -Be 'src/file.ts'
    }

    It 'Decodes octal UTF-8 escapes' {
        # \342\234\223 represents UTF-8 checkmark
        $result = Resolve-UnquotedGitPath -Path '"src/\342\234\223.txt"'
        $result | Should -Be "src/$([char]0x2713).txt"
    }

    It 'Decodes escaped characters' {
        $result = Resolve-UnquotedGitPath -Path '"src/tab\there.txt"'
        $result | Should -Be "src/tab`there.txt"
    }

    It 'Returns empty string for null or empty input' {
        $result = Resolve-UnquotedGitPath -Path $null
        $result | Should -Be ''
    }
}

Describe 'Format-PathOrdinal' {
    It 'Sorts paths using ordinal comparison matching LC_ALL=C sort -f' {
        $items = @(
            [pscustomobject]@{ Path = 'foo_bar.ts' }
            [pscustomobject]@{ Path = 'foo-bar.ts' }
            [pscustomobject]@{ Path = 'foo.ts' }
        )
        $sorted = $items | Format-PathOrdinal
        $sorted[0].Path | Should -Be 'foo-bar.ts'
        $sorted[1].Path | Should -Be 'foo.ts'
        $sorted[2].Path | Should -Be 'foo_bar.ts'
    }

    It 'Sorts string arrays using ordinal comparison' {
        $items = @('b.ts', 'A.ts', 'a.ts')
        $sorted = $items | Format-PathOrdinal
        $sorted[0] | Should -Be 'A.ts'
        $sorted[1] | Should -Be 'a.ts'
        $sorted[2] | Should -Be 'b.ts'
    }
}

