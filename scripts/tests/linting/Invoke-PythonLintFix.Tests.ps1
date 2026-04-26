#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-PythonLintFix.ps1 script
.DESCRIPTION
    Tests for Python lint autofix wrapper script:
    - Parameter validation
    - Tool availability checks
    - Skill discovery via pyproject.toml
    - Ruff --fix execution and result handling
    - Output file generation
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-PythonLintFix.ps1'

    # Create stub function for ruff so it can be mocked even when not installed
    function global:ruff { '' }

    . $script:ScriptPath
}

AfterAll {
    Remove-Item -Path 'Function:\ruff' -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-PythonLintFix Parameter Validation' -Tag 'Unit' {
    Context 'RepoRoot parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom RepoRoot' {
            $repoRoot = Join-Path $TestDrive 'test-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
            { Invoke-PythonLintFix -RepoRoot $repoRoot } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom OutputPath' {
            $outputPath = Join-Path $TestDrive 'lint-fix-output.json'
            { Invoke-PythonLintFix -RepoRoot $TestDrive -OutputPath $outputPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Tool Availability Tests

Describe 'ruff Tool Availability (Fix)' -Tag 'Unit' {
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Returns failure when ruff not available' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Reports skill path in errors' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.errors | Should -Contain (Join-Path $TestDrive 'skill1')
        }

        It 'Reports zero skills checked when ruff missing' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 0
        }
    }

    Context 'Tool installed' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Proceeds when ruff available' {
            { Invoke-PythonLintFix -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion

#region Skill Discovery Tests

Describe 'Python Skill Discovery (Fix)' -Tag 'Unit' {
    Context 'No Python skills found' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Returns success with zero skills when no pyproject.toml found' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.success | Should -BeTrue
            $result.skillsChecked | Should -Be 0
        }
    }

    Context 'Python skills found' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
            Mock ruff { $global:LASTEXITCODE = 0; '' }
        }

        It 'Discovers skills via pyproject.toml' {
            $skillDir = Join-Path $TestDrive 'skill1'
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $skillDir 'pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = $skillDir }
                })
            }

            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 1
        }

        It 'Discovers multiple skills' {
            $skill1Dir = Join-Path $TestDrive 'skill1'
            $skill2Dir = Join-Path $TestDrive 'skill2'
            Mock Get-ChildItem {
                @(
                    [PSCustomObject]@{
                        FullName = (Join-Path $skill1Dir 'pyproject.toml')
                        Directory = [PSCustomObject]@{ FullName = $skill1Dir }
                    },
                    [PSCustomObject]@{
                        FullName = (Join-Path $skill2Dir 'pyproject.toml')
                        Directory = [PSCustomObject]@{ FullName = $skill2Dir }
                    }
                )
            }

            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 2
        }

        It 'Excludes node_modules from discovery' {
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $TestDrive 'node_modules/pkg/pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = (Join-Path $TestDrive 'node_modules/pkg') }
                })
            }

            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 0
        }
    }
}

#endregion

#region Lint Execution Tests

Describe 'Ruff Lint Fix Execution' -Tag 'Unit' {
    BeforeAll {
        $script:SkillDir = Join-Path $TestDrive 'lint-fix-skill'
    }

    BeforeEach {
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:SkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:SkillDir }
            })
        }
    }

    Context 'Fix succeeds' {
        BeforeEach {
            Mock ruff { $global:LASTEXITCODE = 0; '' }
        }

        It 'Returns success when ruff exits cleanly' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.success | Should -BeTrue
        }

        It 'Marks skill as passed in details' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeTrue
        }

        It 'Reports no errors' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.errors | Should -HaveCount 0
        }

        It 'Invokes ruff with --fix argument' {
            Invoke-PythonLintFix -RepoRoot $TestDrive
            Should -Invoke ruff -ParameterFilter { $args -contains '--fix' }
        }

        It 'Invokes ruff with check subcommand' {
            Invoke-PythonLintFix -RepoRoot $TestDrive
            Should -Invoke ruff -ParameterFilter { $args -contains 'check' }
        }
    }

    Context 'Unfixable issues remain' {
        BeforeEach {
            Mock ruff { $global:LASTEXITCODE = 1; 'error: E501 line too long (unfixable)' }
        }

        It 'Returns failure when ruff reports unfixable issues' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Records skill path in errors' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.errors | Should -Contain $script:SkillDir
        }

        It 'Marks skill as failed in details' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeFalse
        }
    }

    Context 'Ruff throws exception' {
        BeforeEach {
            Mock ruff { throw 'ruff crashed' }
        }

        It 'Handles ruff exception gracefully' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Records error with skill path' {
            $result = Invoke-PythonLintFix -RepoRoot $TestDrive
            $result.errors | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion

#region Output Persistence Tests

Describe 'Output Persistence (Fix)' -Tag 'Unit' {
    BeforeAll {
        $script:OutputSkillDir = Join-Path $TestDrive 'output-fix-skill'
    }

    BeforeEach {
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:OutputSkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:OutputSkillDir }
            })
        }
        Mock ruff { $global:LASTEXITCODE = 0; '' }
    }

    Context 'OutputPath specified' {
        It 'Writes JSON results to OutputPath' {
            $outputPath = Join-Path $TestDrive 'lint-fix-results.json'
            Invoke-PythonLintFix -RepoRoot $TestDrive -OutputPath $outputPath
            Test-Path $outputPath | Should -BeTrue
        }

        It 'Produces valid JSON output' {
            $outputPath = Join-Path $TestDrive 'lint-fix-results2.json'
            Invoke-PythonLintFix -RepoRoot $TestDrive -OutputPath $outputPath
            { Get-Content $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'OutputPath not specified' {
        It 'Does not throw when OutputPath omitted' {
            { Invoke-PythonLintFix -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion
