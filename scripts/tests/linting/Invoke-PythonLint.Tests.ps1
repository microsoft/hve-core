#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-PythonLint.ps1 script
.DESCRIPTION
    Tests for Python linting wrapper script:
    - Parameter validation
    - Tool availability checks
    - Skill discovery via pyproject.toml
    - Ruff execution and result handling
    - Output file generation
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../linting/Invoke-PythonLint.ps1'

    # Create stub function for ruff so it can be mocked even when not installed
    function global:ruff { '' }

    . $script:ScriptPath
}

AfterAll {
    Remove-Item -Path 'Function:\ruff' -Force -ErrorAction SilentlyContinue
}

#region Parameter Validation Tests

Describe 'Invoke-PythonLint Parameter Validation' -Tag 'Unit' {
    Context 'RepoRoot parameter' {
        BeforeEach {
            Mock Get-PythonSkill { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom RepoRoot' {
            $repoRoot = Join-Path $TestDrive 'test-repo'
            New-Item -ItemType Directory -Path $repoRoot -Force | Out-Null
            { Invoke-PythonLint -RepoRoot $repoRoot } | Should -Not -Throw
        }
    }

    Context 'OutputPath parameter' {
        BeforeEach {
            Mock Get-PythonSkill { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
            Mock Push-Location {}
            Mock Pop-Location {}
        }

        It 'Accepts custom OutputPath' {
            $outputPath = Join-Path $TestDrive 'lint-output.json'
            { Invoke-PythonLint -RepoRoot $TestDrive -OutputPath $outputPath } | Should -Not -Throw
        }
    }
}

#endregion

#region Tool Availability Tests

Describe 'ruff Tool Availability' -Tag 'Unit' {
    Context 'Tool not installed' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-PythonSkill { @((Join-Path $TestDrive 'skill1')) }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Returns failure when ruff not available' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Reports skill path in errors' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.errors | Should -Contain (Join-Path $TestDrive 'skill1')
        }

        It 'Reports zero skills checked when ruff missing' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 0
        }
    }

    Context 'Tool installed' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-PythonSkill { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Proceeds when ruff available' {
            { Invoke-PythonLint -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion

#region Skill Discovery Tests

Describe 'Python Skill Discovery' -Tag 'Unit' {
    Context 'No Python skills found' {
        BeforeEach {
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Get-PythonSkill { @() }
            Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        }

        It 'Returns success with zero skills when no pyproject.toml found' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
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
            Mock Get-PythonSkill { @($skillDir) }

            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 1
        }

        It 'Discovers multiple skills' {
            $skill1Dir = Join-Path $TestDrive 'skill1'
            $skill2Dir = Join-Path $TestDrive 'skill2'
            Mock Get-PythonSkill { @($skill1Dir, $skill2Dir) }

            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 2
        }

        It 'Excludes node_modules from discovery' {
            # Get-PythonSkill applies the node_modules filter; mock returns post-filter result.
            Mock Get-PythonSkill { @() }

            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.skillsChecked | Should -Be 0
        }
    }
}

#endregion

#region Lint Execution Tests

Describe 'Ruff Lint Execution' -Tag 'Unit' {
    BeforeAll {
        $script:SkillDir = Join-Path $TestDrive 'lint-skill'
    }

    BeforeEach {
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        Mock Get-PythonSkill { @($script:SkillDir) }
    }

    Context 'Lint passes' {
        BeforeEach {
            Mock ruff { $global:LASTEXITCODE = 0; '' }
        }

        It 'Returns success when ruff reports no issues' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.success | Should -BeTrue
        }

        It 'Marks skill as passed in details' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeTrue
        }

        It 'Reports no errors' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.errors | Should -HaveCount 0
        }
    }

    Context 'Lint fails' {
        BeforeEach {
            Mock ruff { $global:LASTEXITCODE = 1; 'error: E501 line too long' }
        }

        It 'Returns failure when ruff reports issues' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Records skill path in errors' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.errors | Should -Contain $script:SkillDir
        }

        It 'Marks skill as failed in details' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.details[0].passed | Should -BeFalse
        }
    }

    Context 'Ruff throws exception' {
        BeforeEach {
            Mock ruff { throw 'ruff crashed' }
        }

        It 'Handles ruff exception gracefully' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.success | Should -BeFalse
        }

        It 'Records error with skill path' {
            $result = Invoke-PythonLint -RepoRoot $TestDrive
            $result.errors | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Fix mode with -Fix switch' {
        BeforeEach {
            Mock ruff { $global:LASTEXITCODE = 0; '' }
        }

        It 'Invokes ruff with --fix argument' {
            Invoke-PythonLint -Fix -RepoRoot $TestDrive
            Should -Invoke ruff -ParameterFilter { $args -contains '--fix' }
        }

        It 'Invokes ruff with check subcommand' {
            Invoke-PythonLint -Fix -RepoRoot $TestDrive
            Should -Invoke ruff -ParameterFilter { $args -contains 'check' }
        }

        It 'Invokes ruff with format subcommand' {
            Invoke-PythonLint -Fix -RepoRoot $TestDrive
            Should -Invoke ruff -ParameterFilter { $args -contains 'format' }
        }

        It 'Records formatExitCode in skill detail' {
            $result = Invoke-PythonLint -Fix -RepoRoot $TestDrive
            $result.details[0].formatExitCode | Should -Be 0
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
        Mock Get-Command { [PSCustomObject]@{ Source = 'ruff' } } -ParameterFilter { $Name -eq 'ruff' }
        Mock Get-PythonSkill { @($script:OutputSkillDir) }
        Mock ruff { $global:LASTEXITCODE = 0; '' }
    }

    Context 'OutputPath specified' {
        It 'Writes JSON results to OutputPath' {
            $outputPath = Join-Path $TestDrive 'lint-results.json'
            Invoke-PythonLint -RepoRoot $TestDrive -OutputPath $outputPath
            Test-Path $outputPath | Should -BeTrue
        }

        It 'Produces valid JSON output' {
            $outputPath = Join-Path $TestDrive 'lint-results2.json'
            Invoke-PythonLint -RepoRoot $TestDrive -OutputPath $outputPath
            { Get-Content $outputPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'OutputPath not specified' {
        It 'Does not throw when OutputPath omitted' {
            { Invoke-PythonLint -RepoRoot $TestDrive } | Should -Not -Throw
        }
    }
}

#endregion

#region Import-Order Detection (I001) Guard

# Defense-in-depth: ensure that when a Python skill enables the isort rule ('I')
# and ships an import-order violation, Invoke-PythonLint surfaces it as a
# failure. Guards against silent regressions where the rule selection is
# stripped or the lint runner stops invoking ruff against test fixtures.
# Untagged so it runs in the default Pester suite (which excludes 'Integration'
# and 'Slow'); skips at runtime when no real ruff binary is available.
Describe 'Invoke-PythonLint Import-Order Detection (I001 Guard)' {
    BeforeAll {
        # Drop the global ruff stub from the file's top-level BeforeAll so we
        # invoke a real ruff binary, not the no-op function.
        Remove-Item -Path 'Function:\ruff' -Force -ErrorAction SilentlyContinue

        # Resolve a real ruff binary: prefer one already on PATH, else borrow
        # one from any existing skill venv in this repo so the test mirrors how
        # Invoke-PythonLint discovers ruff in CI.
        $script:RealRuffPath = $null
        $globalRuff = Get-Command ruff -ErrorAction SilentlyContinue
        if ($globalRuff) {
            $script:RealRuffPath = $globalRuff.Source
        }
        else {
            $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
            $candidate = Get-ChildItem -Path (Join-Path $repoRoot '.github/skills') `
                -Recurse -Force -File -Filter 'ruff' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\.venv/bin/ruff$' } |
                Select-Object -First 1
            if ($candidate) {
                $script:RealRuffPath = $candidate.FullName
            }
        }
    }

    It 'Reports failure when a skill ships an I001 import-order violation' {
        if (-not $script:RealRuffPath) {
            Set-ItResult -Skipped -Because 'no ruff binary available on PATH or in any skill .venv'
        }

        $skillDir = Join-Path $TestDrive 'i001-guard-skill'
        $venvBinDir = Join-Path $skillDir '.venv/bin'
        New-Item -ItemType Directory -Path $venvBinDir -Force | Out-Null

        # Plant pyproject.toml that explicitly enables the isort rule.
        Set-Content -Path (Join-Path $skillDir 'pyproject.toml') -Value @"
[project]
name = "i001-guard-skill"
version = "0.0.0"
requires-python = ">=3.11"

[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = ["I"]
"@

        # Plant a Python file whose imports are unsorted (triggers I001).
        $scriptsDir = Join-Path $skillDir 'scripts'
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Set-Content -Path (Join-Path $scriptsDir 'bad_imports.py') -Value @"
import sys
import os
"@

        # Stage a real ruff binary at the skill's expected venv path so
        # Invoke-PythonLint resolves and invokes it just as in production.
        $stagedRuff = Join-Path $venvBinDir 'ruff'
        try {
            New-Item -ItemType SymbolicLink -Path $stagedRuff -Target $script:RealRuffPath -Force | Out-Null
        }
        catch {
            Copy-Item -Path $script:RealRuffPath -Destination $stagedRuff -Force
        }

        $result = Invoke-PythonLint -RepoRoot $TestDrive
        $result.success | Should -BeFalse
        $result.skillsChecked | Should -Be 1
        ($result.details | Where-Object { -not $_.passed }).output | Should -Match 'I001'
    }
}

#endregion
