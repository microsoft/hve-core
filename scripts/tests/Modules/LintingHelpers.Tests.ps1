#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for LintingHelpers.psm1 module
.DESCRIPTION
    Comprehensive tests for all 7 exported functions in the LintingHelpers module:
    - Get-ChangedFilesFromGit
    - Get-FilesRecursive
    - Get-GitIgnorePatterns
    - Write-GitHubAnnotation
    - Set-GitHubOutput
    - Set-GitHubEnv
    - Write-GitHubStepSummary
#>

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '../../linting/Modules/LintingHelpers.psm1'
    $mockPath = Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1'

    Import-Module $modulePath -Force
    Import-Module $mockPath -Force
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

#region Write-GitHubAnnotation Tests

Describe 'Write-GitHubAnnotation' {
    Context 'Basic annotation types' {
        It 'Writes error annotation without properties' {
            $output = Write-GitHubAnnotation -Type 'error' -Message 'Test error' 6>&1
            $output | Should -Be '::error::Test error'
        }

        It 'Writes warning annotation without properties' {
            $output = Write-GitHubAnnotation -Type 'warning' -Message 'Test warning' 6>&1
            $output | Should -Be '::warning::Test warning'
        }

        It 'Writes notice annotation without properties' {
            $output = Write-GitHubAnnotation -Type 'notice' -Message 'Test notice' 6>&1
            $output | Should -Be '::notice::Test notice'
        }
    }

    Context 'Annotation with file property' {
        It 'Includes file property when specified' {
            $output = Write-GitHubAnnotation -Type 'warning' -Message 'File warning' -File 'test.ps1' 6>&1
            $output | Should -Be '::warning file=test.ps1::File warning'
        }
    }

    Context 'Annotation with line and column' {
        It 'Includes file and line properties' {
            $output = Write-GitHubAnnotation -Type 'notice' -Message 'Line notice' -File 'test.ps1' -Line 10 6>&1
            $output | Should -Be '::notice file=test.ps1,line=10::Line notice'
        }

        It 'Includes all properties when specified' {
            $output = Write-GitHubAnnotation -Type 'error' -Message 'Full error' -File 'test.ps1' -Line 10 -Column 5 6>&1
            $output | Should -Be '::error file=test.ps1,line=10,col=5::Full error'
        }

        It 'Omits line when zero' {
            $output = Write-GitHubAnnotation -Type 'error' -Message 'Zero line' -File 'test.ps1' -Line 0 6>&1
            $output | Should -Be '::error file=test.ps1::Zero line'
        }

        It 'Omits column when zero' {
            $output = Write-GitHubAnnotation -Type 'error' -Message 'Zero col' -File 'test.ps1' -Line 10 -Column 0 6>&1
            $output | Should -Be '::error file=test.ps1,line=10::Zero col'
        }
    }
}

#endregion

#region Set-GitHubOutput Tests

Describe 'Set-GitHubOutput' {
    BeforeAll {
        Save-GitHubEnvironment
    }

    AfterAll {
        Restore-GitHubEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockGitHubEnvironment
        }

        AfterEach {
            Remove-MockGitHubFiles -MockFiles $script:mockFiles
        }

        It 'Writes output to GITHUB_OUTPUT file' {
            Set-GitHubOutput -Name 'result' -Value 'success'
            $content = Get-Content $script:mockFiles.Output
            $content | Should -Contain 'result=success'
        }

        It 'Appends multiple outputs to file' {
            Set-GitHubOutput -Name 'first' -Value 'one'
            Set-GitHubOutput -Name 'second' -Value 'two'
            $content = Get-Content $script:mockFiles.Output
            $content | Should -Contain 'first=one'
            $content | Should -Contain 'second=two'
        }

        It 'Handles values with special characters' {
            Set-GitHubOutput -Name 'path' -Value 'C:\Users\test'
            $content = Get-Content $script:mockFiles.Output
            $content | Should -Contain 'path=C:\Users\test'
        }
    }

    Context 'Outside GitHub Actions environment' {
        BeforeEach {
            Clear-MockGitHubEnvironment
        }

        It 'Does not throw when GITHUB_OUTPUT is not set' {
            { Set-GitHubOutput -Name 'test' -Value 'value' } | Should -Not -Throw
        }
    }
}

#endregion

#region Set-GitHubEnv Tests

Describe 'Set-GitHubEnv' {
    BeforeAll {
        Save-GitHubEnvironment
    }

    AfterAll {
        Restore-GitHubEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockGitHubEnvironment
        }

        AfterEach {
            Remove-MockGitHubFiles -MockFiles $script:mockFiles
        }

        It 'Writes environment variable to GITHUB_ENV file' {
            Set-GitHubEnv -Name 'MY_VAR' -Value 'my_value'
            $content = Get-Content $script:mockFiles.Env
            $content | Should -Contain 'MY_VAR=my_value'
        }

        It 'Appends multiple environment variables' {
            Set-GitHubEnv -Name 'VAR1' -Value 'value1'
            Set-GitHubEnv -Name 'VAR2' -Value 'value2'
            $content = Get-Content $script:mockFiles.Env
            $content | Should -Contain 'VAR1=value1'
            $content | Should -Contain 'VAR2=value2'
        }
    }

    Context 'Outside GitHub Actions environment' {
        BeforeEach {
            Clear-MockGitHubEnvironment
        }

        It 'Does not throw when GITHUB_ENV is not set' {
            { Set-GitHubEnv -Name 'test' -Value 'value' } | Should -Not -Throw
        }
    }
}

#endregion

#region Write-GitHubStepSummary Tests

Describe 'Write-GitHubStepSummary' {
    BeforeAll {
        Save-GitHubEnvironment
    }

    AfterAll {
        Restore-GitHubEnvironment
    }

    Context 'In GitHub Actions environment' {
        BeforeEach {
            $script:mockFiles = Initialize-MockGitHubEnvironment
        }

        AfterEach {
            Remove-MockGitHubFiles -MockFiles $script:mockFiles
        }

        It 'Writes content to GITHUB_STEP_SUMMARY file' {
            Write-GitHubStepSummary -Content '# Test Summary'
            $content = Get-Content $script:mockFiles.Summary -Raw
            $content | Should -Match '# Test Summary'
        }

        It 'Appends multiple summary entries' {
            Write-GitHubStepSummary -Content '## Section 1'
            Write-GitHubStepSummary -Content '## Section 2'
            $content = Get-Content $script:mockFiles.Summary -Raw
            $content | Should -Match '## Section 1'
            $content | Should -Match '## Section 2'
        }

        It 'Handles markdown table content' {
            $table = @"
| Column 1 | Column 2 |
|----------|----------|
| Value 1  | Value 2  |
"@
            Write-GitHubStepSummary -Content $table
            $content = Get-Content $script:mockFiles.Summary -Raw
            $content | Should -Match 'Column 1'
            $content | Should -Match 'Value 1'
        }
    }

    Context 'Outside GitHub Actions environment' {
        BeforeEach {
            Clear-MockGitHubEnvironment
        }

        It 'Does not throw when GITHUB_STEP_SUMMARY is not set' {
            { Write-GitHubStepSummary -Content 'Test content' } | Should -Not -Throw
        }
    }
}

#endregion
