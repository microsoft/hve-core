#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for LintingHelpers.psm1 module
.DESCRIPTION
    Comprehensive tests for all 3 exported functions in the LintingHelpers module:
    - Get-ChangedFilesFromGit
    - Get-FilesRecursive
    - Get-GitIgnorePatterns
#>

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    Import-Module $modulePath -Force
}

#region Get-ChangedFilesFromGit Tests

Describe 'Get-ChangedFilesFromGit' {
    Context 'Merge-base succeeds' {
        BeforeEach {
            # Mock git commands at module scope with proper LASTEXITCODE handling
            $changedFiles = @('scripts/test.ps1', 'docs/readme.md', 'config/settings.json')
            
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            Mock git {
                $global:LASTEXITCODE = 0
                return $changedFiles
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
            
            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Returns changed files filtered by extension' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1')
            $result | Should -Contain 'scripts/test.ps1'
            $result | Should -Not -Contain 'docs/readme.md'
            $result | Should -Not -Contain 'config/settings.json'
        }

        It 'Returns all files with wildcard extension' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*')
            $result.Count | Should -Be 3
        }

        It 'Returns files matching multiple extension patterns' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1', '*.md')
            $result | Should -Contain 'scripts/test.ps1'
            $result | Should -Contain 'docs/readme.md'
            $result | Should -Not -Contain 'config/settings.json'
        }

        It 'Uses default extension pattern when not specified' {
            $result = Get-ChangedFilesFromGit
            $result.Count | Should -Be 3
        }
    }

    Context 'Merge-base fails, HEAD~1 fallback' {
        BeforeEach {
            # Merge-base fails
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            # rev-parse succeeds for HEAD~1 check
            Mock git {
                $global:LASTEXITCODE = 0
                return 'HEAD~1-sha'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }
            
            # diff returns fallback file
            Mock git {
                $global:LASTEXITCODE = 0
                return @('fallback-file.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
            
            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Falls back to HEAD~1 comparison and returns files' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1')
            $result | Should -Contain 'fallback-file.ps1'
        }
    }

    Context 'Empty results' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
        }

        It 'Returns empty array when no files changed' {
            $result = Get-ChangedFilesFromGit
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'File existence filtering' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            Mock git {
                $global:LASTEXITCODE = 0
                return @('exists.ps1', 'deleted.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
            
            Mock Test-Path {
                param($Path)
                return $Path -eq 'exists.ps1'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Excludes files that no longer exist' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1')
            $result | Should -Contain 'exists.ps1'
            $result | Should -Not -Contain 'deleted.ps1'
        }
    }

    Context 'Empty and whitespace file entries' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            Mock git {
                $global:LASTEXITCODE = 0
                return @('valid.ps1', '', '   ', 'another.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
            
            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Filters out empty and whitespace entries' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1')
            $result | Should -Contain 'valid.ps1'
            $result | Should -Contain 'another.ps1'
            $result | Should -Not -Contain ''
            $result | Should -Not -Contain '   '
        }
    }

    Context 'Both merge-base and HEAD~1 fail, third fallback' {
        BeforeEach {
            # Merge-base fails
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            # rev-parse fails for HEAD~1 check
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }
            
            # diff returns files from third fallback (git diff --name-only HEAD)
            Mock git {
                $global:LASTEXITCODE = 0
                return @('unstaged-file.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
            
            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Falls back to git diff --name-only HEAD and returns files' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.ps1')
            $result | Should -Contain 'unstaged-file.ps1'
        }
    }

    Context 'Git diff command fails' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
            
            # Diff fails with non-zero exit code
            Mock git {
                $global:LASTEXITCODE = 1
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }
        }

        It 'Returns empty array when git diff fails' {
            $result = Get-ChangedFilesFromGit
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Exception during execution' {
        BeforeEach {
            Mock git {
                throw "Simulated git failure"
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }
        }

        It 'Catches exceptions and returns empty array' {
            $result = Get-ChangedFilesFromGit
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Warning and verbose output' {
        It 'Emits warning when git diff returns non-zero exit code' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 1
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            $output = Get-ChangedFilesFromGit 3>&1
            $warnings = @($output | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Emits warning when exception occurs' {
            Mock git {
                throw "Simulated git failure"
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            $warnings = Get-ChangedFilesFromGit 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Emits verbose message when merge-base succeeds' {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('file.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }

            $verbose = Get-ChangedFilesFromGit -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verbose | Should -Not -BeNullOrEmpty
        }

        It 'Emits verbose message when falling back to HEAD~1' {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return 'HEAD~1-sha'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('file.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }

            $verbose = Get-ChangedFilesFromGit -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            $verbose | Should -Not -BeNullOrEmpty
            ($verbose | Where-Object { $_.Message -match 'HEAD~1' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Custom BaseBranch parameter' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('file.md')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Passes custom BaseBranch to merge-base' {
            Get-ChangedFilesFromGit -BaseBranch 'origin/develop' -FileExtensions @('*.md')
            Should -Invoke git -ModuleName 'LintingHelpers' -ParameterFilter {
                $args[0] -eq 'merge-base' -and $args -contains 'origin/develop'
            }
        }

        It 'Uses default BaseBranch when not specified' {
            Get-ChangedFilesFromGit -FileExtensions @('*.md')
            Should -Invoke git -ModuleName 'LintingHelpers' -ParameterFilter {
                $args[0] -eq 'merge-base' -and $args -contains 'origin/main'
            }
        }
    }

    Context 'Mixed path separators' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return 'abc123def456789'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'merge-base' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('src/docs/readme.md', 'src\tests\test.md', 'docs/guide.md')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'diff' }

            Mock Test-Path { return $true } -ModuleName 'LintingHelpers' -ParameterFilter { $PathType -eq 'Leaf' }
        }

        It 'Handles files with forward slashes' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.md')
            $result | Should -Contain 'src/docs/readme.md'
        }

        It 'Handles files with backslashes' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.md')
            $result | Should -Contain 'src\tests\test.md'
        }

        It 'Returns correct count with mixed separators' {
            $result = Get-ChangedFilesFromGit -FileExtensions @('*.md')
            $result.Count | Should -Be 3
        }
    }
}

#endregion

#region Get-FilesRecursive Tests

Describe 'Get-FilesRecursive' {
    Context 'Basic file enumeration' {
        BeforeEach {
            New-Item -Path 'TestDrive:/scripts' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/scripts/test.ps1' -ItemType File -Force | Out-Null
            New-Item -Path 'TestDrive:/scripts/readme.md' -ItemType File -Force | Out-Null
            New-Item -Path 'TestDrive:/scripts/sub' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/scripts/sub/nested.ps1' -ItemType File -Force | Out-Null
        }

        It 'Finds files matching Include pattern' {
            $result = Get-FilesRecursive -Path 'TestDrive:/scripts' -Include @('*.ps1')
            $result.Count | Should -Be 2
            $result.Name | Should -Contain 'test.ps1'
            $result.Name | Should -Contain 'nested.ps1'
        }

        It 'Finds files with multiple Include patterns' {
            $result = Get-FilesRecursive -Path 'TestDrive:/scripts' -Include @('*.ps1', '*.md')
            $result.Count | Should -Be 3
        }

        It 'Does not include directories in results' {
            $result = Get-FilesRecursive -Path 'TestDrive:/scripts' -Include @('*')
            $result | ForEach-Object { $_.PSIsContainer | Should -BeFalse }
        }
    }

    Context 'Gitignore filtering' {
        BeforeEach {
            New-Item -Path 'TestDrive:/project' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/project/src' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/project/src/app.ps1' -ItemType File -Force | Out-Null
            New-Item -Path 'TestDrive:/project/node_modules' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/project/node_modules/pkg.ps1' -ItemType File -Force | Out-Null
            'node_modules/' | Set-Content 'TestDrive:/project/.gitignore'
        }

        It 'Excludes files matching gitignore patterns' {
            $result = Get-FilesRecursive -Path 'TestDrive:/project' `
                -Include @('*.ps1') `
                -GitIgnorePath 'TestDrive:/project/.gitignore'
            $result.Name | Should -Contain 'app.ps1'
            $result.Name | Should -Not -Contain 'pkg.ps1'
        }

        It 'Returns all files when gitignore path not provided' {
            $result = Get-FilesRecursive -Path 'TestDrive:/project' -Include @('*.ps1')
            $result.Count | Should -Be 2
        }
    }

    Context 'Invalid paths' {
        It 'Returns empty for non-existent path' {
            $result = Get-FilesRecursive -Path 'TestDrive:/nonexistent' -Include @('*.ps1')
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'No gitignore file' {
        BeforeEach {
            New-Item -Path 'TestDrive:/simple' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/simple/file.ps1' -ItemType File -Force | Out-Null
        }

        It 'Returns files when gitignore does not exist' {
            $result = Get-FilesRecursive -Path 'TestDrive:/simple' `
                -Include @('*.ps1') `
                -GitIgnorePath 'TestDrive:/simple/.gitignore'
            $result.Count | Should -Be 1
        }
    }

    Context 'Git ls-files code path at repo root' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return '/mock/repo'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('src/app.ps1', 'src/helper.psm1', 'tests/run.ps1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'ls-files' }

            Mock Resolve-Path {
                [PSCustomObject]@{ Path = '/mock/repo' }
            } -ModuleName 'LintingHelpers'

            Mock Test-Path { $true } -ModuleName 'LintingHelpers' -ParameterFilter {
                $LiteralPath -or ($Path -and $PathType -eq 'Leaf')
            }

            Mock Get-Item {
                [PSCustomObject]@{
                    FullName      = $LiteralPath
                    Name          = [System.IO.Path]::GetFileName($LiteralPath)
                    PSIsContainer = $false
                }
            } -ModuleName 'LintingHelpers'
        }

        It 'Calls git ls-files when path is inside the repository' {
            Get-FilesRecursive -Path '.' -Include @('*.ps1')
            Should -Invoke git -ModuleName 'LintingHelpers' -ParameterFilter {
                $args[0] -eq 'ls-files'
            }
        }

        It 'Returns FileInfo objects from git ls-files output' {
            $result = Get-FilesRecursive -Path '.' -Include @('*.ps1')
            $result | Should -Not -BeNullOrEmpty
            $result | ForEach-Object { $_.PSIsContainer | Should -BeFalse }
        }

        It 'Passes Include patterns as pathspecs at repo root' {
            Get-FilesRecursive -Path '.' -Include @('*.ps1', '*.psm1')
            Should -Invoke git -ModuleName 'LintingHelpers' -ParameterFilter {
                $args -contains '*.ps1' -and $args -contains '*.psm1'
            }
        }

        It 'Accepts GitIgnorePath without error on git path' {
            { Get-FilesRecursive -Path '.' -Include @('*.ps1') -GitIgnorePath '/nonexistent/.gitignore' } |
                Should -Not -Throw
        }
    }

    Context 'Git ls-files subdirectory scoping' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return '/mock/repo'
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }

            Mock git {
                $global:LASTEXITCODE = 0
                return @('src/app.ps1', 'src/helper.psm1')
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'ls-files' }

            Mock Resolve-Path {
                [PSCustomObject]@{ Path = '/mock/repo/src' }
            } -ModuleName 'LintingHelpers'

            Mock Test-Path { $true } -ModuleName 'LintingHelpers' -ParameterFilter {
                $LiteralPath -or ($Path -and $PathType -eq 'Leaf')
            }

            Mock Get-Item {
                [PSCustomObject]@{
                    FullName      = $LiteralPath
                    Name          = [System.IO.Path]::GetFileName($LiteralPath)
                    PSIsContainer = $false
                }
            } -ModuleName 'LintingHelpers'
        }

        It 'Scopes git ls-files to the specified subdirectory' {
            Get-FilesRecursive -Path './src' -Include @('*.ps1')
            Should -Invoke git -ModuleName 'LintingHelpers' -ParameterFilter {
                $args -contains '--' -and $args -contains 'src/'
            }
        }

        It 'Filters subdirectory results by Include patterns' {
            $result = Get-FilesRecursive -Path './src' -Include @('*.ps1')
            $result.Name | Should -Contain 'app.ps1'
            $result.Name | Should -Not -Contain 'helper.psm1'
        }
    }

    Context 'Git unavailable' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                return $null
            } -ModuleName 'LintingHelpers' -ParameterFilter { $args[0] -eq 'rev-parse' }

            New-Item -Path 'TestDrive:/nogit' -ItemType Directory -Force | Out-Null
            New-Item -Path 'TestDrive:/nogit/script.ps1' -ItemType File -Force | Out-Null
        }

        It 'Falls back to Get-ChildItem when git is unavailable' {
            $result = Get-FilesRecursive -Path 'TestDrive:/nogit' -Include @('*.ps1')
            $result.Count | Should -Be 1
            $result.Name | Should -Contain 'script.ps1'
        }
    }
}

#endregion

#region Get-GitIgnorePatterns Tests

Describe 'Get-GitIgnorePatterns' {
    Context 'Non-existent file' {
        It 'Returns empty for non-existent file' {
            $result = Get-GitIgnorePatterns -GitIgnorePath 'TestDrive:/nonexistent/.gitignore'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Empty file' {
        BeforeEach {
            New-Item -Path 'TestDrive:/.gitignore-empty' -ItemType File -Force | Out-Null
        }

        It 'Returns empty for empty file' {
            $result = Get-GitIgnorePatterns -GitIgnorePath 'TestDrive:/.gitignore-empty'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Pattern parsing' {
        It 'Skips comments and empty lines' {
            @('# Comment', '', 'node_modules/', '  ', '*.log') | Set-Content 'TestDrive:/.gitignore'
            $result = Get-GitIgnorePatterns -GitIgnorePath 'TestDrive:/.gitignore'
            $result.Count | Should -Be 2
        }

        It 'Converts directory patterns correctly' {
            $gitignorePath = Join-Path $TestDrive '.gitignore-dir'
            'node_modules/' | Set-Content $gitignorePath
            $result = @(Get-GitIgnorePatterns -GitIgnorePath $gitignorePath)
            $sep = [System.IO.Path]::DirectorySeparatorChar
            # Function wraps directory patterns with platform separator
            $result[0] | Should -Be "*${sep}node_modules${sep}*"
        }

        It 'Converts file patterns with paths correctly' {
            $gitignorePath = Join-Path $TestDrive '.gitignore-path'
            'build/output.log' | Set-Content $gitignorePath
            $result = @(Get-GitIgnorePatterns -GitIgnorePath $gitignorePath)
            $sep = [System.IO.Path]::DirectorySeparatorChar
            # Function normalizes paths and wraps with wildcards
            $result[0] | Should -Be "*${sep}build${sep}output.log*"
        }

        It 'Handles simple file patterns' {
            $gitignorePath = Join-Path $TestDrive '.gitignore-simple'
            '*.log' | Set-Content $gitignorePath
            $result = @(Get-GitIgnorePatterns -GitIgnorePath $gitignorePath)
            $sep = [System.IO.Path]::DirectorySeparatorChar
            # Function wraps simple patterns with wildcards
            $result[0] | Should -Be "*${sep}*.log${sep}*"
        }

        It 'Processes multiple patterns' {
            @('node_modules/', 'dist/', '*.tmp', 'logs/debug.log') | Set-Content 'TestDrive:/.gitignore-multi'
            $result = Get-GitIgnorePatterns -GitIgnorePath 'TestDrive:/.gitignore-multi'
            $result.Count | Should -Be 4
        }
    }
}

#endregion
