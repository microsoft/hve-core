#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for PythonLintHelpers.psm1 module.
.DESCRIPTION
    Covers shared helper functions used by Invoke-PythonLint(Fix).ps1:
    - Get-PythonSkill discovers pyproject.toml directories.
    - Resolve-RuffCommand selects venv ruff, global ruff, or $null.
    - Get-LockedRuffVersion reads the ruff version pinned by uv.lock.
    - Resolve-ProjectRuff enforces exact locked versions and unlocked fallback.
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

        It 'Excludes pyproject.toml under the repository-root plugins generated output' {
            $repo = Join-Path $TestDrive 'repo-with-generated-plugins'
            $skill = Join-Path $repo '.github/skills/security/vex'
            $generated = Join-Path $repo 'plugins/hve-core/skills/security/vex'
            New-Item -ItemType Directory -Path $skill -Force | Out-Null
            New-Item -ItemType Directory -Path $generated -Force | Out-Null
            Set-Content -Path (Join-Path $skill 'pyproject.toml') -Value ''
            Set-Content -Path (Join-Path $generated 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 1
            ($result -join ';') | Should -Not -Match '[\\/]plugins[\\/]'
            ($result -join ';') | Should -Match 'skills[\\/]security[\\/]vex$'
        }

        It 'Includes root directories whose names merely contain plugins' {
            $repo = Join-Path $TestDrive 'repo-with-plugins-lookalike'
            $lookalike = Join-Path $repo 'plugins-archive'
            $prefixed = Join-Path $repo 'myplugins'
            New-Item -ItemType Directory -Path $lookalike -Force | Out-Null
            New-Item -ItemType Directory -Path $prefixed -Force | Out-Null
            Set-Content -Path (Join-Path $lookalike 'pyproject.toml') -Value ''
            Set-Content -Path (Join-Path $prefixed 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 2
            ($result -join ';') | Should -Match 'plugins-archive'
            ($result -join ';') | Should -Match 'myplugins'
        }

        It 'Includes pyproject.toml under a plugins directory below the repository root' {
            $repo = Join-Path $TestDrive 'repo-with-nested-plugins'
            $nested = Join-Path $repo 'docs/plugins/sample'
            New-Item -ItemType Directory -Path $nested -Force | Out-Null
            Set-Content -Path (Join-Path $nested 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 1
            ($result -join ';') | Should -Match 'docs[\\/]plugins[\\/]sample$'
        }

        It 'Excludes moderation while retaining the telemetry hook project' {
            $repo = Join-Path $TestDrive 'repo-with-non-skill-projects'
            $moderation = Join-Path $repo 'scripts/evals/moderation'
            $telemetry = Join-Path $repo '.github/hooks/shared/telemetry'
            New-Item -ItemType Directory -Path $moderation -Force | Out-Null
            New-Item -ItemType Directory -Path $telemetry -Force | Out-Null
            Set-Content -Path (Join-Path $moderation 'pyproject.toml') -Value ''
            Set-Content -Path (Join-Path $telemetry 'pyproject.toml') -Value ''

            $result = Get-PythonSkill -RepoRoot $repo

            $result.Count | Should -Be 1
            ($result -join ';') | Should -Match '[\\/]hooks[\\/]shared[\\/]telemetry$'
            ($result -join ';') | Should -Not -Match '[\\/]evals[\\/]moderation$'
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

    Context 'When scanning the current repository' {
        It 'Finds a lockfile with a usable ruff version for every eligible project' {
            $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
            $projects = @(Get-PythonSkill -RepoRoot $repoRoot)

            $projects.Count | Should -BeGreaterThan 0
            foreach ($project in $projects) {
                $lockPath = Join-Path $project 'uv.lock'
                Test-Path $lockPath -PathType Leaf | Should -BeTrue -Because "$project is eligible for locked setup"
                Get-LockedRuffVersion -LockPath $lockPath | Should -Not -BeNullOrEmpty -Because "$project must lock ruff"
            }
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

Describe 'Get-LockedRuffVersion' -Tag 'Unit' {
    Context 'When uv.lock records a ruff package' {
        It 'Returns the locked ruff version' {
            $project = Join-Path $TestDrive 'lock-valid'
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @'
[[package]]
name = "pytest"
version = "8.4.1"

[[package]]
name = "ruff"
version = "0.16.2"
source = { registry = "https://pypi.org/simple" }
'@

            Get-LockedRuffVersion -LockPath (Join-Path $project 'uv.lock') | Should -Be '0.16.2'
        }
    }

    Context 'When uv.lock does not lock ruff' {
        It 'Returns $null' {
            $project = Join-Path $TestDrive 'lock-no-ruff'
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @'
[[package]]
name = "pytest"
version = "8.4.1"
'@

            Get-LockedRuffVersion -LockPath (Join-Path $project 'uv.lock') | Should -BeNullOrEmpty
        }
    }

    Context 'When uv.lock is malformed' {
        It 'Returns $null when the ruff entry has no version' {
            $project = Join-Path $TestDrive 'lock-malformed'
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @'
[[package]]
name = "ruff"
'@

            Get-LockedRuffVersion -LockPath (Join-Path $project 'uv.lock') | Should -BeNullOrEmpty
        }

        It 'Does not attribute a later package version to ruff' {
            $project = Join-Path $TestDrive 'lock-version-bleed'
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @'
[[package]]
name = "ruff"

[[package]]
name = "pytest"
version = "8.4.1"
'@

            Get-LockedRuffVersion -LockPath (Join-Path $project 'uv.lock') | Should -BeNullOrEmpty
        }
    }

    Context 'When uv.lock is missing' {
        It 'Returns $null' {
            $project = Join-Path $TestDrive 'lock-missing'
            New-Item -ItemType Directory -Path $project -Force | Out-Null

            Get-LockedRuffVersion -LockPath (Join-Path $project 'uv.lock') | Should -BeNullOrEmpty
        }
    }
}

Describe 'Resolve-ProjectRuff' -Tag 'Unit' {
    BeforeAll {
        function New-LockedProject {
            param(
                [string]$Name,
                [string]$Version = '0.16.2',
                [switch]$LinuxVenv,
                [switch]$WindowsVenv
            )

            $project = Join-Path $TestDrive $Name
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @"
[[package]]
name = "ruff"
version = "$Version"
"@

            if ($LinuxVenv) {
                $bin = Join-Path $project '.venv/bin'
                New-Item -ItemType Directory -Path $bin -Force | Out-Null
                Set-Content -Path (Join-Path $bin 'ruff') -Value ''
            }

            if ($WindowsVenv) {
                $scripts = Join-Path $project '.venv/Scripts'
                New-Item -ItemType Directory -Path $scripts -Force | Out-Null
                Set-Content -Path (Join-Path $scripts 'ruff.exe') -Value ''
            }

            return $project
        }
    }

    Context 'When the project venv ruff matches the locked version' {
        It 'Selects the Linux venv binary and reports locked resolution' {
            $project = New-LockedProject -Name 'locked-linux-match' -LinuxVenv
            Mock Get-RuffVersionString { '0.16.2' } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $false

            $resolution.command | Should -Match 'bin[\\/]ruff$'
            $resolution.resolutionMode | Should -Be 'locked'
            $resolution.lockedVersion | Should -Be '0.16.2'
            $resolution.resolvedVersion | Should -Be '0.16.2'
        }

        It 'Selects the Windows venv binary when it is the matching candidate' {
            $project = New-LockedProject -Name 'locked-windows-match' -WindowsVenv
            Mock Get-RuffVersionString { '0.16.2' } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $false

            $resolution.command | Should -Match 'Scripts[\\/]ruff\.exe$'
            $resolution.resolutionMode | Should -Be 'locked'
        }
    }

    Context 'When the project venv ruff does not match the locked version' {
        It 'Falls through to an exactly matching global ruff' {
            $project = New-LockedProject -Name 'locked-global-fallback' -LinuxVenv
            Mock Get-RuffVersionString {
                if ($RuffCommand -eq 'ruff') { '0.16.2' } else { '0.15.4' }
            } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $true

            $resolution.command | Should -Be 'ruff'
            $resolution.resolvedVersion | Should -Be '0.16.2'
            ($resolution.mismatches -join ';') | Should -Match '0\.15\.4'
        }

        It 'Rejects a mismatched global ruff and reports the setup action' {
            $project = New-LockedProject -Name 'locked-global-mismatch' -LinuxVenv
            Mock Get-RuffVersionString { '0.15.4' } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $true

            $resolution.command | Should -BeNullOrEmpty
            $resolution.lockedVersion | Should -Be '0.16.2'
            $resolution.reason | Should -Match 'requires ruff 0\.16\.2'
            $resolution.reason | Should -Match "uv sync --locked"
        }
    }

    Context 'When no ruff candidate exists for a locked project' {
        It 'Fails with the required version and setup action' {
            $project = New-LockedProject -Name 'locked-no-candidate'
            Mock Get-RuffVersionString { $null } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $false

            $resolution.command | Should -BeNullOrEmpty
            $resolution.resolutionMode | Should -Be 'locked'
            $resolution.reason | Should -Match 'found no ruff candidate'
        }
    }

    Context 'When uv.lock does not record ruff' {
        It 'Fails without executing any candidate' {
            $project = Join-Path $TestDrive 'locked-without-ruff'
            New-Item -ItemType Directory -Path $project -Force | Out-Null
            Set-Content -Path (Join-Path $project 'uv.lock') -Value @'
[[package]]
name = "pytest"
version = "8.4.1"
'@
            Mock Get-RuffVersionString { '0.16.2' } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $true

            $resolution.command | Should -BeNullOrEmpty
            $resolution.reason | Should -Match 'does not record a usable ruff version'
            Should -Invoke Get-RuffVersionString -ModuleName PythonLintHelpers -Times 0 -Exactly
        }
    }

    Context 'When the project has no uv.lock' {
        It 'Prefers the project venv ruff and reports unlocked fallback' {
            $project = Join-Path $TestDrive 'unlocked-with-venv'
            $bin = Join-Path $project '.venv/bin'
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            Set-Content -Path (Join-Path $bin 'ruff') -Value ''
            Mock Get-RuffVersionString { '0.15.4' } -ModuleName PythonLintHelpers

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $true

            $resolution.command | Should -Match 'bin[\\/]ruff$'
            $resolution.resolutionMode | Should -Be 'unlocked-fallback'
            $resolution.lockedVersion | Should -BeNullOrEmpty
            Should -Invoke Get-RuffVersionString -ModuleName PythonLintHelpers -Times 0 -Exactly
        }

        It 'Falls back to global ruff without a version claim' {
            $project = Join-Path $TestDrive 'unlocked-global'
            New-Item -ItemType Directory -Path $project -Force | Out-Null

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $true

            $resolution.command | Should -Be 'ruff'
            $resolution.resolutionMode | Should -Be 'unlocked-fallback'
            $resolution.resolvedVersion | Should -BeNullOrEmpty
        }

        It 'Fails when no ruff is available anywhere' {
            $project = Join-Path $TestDrive 'unlocked-no-ruff'
            New-Item -ItemType Directory -Path $project -Force | Out-Null

            $resolution = Resolve-ProjectRuff -SkillPath $project -GlobalRuffAvailable $false

            $resolution.command | Should -BeNullOrEmpty
            $resolution.resolutionMode | Should -Be 'unlocked-fallback'
            $resolution.reason | Should -Match 'ruff not available'
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
