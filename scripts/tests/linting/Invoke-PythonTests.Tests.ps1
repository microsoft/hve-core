#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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
    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force

    # Create stub functions so they can be mocked even when not installed
    function global:pytest { '' }
    function global:uv { '' }

    . $script:ScriptPath
}

AfterAll {
    Remove-Item -Path 'Function:\pytest' -Force -ErrorAction SilentlyContinue
    Remove-Item -Path 'Function:\uv' -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-PythonTests Parameter Validation' -Tag 'Unit' {
    Context 'RepoRoot parameter' {
        BeforeEach {
            Mock Get-ChildItem { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*uv.lock' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
            Mock Get-ChildItem {
                @([PSCustomObject]@{
                    FullName = (Join-Path $script:NoTestsSkillDir 'pyproject.toml')
                    Directory = [PSCustomObject]@{ FullName = $script:NoTestsSkillDir }
                })
            }
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*tests' }
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*uv.lock' }
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
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
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
        Save-CIEnvironment
        $script:UvEnvironment = @{}
        foreach ($name in @('UV_DEFAULT_INDEX', 'UV_INDEX_URL')) {
            $script:UvEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $env:UV_DEFAULT_INDEX = 'https://pypi.org/simple'
        Remove-Item Env:UV_INDEX_URL -ErrorAction SilentlyContinue
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'pytest' } } -ParameterFilter { $Name -eq 'pytest' }
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:SkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:SkillDir }
            })
        }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
        Mock Test-Path { $false } -ParameterFilter { $Path -like '*uv.lock' }
    }

    AfterEach {
        Restore-CIEnvironment
        foreach ($name in $script:UvEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:UvEnvironment[$name])
        }
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

    Context 'Locked uv project' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'uv' } } -ParameterFilter { $Name -eq 'uv' }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*uv.lock' }
            Mock uv {
                if ($args[0] -eq 'sync') {
                    $global:LASTEXITCODE = 0
                    return 'synced'
                }

                $global:LASTEXITCODE = 0
                return '3 passed'
            }
        }

        It 'Uses uv runner for locked project' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.details[0].runner | Should -Be 'uv'
        }

        It 'Returns success when uv pytest passes' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeTrue
            $result.passed | Should -Be 1
        }

        It 'Runs uv sync before pytest' {
            Invoke-PythonTests -RepoRoot $TestDrive
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'sync' -and $args[1] -eq '--locked' -and $args[2] -eq '--dev' } -Times 1
        }

        It 'Runs pytest through uv' {
            Invoke-PythonTests -RepoRoot $TestDrive
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'run' -and $args[1] -eq '--no-sync' -and $args[2] -eq 'pytest' -and $args[3] -eq 'tests/' } -Times 1
        }

        It 'Provisions unlocked projects and still prevents implicit pytest sync' {
            Mock Test-Path { $false } -ParameterFilter { $Path -like '*uv.lock' }
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeTrue
            Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'sync' -and $args[1] -eq '--dev' }
            Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'run' -and $args[1] -eq '--no-sync' }
        }
    }

    Context 'Locked uv project sync failure' {
        BeforeEach {
            Mock Get-Command { [PSCustomObject]@{ Source = 'uv' } } -ParameterFilter { $Name -eq 'uv' }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*uv.lock' }
            Mock uv {
                $global:LASTEXITCODE = 1
                'sync failed'
            }
        }

        It 'Returns failure when uv sync fails' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Records sync phase failure details' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.details[0].runner | Should -Be 'uv'
            $result.details[0].phase | Should -Be 'sync'
            $result.details[0].passed | Should -BeFalse
        }

        It 'Does not run pytest after failed sync' {
            Invoke-PythonTests -RepoRoot $TestDrive
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'run' } -Times 0
        }
    }

    Context 'Locked uv project with custom default index' {
        BeforeEach {
            $env:UV_DEFAULT_INDEX = 'https://mirror.example.com/pypi/simple'
            Mock Get-Command { [PSCustomObject]@{ Source = 'uv' } } -ParameterFilter { $Name -eq 'uv' }
            Mock Test-Path { $true } -ParameterFilter { $Path -like '*uv.lock' }
            Mock uv {
                $global:LASTEXITCODE = 0
                if ($args[0] -eq 'export') {
                    return 'lock validated'
                }

                return '3 passed'
            }
        }

        It 'Provisions the canonical lock and runs pytest without syncing' {
            $result = Invoke-PythonTests -RepoRoot $TestDrive

            $result.success | Should -BeTrue
            Should -Invoke -CommandName uv -ParameterFilter {
                $args[0] -eq 'export' -and
                $args[1] -eq '--locked' -and
                $args[2] -eq '--offline'
            } -Times 1
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'sync' } -Times 0
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'venv' } -Times 1
            Should -Invoke -CommandName uv -ParameterFilter { $args[0] -eq 'pip' -and $args -contains '--require-hashes' } -Times 1
            Should -Invoke -CommandName uv -ParameterFilter {
                $args[0] -eq 'run' -and
                $args[1] -eq '--no-sync' -and
                $args[2] -eq 'pytest'
            } -Times 1
        }

        It 'Does not run pytest after the mirrored prerequisite <Command> fails' -ForEach @(
            @{ Command = 'run' }
            @{ Command = 'export' }
            @{ Command = 'venv' }
            @{ Command = 'pip' }
        ) {
            $script:FailedUvCommand = $Command
            Mock uv {
                $global:LASTEXITCODE = if ($args[0] -eq $script:FailedUvCommand) { 42 } else { 0 }
                'prerequisite result'
            }
            $result = Invoke-PythonTests -RepoRoot $TestDrive
            $result.success | Should -BeFalse
            $result.details[0].phase | Should -Be 'sync'
            Should -Invoke uv -Times 0 -ParameterFilter { $args -contains 'pytest' }
        }
    }
}

Describe 'Invoke-UvEnvironmentSync mirror boundaries' -Tag 'Unit' {
    BeforeEach {
        Save-CIEnvironment
        $script:UvEnvironment = @{}
        foreach ($name in @('UV_DEFAULT_INDEX', 'UV_INDEX_URL')) {
            $script:UvEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
        }
        $env:UV_DEFAULT_INDEX = 'https://mirror.example.com/simple'
        Remove-Item Env:UV_INDEX_URL -ErrorAction SilentlyContinue
        Mock uv { $global:LASTEXITCODE = 0; 'provisioned' }
        Mock Test-Path { $false } -ParameterFilter { $Path -like '.venv/*' }
    }

    AfterEach {
        Restore-CIEnvironment
        foreach ($name in $script:UvEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $script:UvEnvironment[$name])
        }
    }

    It 'Preserves both index variables after <Command> returns <ExitCode>' -ForEach @(
        @{ Command = 'export'; ExitCode = 1; OriginalDefault = 'https://mirror.example.com/simple'; OriginalLegacy = $null }
        @{ Command = 'venv'; ExitCode = 1; OriginalDefault = 'https://mirror.example.com/simple'; OriginalLegacy = '' }
        @{ Command = 'pip'; ExitCode = 1; OriginalDefault = $null; OriginalLegacy = 'https://fallback.example.com/simple' }
        @{ Command = 'pip'; ExitCode = 0; OriginalDefault = ''; OriginalLegacy = 'https://fallback.example.com/simple' }
        @{ Command = 'pip'; ExitCode = 0; OriginalDefault = 'https://mirror.example.com/simple'; OriginalLegacy = 'https://fallback.example.com/simple' }
    ) {
        [Environment]::SetEnvironmentVariable('UV_DEFAULT_INDEX', $OriginalDefault)
        [Environment]::SetEnvironmentVariable('UV_INDEX_URL', $OriginalLegacy)
        $beforeDefault = [Environment]::GetEnvironmentVariable('UV_DEFAULT_INDEX')
        $beforeLegacy = [Environment]::GetEnvironmentVariable('UV_INDEX_URL')
        $script:BoundaryCommand = $Command
        $script:BoundaryExit = $ExitCode
        Mock uv {
            $global:LASTEXITCODE = if ($args[0] -eq $script:BoundaryCommand) { $script:BoundaryExit } else { 0 }
            'boundary result'
        }
        $result = Invoke-UvEnvironmentSync -Locked $true
        $result.exitCode | Should -Be $ExitCode
        [Environment]::GetEnvironmentVariable('UV_DEFAULT_INDEX') | Should -BeExactly $beforeDefault
        [Environment]::GetEnvironmentVariable('UV_INDEX_URL') | Should -BeExactly $beforeLegacy
    }

    It 'Uses non-empty default before fallback: <DefaultIndex>' -ForEach @(
        @{ DefaultIndex = ''; IndexUrl = 'https://fallback.example.com/simple'; Selected = 'https://fallback.example.com/simple' }
        @{ DefaultIndex = $null; IndexUrl = 'https://fallback.example.com/simple'; Selected = 'https://fallback.example.com/simple' }
        @{ DefaultIndex = 'https://preferred.example.com/simple'; IndexUrl = 'https://fallback.example.com/simple'; Selected = 'https://preferred.example.com/simple' }
    ) {
        $env:UV_DEFAULT_INDEX = $DefaultIndex
        $env:UV_INDEX_URL = $IndexUrl
        $script:SelectedIndex = $Selected
        (Invoke-UvEnvironmentSync -Locked $true).exitCode | Should -Be 0
        Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'pip' -and $args -contains $script:SelectedIndex }
    }

    It 'Reuses an existing environment without recreating it' {
        Mock Test-Path { $true } -ParameterFilter { $Path -like '.venv/*' }
        (Invoke-UvEnvironmentSync -Locked $true).exitCode | Should -Be 0
        Should -Invoke uv -Times 0 -ParameterFilter { $args[0] -eq 'venv' }
        Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'pip' }
    }

    It 'Syncs unlocked projects before no-sync test execution' {
        (Invoke-UvEnvironmentSync -Locked $false).exitCode | Should -Be 0
        Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'sync' -and $args[1] -eq '--dev' }
    }

    It 'Uses public locked sync when both index variables are unset' {
        Remove-Item Env:UV_DEFAULT_INDEX -ErrorAction SilentlyContinue
        Remove-Item Env:UV_INDEX_URL -ErrorAction SilentlyContinue
        (Invoke-UvEnvironmentSync -Locked $true).exitCode | Should -Be 0
        Should -Invoke uv -Times 1 -ParameterFilter { $args[0] -eq 'sync' -and $args[1] -eq '--locked' }
    }
}

Describe 'PowerShell controlled mirror restore' -Tag 'Unit', 'Integration' {
    It 'Provisions a missing environment without source leakage with uv <Version>' -ForEach @(
        @{ Version = '0.10.8'; Compatibility = $false }
        @{ Version = '0.11.15'; Compatibility = $true }
    ) {
        if (-not $IsLinux) {
            Set-ItResult -Skipped -Because 'controlled-index evidence requires Ubuntu'
            return
        }
        if (-not (Get-Command uv -CommandType Application -ErrorAction SilentlyContinue) -or
            -not (Get-Command uvx -CommandType Application -ErrorAction SilentlyContinue)) {
            Set-ItResult -Skipped -Because 'local controlled-index evidence requires uv and uvx'
            return
        }
        $fixture = Join-Path $PSScriptRoot '../devcontainer/fixtures/controlled_uv_index.py'
        if ($Compatibility) {
            $output = & uvx --from uv==0.11.15 uv run --no-project $fixture --mode powershell
        } else {
            $uvApplication = (Get-Command uv -CommandType Application).Source
            $output = & $uvApplication run --no-project $fixture --mode powershell
        }
        $LASTEXITCODE | Should -Be 0
        $evidence = $output | ConvertFrom-Json
        $evidence.version | Should -Match ([regex]::Escape($Version))
        $evidence.clean_environment | Should -BeTrue
        $evidence.hash_rejected | Should -BeTrue
        $evidence.explicit_requests | Should -HaveCount 0
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
        Mock Get-Command { $null } -ParameterFilter { $Name -eq 'uv' }
        Mock Get-ChildItem {
            @([PSCustomObject]@{
                FullName = (Join-Path $script:OutputSkillDir 'pyproject.toml')
                Directory = [PSCustomObject]@{ FullName = $script:OutputSkillDir }
            })
        }
        Mock Test-Path { $true } -ParameterFilter { $Path -like '*tests' }
        Mock Test-Path { $false } -ParameterFilter { $Path -like '*uv.lock' }
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
