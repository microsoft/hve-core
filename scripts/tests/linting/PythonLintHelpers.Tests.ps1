#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for PythonLintHelpers.psm1 module.
.DESCRIPTION
    Covers shared helper functions used by Invoke-PythonLint(Fix).ps1:
    - Get-PythonSkill discovers pyproject.toml directories.
    - Resolve-RuffCommand selects venv ruff, global ruff, or $null.
    - Write-PythonLintResults creates parent directory and writes JSON.
#>

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../linting/Modules/PythonLintHelpers.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module PythonLintHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Get-PythonSkill' -Tag 'Unit' {
    Context 'When repository contains pyproject.toml files' {
        It 'Returns directories that contain pyproject.toml' {
            $repo = Join-Path $TestDrive 'repo-with-skills'
            $skillA = Join-Path $repo 'skills/a'
            $skillB = Join-Path $repo 'skills/b'
            New-Item -ItemType Directory -Path $skillA -Force | Out-Null
            New-Item -ItemType Directory -Path $skillB -Force | Out-Null
            Set-Content -Path (Join-Path $skillA 'pyproject.toml') -Value ''
            Set-Content -Path (Join-Path $skillB 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 2
            ($result -join ';') | Should -Match 'a'
            ($result -join ';') | Should -Match 'b'
        }

        It 'Excludes pyproject.toml under node_modules' {
            $repo = Join-Path $TestDrive 'repo-with-node-modules'
            $skill = Join-Path $repo 'skills/real'
            $nm = Join-Path $repo 'node_modules/pkg'
            New-Item -ItemType Directory -Path $skill -Force | Out-Null
            New-Item -ItemType Directory -Path $nm -Force | Out-Null
            Set-Content -Path (Join-Path $skill 'pyproject.toml') -Value ''
            Set-Content -Path (Join-Path $nm 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 1
            ($result -join ';') | Should -Not -Match 'node_modules'
        }
    }

    Context 'When repository contains no pyproject.toml files' {
        It 'Returns an empty array' {
            $repo = Join-Path $TestDrive 'empty-repo'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null

            $result = Get-PythonSkill -RepoRoot $repo

            @($result).Count | Should -Be 0
        }
    }
}

Describe 'Resolve-RuffCommand' -Tag 'Unit' {
    Context 'When skill has a Linux .venv ruff binary' {
        It 'Returns the .venv/bin/ruff path' {
            $skill = Join-Path $TestDrive 'skill-linux-venv'
            $venvBin = Join-Path $skill '.venv/bin'
            New-Item -ItemType Directory -Path $venvBin -Force | Out-Null
            Set-Content -Path (Join-Path $venvBin 'ruff') -Value ''

            $result = Resolve-RuffCommand -SkillPath $skill -GlobalRuffAvailable $false

            $result | Should -Match 'bin[\\/]ruff$'
        }
    }

    Context 'When skill has a Windows .venv ruff.exe binary' {
        It 'Returns the .venv/Scripts/ruff.exe path' {
            $skill = Join-Path $TestDrive 'skill-win-venv'
            $venvScripts = Join-Path $skill '.venv/Scripts'
            New-Item -ItemType Directory -Path $venvScripts -Force | Out-Null
            Set-Content -Path (Join-Path $venvScripts 'ruff.exe') -Value ''

            $result = Resolve-RuffCommand -SkillPath $skill -GlobalRuffAvailable $false

            $result | Should -Match 'Scripts[\\/]ruff\.exe$'
        }
    }

    Context 'When no .venv ruff exists but global ruff is available' {
        It "Returns 'ruff'" {
            $skill = Join-Path $TestDrive 'skill-no-venv'
            New-Item -ItemType Directory -Path $skill -Force | Out-Null

            $result = Resolve-RuffCommand -SkillPath $skill -GlobalRuffAvailable $true

            $result | Should -Be 'ruff'
        }
    }

    Context 'When no ruff is available anywhere' {
        It 'Returns $null' {
            $skill = Join-Path $TestDrive 'skill-no-ruff'
            New-Item -ItemType Directory -Path $skill -Force | Out-Null

            $result = Resolve-RuffCommand -SkillPath $skill -GlobalRuffAvailable $false

            $result | Should -BeNullOrEmpty
        }
    }
}

Describe 'Write-PythonLintResults' -Tag 'Unit' {
    Context 'When OutputPath is not provided' {
        It 'Writes JSON to logs/<DefaultFileName> under RepoRoot' {
            $repo = Join-Path $TestDrive 'repo-default-output'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $results = @{ success = $true; count = 1 }

            $resolved = Write-PythonLintResults -Results $results -RepoRoot $repo -DefaultFileName 'python-lint-results.json'

            $expected = Join-Path $repo 'logs/python-lint-results.json'
            $resolved | Should -Be $expected
            Test-Path $expected | Should -BeTrue
            (Get-Content $expected -Raw | ConvertFrom-Json).success | Should -BeTrue
        }

        It 'Creates the logs directory when it does not exist' {
            $repo = Join-Path $TestDrive 'repo-missing-logs'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $logsDir = Join-Path $repo 'logs'
            Test-Path $logsDir | Should -BeFalse

            Write-PythonLintResults -Results @{ success = $true } -RepoRoot $repo -DefaultFileName 'python-lint-results.json' | Out-Null

            Test-Path $logsDir | Should -BeTrue
        }
    }

    Context 'When OutputPath is provided' {
        It 'Writes JSON to the explicit OutputPath' {
            $repo = Join-Path $TestDrive 'repo-explicit-output'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $outputPath = Join-Path $TestDrive 'custom/dir/results.json'

            $resolved = Write-PythonLintResults -Results @{ success = $false } -RepoRoot $repo -OutputPath $outputPath -DefaultFileName 'python-lint-results.json'

            $resolved | Should -Be $outputPath
            Test-Path $outputPath | Should -BeTrue
            (Get-Content $outputPath -Raw | ConvertFrom-Json).success | Should -BeFalse
        }

        It 'Creates the parent directory of OutputPath when missing' {
            $repo = Join-Path $TestDrive 'repo-explicit-missing-parent'
            New-Item -ItemType Directory -Path $repo -Force | Out-Null
            $outputPath = Join-Path $TestDrive 'never/created/before/results.json'
            Test-Path (Split-Path -Parent $outputPath) | Should -BeFalse

            Write-PythonLintResults -Results @{ success = $true } -RepoRoot $repo -OutputPath $outputPath -DefaultFileName 'python-lint-results.json' | Out-Null

            Test-Path (Split-Path -Parent $outputPath) | Should -BeTrue
            Test-Path $outputPath | Should -BeTrue
        }
    }
}
