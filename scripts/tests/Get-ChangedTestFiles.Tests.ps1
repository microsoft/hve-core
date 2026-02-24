#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Get-ChangedTestFiles.ps1 script
.DESCRIPTION
    Tests for changed PowerShell file detection and test path resolution:
    - Empty diff returns no changes
    - Source file with matching test resolves correctly
    - Source file without matching test returns empty
    - Directly changed test files are included
    - Skill directory discovery at depth 1 and 2
    - No skills directory handles gracefully
    - Deduplication of discovered test paths
    - Git diff failure returns no changes
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Get-ChangedTestFiles.ps1'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1'

    # Import modules for mocking
    Import-Module $script:CIHelpersPath -Force

    # Dot-source the script to access Get-ChangedTestFilesCore
    . $script:ScriptPath
}

AfterAll {
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ChangedTestFiles' -Tag 'Unit' {

    Context 'Empty diff returns no changes' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 0
                return @()
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        It 'Returns HasChanges as false' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main'
            $result.HasChanges | Should -BeFalse
        }

        It 'Returns empty TestPaths' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main'
            $result.TestPaths | Should -BeNullOrEmpty
        }

        It 'Returns empty ChangedFiles' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main'
            $result.ChangedFiles | Should -BeNullOrEmpty
        }
    }

    Context 'Source file with matching test' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testDir 'MyScript.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/MyScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Resolves matching test file path' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests')
            $result.TestPaths | Should -HaveCount 1
            $result.TestPaths[0] | Should -BeLike '*MyScript.Tests.ps1'
        }

        It 'Sets HasChanges to true' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests')
            $result.HasChanges | Should -BeTrue
        }
    }

    Context 'Source file without matching test' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/NoTestScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns HasChanges as false when no test found' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests')
            $result.HasChanges | Should -BeFalse
        }

        It 'Returns empty TestPaths' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests')
            $result.TestPaths | Should -BeNullOrEmpty
        }
    }

    Context 'Directly changed test file included' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testDir 'SomeScript.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/tests/SomeScript.Tests.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Includes directly changed test files' {
            Push-Location $script:TempDir
            try {
                $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests')
                $result.TestPaths | Should -HaveCount 1
                $result.TestPaths[0] | Should -BeLike '*SomeScript.Tests.ps1'
            }
            finally {
                Pop-Location
            }
        }
    }

    Context 'Skill directory discovery at depth 1' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"

            $testRoot = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

            $skillDir = Join-Path $script:TempDir '.github/skills/collection1'
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'tests') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'scripts') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $skillDir 'tests/SkillScript.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('.github/skills/collection1/scripts/SkillScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers test files in skill directories at depth 1' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' `
                -TestRoot (Join-Path $script:TempDir 'scripts/tests') `
                -SkillsRoot (Join-Path $script:TempDir '.github/skills')
            $result.HasChanges | Should -BeTrue
            $result.TestPaths | Should -HaveCount 1
            $result.TestPaths[0] | Should -BeLike '*SkillScript.Tests.ps1'
        }
    }

    Context 'Skill directory discovery at depth 2' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"

            $testRoot = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

            $skillDir = Join-Path $script:TempDir '.github/skills/collection1/skill1'
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'tests') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $skillDir 'scripts') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $skillDir 'tests/DeepSkillScript.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('.github/skills/collection1/skill1/scripts/DeepSkillScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Discovers test files in skill directories at depth 2' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' `
                -TestRoot (Join-Path $script:TempDir 'scripts/tests') `
                -SkillsRoot (Join-Path $script:TempDir '.github/skills')
            $result.HasChanges | Should -BeTrue
            $result.TestPaths | Should -HaveCount 1
            $result.TestPaths[0] | Should -BeLike '*DeepSkillScript.Tests.ps1'
        }
    }

    Context 'No skills directory handles gracefully' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testDir 'MyScript.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/MyScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Works when skills directory does not exist' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' `
                -TestRoot (Join-Path $script:TempDir 'scripts/tests') `
                -SkillsRoot (Join-Path $script:TempDir 'nonexistent/skills')
            $result.HasChanges | Should -BeTrue
            $result.TestPaths | Should -HaveCount 1
        }
    }

    Context 'Deduplication of discovered test paths' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testDir 'Shared.Tests.ps1') -Force | Out-Null

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/Shared.ps1', 'scripts/extension/Shared.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns unique test paths only' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests') -SkillsRoot (Join-Path $script:TempDir 'nonexistent/skills')
            $result.TestPaths | Should -HaveCount 1
        }
    }

    Context 'Git diff failure' {
        BeforeEach {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: bad object'
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        It 'Returns no changes when git diff fails' {
            $result = Get-ChangedTestFilesCore -BaseBranch 'main'
            $result.HasChanges | Should -BeFalse
            $result.TestPaths | Should -BeNullOrEmpty
        }
    }

    Context 'Script guard execution' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            $testDir = Join-Path $script:TempDir 'scripts/tests'
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $testDir 'MyScript.Tests.ps1') -Force | Out-Null

            $script:EnvFile = Join-Path $script:TempDir 'github_env'
            New-Item -ItemType File -Path $script:EnvFile -Force | Out-Null
            $env:GITHUB_ENV = $script:EnvFile
            $env:GITHUB_ACTIONS = 'true'

            Mock git {
                $global:LASTEXITCODE = 0
                return @('scripts/linting/MyScript.ps1')
            } -ParameterFilter { $args[0] -eq 'diff' }
        }

        AfterEach {
            $env:GITHUB_ENV = $null
            $env:GITHUB_ACTIONS = $null
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Throws when BaseBranch is not provided' {
            { & $script:ScriptPath } | Should -Throw '*BaseBranch*'
        }

        It 'Writes HAS_CHANGES to GITHUB_ENV' {
            & $script:ScriptPath -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests') -SkillsRoot (Join-Path $script:TempDir 'nonexistent')
            $content = Get-Content $script:EnvFile -Raw
            $content | Should -Match 'HAS_CHANGES'
            $content | Should -Match 'True'
        }

        It 'Writes TEST_PATHS to GITHUB_ENV' {
            & $script:ScriptPath -BaseBranch 'main' -TestRoot (Join-Path $script:TempDir 'scripts/tests') -SkillsRoot (Join-Path $script:TempDir 'nonexistent')
            $content = Get-Content $script:EnvFile -Raw
            $content | Should -Match 'TEST_PATHS'
        }
    }
}
