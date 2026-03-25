#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-PythonTests.ps1 script
.DESCRIPTION
    Tests for Python testing wrapper script:
    - Parameter validation
    - Tool availability checks
    - Skill discovery via pyproject.toml
    - Tests directory detection
    - Pytest execution and result handling
    - Output file generation
    - Summary counters
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-PythonTests.ps1'

    # Create stub function for pytest so it can be mocked even when not installed
    function global:pytest { '' }

    . $script:ScriptPath
}

AfterAll {
    Remove-Item -Path 'Function:\pytest' -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-PythonTests Parameter Validation' -Tag 'Unit' {
    Context 'RepoRoot parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom RepoRoot' {
            $repoRoot = Join-Path $TestDrive 'test-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
            { Invoke-PythonTests -RepoRoot $repoRoot } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom OutputPath' {
            $outputPath = Join-Path $TestDrive 'test-output.json'
            { Invoke-PythonTests -RepoRoot $TestDrive -OutputPath $outputPath } | Should -Not -Throw
        }
    }

    Context 'Verbosity parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Defaults to -v verbosity' {
            { Invoke-PythonTests -RepoRoot $TestDrive } | Should -Not -Throw
        }

        It 'Accepts custom verbosity' {
            { Invoke-PythonTests -RepoRoot $TestDrive -Verbosity '-vv' } | Should -Not -Throw
        }
    }
}

#endregion

#region Tool Availability Tests

Describe 'pytest Tool Availability' -Tag 'Unit' {
    Context 'Tool not installed' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $TestDrive 'skill1/pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = (Join-Path $TestDrive 'skill1') }
                })
            }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pytest' }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
        }

        It 'Returns failure when pytest not available' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Reports skill path in errors' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.errors | Should -Contain (Join-Path $TestDrive 'skill1')
        }

        It 'Reports zero skills tested when pytest missing' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.skillsTested | Should -Be 0
        }

        It 'Reports zero passed' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.passed | Should -Be 0
        }
    }

    Context 'Tool installed' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
        }

        It 'Proceeds when pytest available' {
            { Invoke-PythonTests -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion

#region Skill Discovery Tests

Describe 'Python Skill Discovery for Testing' -Tag 'Unit' {
    Context 'No Python skills found' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
        }

        It 'Returns success with zero skills' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeTrue
            $result.skillsTested | Should -Be 0
        }

        It 'Reports zero passed and failed' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.passed | Should -Be 0
            $result.failed | Should -Be 0
        }
    }

    Context 'Skill without tests directory' {
        BeforeEach {
            $script:NoTestsSkillDir = Join-Path $TestDrive 'no-tests-skill'
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $script:NoTestsSkillDir 'pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = $script:NoTestsSkillDir }
                })
            }
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*tests' }
            Mock pytest { $global:LASTEXITCODE = 0; '' }
        }

        It 'Skips skill without tests directory' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.skillsTested | Should -Be 0
        }

        It 'Does not call pytest for skill without tests' {
            Invoke-PythonTests -RepoRoot $TestDrive
            Should -Invoke -CommandName pytest -Times 0
        }
    }

    Context 'Excludes node_modules from discovery' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $TestDrive 'node_modules/pkg/pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = (Join-Path $TestDrive 'node_modules/pkg') }
                })
            }
        }

        It 'Filters out node_modules paths' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.skillsTested | Should -Be 0
        }
    }
}

#endregion

#region Test Execution Tests

Describe 'Pytest Execution' -Tag 'Unit' {
    BeforeAll {
        $script:SkillDir = Join-Path $TestDrive 'test-skill'
    }

    BeforeEach {
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:SkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:SkillDir }
            })
        }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
    }

    Context 'Tests pass' {
        BeforeEach {
            Mock pytest { $global:LASTEXITCODE = 0; '3 passed' }
        }

        It 'Returns success when pytest passes' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeTrue
        }

        It 'Increments passed counter' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.passed | Should -Be 1
        }

        It 'Reports one skill tested' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.skillsTested | Should -Be 1
        }

        It 'Reports zero failures' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.failed | Should -Be 0
        }

        It 'Marks skill as passed in details' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeTrue
        }
    }

    Context 'Tests fail' {
        BeforeEach {
            Mock pytest { $global:LASTEXITCODE = 1; '1 failed, 2 passed' }
        }

        It 'Returns failure when pytest fails' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Increments failed counter' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.failed | Should -Be 1
        }

        It 'Records skill path in errors' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.errors | Should -Contain $script:SkillDir
        }

        It 'Marks skill as failed in details' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeFalse
        }
    }

    Context 'Pytest throws exception' {
        BeforeEach {
            Mock pytest { throw 'pytest crashed' }
        }

        It 'Handles pytest exception gracefully' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Increments failed counter on exception' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.failed | Should -Be 1
        }

        It 'Records error with skill path' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.errors | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Multiple skills' {
        BeforeEach {
            $script:Skill1Dir = Join-Path $TestDrive 'skill-a'
            $script:Skill2Dir = Join-Path $TestDrive 'skill-b'
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{
                        FullName = (Join-Path $script:Skill1Dir 'pyproject.toml')
                        Directory = [PSCustomObject]@{ FullName = $script:Skill1Dir }
                    },
                    [PSCustomObject]@{
                        FullName = (Join-Path $script:Skill2Dir 'pyproject.toml')
                        Directory = [PSCustomObject]@{ FullName = $script:Skill2Dir }
                    }
                )
            }
            Mock pytest { $global:LASTEXITCODE = 0; 'passed' }
        }

        It 'Tests all discovered skills' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.skillsTested | Should -Be 2
        }

        It 'Counts all passing skills' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.passed | Should -Be 2
        }
    }
}

#endregion

#region Output Persistence Tests

Describe 'Output Persistence' -Tag 'Unit' {
    BeforeAll {
        $script:OutputSkillDir = Join-Path $TestDrive 'output-skill'
    }

    BeforeEach {
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:OutputSkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:OutputSkillDir }
            })
        }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
        Mock pytest { $global:LASTEXITCODE = 0; 'passed' }
    }

    Context 'OutputPath specified' {
        It 'Writes JSON results to OutputPath' {
            $outputPath = Join-Path $TestDrive 'test-results.json'
            Invoke-PythonTests -RepoRoot $TestDrive -OutputPath $outputPath
            Test-Path $outputPath | Should -BeTrue
        }

        It 'Produces valid JSON output' {
            $outputPath = Join-Path $TestDrive 'test-results2.json'
            Invoke-PythonTests -RepoRoot $TestDrive -OutputPath $outputPath
            { Get-Content $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'OutputPath not specified' {
        It 'Does not throw when OutputPath omitted' {
            { Invoke-PythonTests -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion
